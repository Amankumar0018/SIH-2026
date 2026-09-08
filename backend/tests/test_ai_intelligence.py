import pytest
import os
import json
import asyncio
import httpx
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from app.main import app
from app.models import (
    EmergencyIncidentModel,
    IncidentCreateSchema,
    AIIntelligenceModel,
)
from app.store import store, user_store
from app.ai_service import (
    sanitize_incident_notes,
    generate_rule_based_intelligence,
    enrich_incident_with_llm,
)
from app.routes.incidents import _async_enrich_incident_llm
from app.ws import connection_manager


@pytest.fixture(autouse=True)
def clean_store():
    store.clear()
    user_store.clear()
    connection_manager.active_connections.clear()
    yield
    store.clear()
    user_store.clear()
    connection_manager.active_connections.clear()


def test_pii_sanitization():
    """Verify phone numbers, emails, tokens, and coordinates are stripped from user notes."""
    raw_notes = (
        "Call my brother at +91 9876543210 or 9123456789. "
        "Email him at family_contact@example.com! "
        "Token: Bearer abcdef1234567890abcdef1234567890. "
        "Coordinates: 28.6139, 77.2090. Help urgently."
    )
    sanitized = sanitize_incident_notes(raw_notes)

    assert "[REDACTED_PHONE]" in sanitized
    assert "9876543210" not in sanitized
    assert "9123456789" not in sanitized
    assert "[REDACTED_EMAIL]" in sanitized
    assert "family_contact@example.com" not in sanitized
    assert "[REDACTED_TOKEN]" in sanitized
    assert "abcdef1234567890abcdef1234567890" not in sanitized
    assert "[REDACTED_COORDINATES]" in sanitized
    assert "Help urgently." in sanitized


def test_missing_and_empty_notes():
    """Verify missing or empty notes do not cause errors and produce valid intelligence."""
    assert sanitize_incident_notes(None) == ""
    assert sanitize_incident_notes("   ") == ""

    ai_none = generate_rule_based_intelligence(
        category="medical",
        intent="Ambulance",
        notes=None,
        priority="high",
    )
    assert ai_none is not None
    assert ai_none.summary != ""
    assert len(ai_none.recommendedActions) > 0


def test_rule_based_all_categories():
    """Verify rule-based intelligence generates valid structured intelligence for all 4 categories."""
    categories = ["medical", "womenSafety", "disaster", "campus"]
    for cat in categories:
        ai = generate_rule_based_intelligence(
            category=cat,
            intent="General Emergency",
            notes="Someone needs assistance",
            priority="high",
        )
        assert isinstance(ai, AIIntelligenceModel)
        assert ai.source == "rule_based"
        assert ai.urgencyScore in ("CRITICAL", "HIGH", "MEDIUM", "LOW")
        assert len(ai.hazards) > 0
        assert len(ai.recommendedActions) > 0
        assert len(ai.missingInfo) > 0
        assert 0.0 <= ai.confidence <= 1.0


def test_rule_based_urgency_escalation():
    """Verify critical keywords elevate urgency score to CRITICAL."""
    ai_critical = generate_rule_based_intelligence(
        category="medical",
        intent="Cardiac arrest",
        notes="Patient is unconscious and bleeding",
        priority="high",
    )
    assert ai_critical.urgencyScore == "CRITICAL"
    assert any("cardiac" in h.lower() or "unconscious" in h.lower() for h in ai_critical.hazards)


def test_llm_enrichment_missing_api_key():
    """Verify missing GEMINI_API_KEY gracefully returns None without error."""
    async def _test():
        with patch.dict(os.environ, {}, clear=True):
            res = await enrich_incident_with_llm(
                category="medical",
                intent="Injury",
                notes="Minor cut",
            )
            assert res is None

    asyncio.run(_test())


def test_llm_enrichment_success():
    """Verify successful LLM response parses into valid AIIntelligenceModel."""
    fake_llm_response = {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {
                            "text": json.dumps({
                                "summary": "Paramedic triage required for fracture injury.",
                                "urgencyScore": "HIGH",
                                "hazards": ["Potential bone displacement"],
                                "recommendedActions": ["Immobilize limb", "Assess pulse"],
                                "missingInfo": ["X-ray availability"],
                                "confidence": 0.88,
                            })
                        }
                    ]
                }
            }
        ]
    }

    mock_client = AsyncMock()
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = fake_llm_response
    mock_client.post.return_value = mock_response

    async def _test():
        with patch.dict(os.environ, {"GEMINI_API_KEY": "dummy_test_key"}):
            result = await enrich_incident_with_llm(
                category="medical",
                intent="Fracture",
                notes="Patient fell down stairs",
                client=mock_client,
            )

            assert result is not None
            assert result.source == "llm"
            assert result.urgencyScore == "HIGH"
            assert "fracture" in result.summary.lower()
            assert result.confidence == 0.88
            assert "Immobilize limb" in result.recommendedActions

    asyncio.run(_test())


def test_llm_enrichment_invalid_malformed_json():
    """Verify malformed JSON from LLM is handled safely, returning None."""
    mock_client = AsyncMock()
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "candidates": [{"content": {"parts": [{"text": "THIS IS NOT JSON"}]}}]
    }
    mock_client.post.return_value = mock_response

    async def _test():
        with patch.dict(os.environ, {"GEMINI_API_KEY": "dummy_test_key"}):
            result = await enrich_incident_with_llm(
                category="medical",
                intent="Injury",
                notes="Test",
                client=mock_client,
            )
            assert result is None

    asyncio.run(_test())


def test_llm_enrichment_timeout():
    """Verify network timeout returns None gracefully."""
    mock_client = AsyncMock()
    mock_client.post.side_effect = httpx.TimeoutException("Timeout")

    async def _test():
        with patch.dict(os.environ, {"GEMINI_API_KEY": "dummy_test_key"}):
            result = await enrich_incident_with_llm(
                category="medical",
                intent="Injury",
                notes="Test",
                client=mock_client,
            )
            assert result is None

    asyncio.run(_test())


def test_ai_cannot_modify_authoritative_fields():
    """Verify AI update in store only modifies aiIntelligence and preserves authoritative fields."""
    incident = EmergencyIncidentModel(
        id="INC_TEST_001",
        userId="9876543210",
        category="medical",
        intent="Ambulance",
        priority="high",
        status="created",
    )
    store.save(incident)

    ai_update = AIIntelligenceModel(
        summary="Updated by LLM",
        urgencyScore="CRITICAL",
        hazards=["Hazard 1"],
        recommendedActions=["Action 1"],
        missingInfo=["Info 1"],
        source="llm",
        confidence=0.92,
    )

    updated = store.update_ai_intelligence("INC_TEST_001", ai_update)
    assert updated is not None
    assert updated.id == "INC_TEST_001"
    assert updated.userId == "9876543210"
    assert updated.category == "medical"
    assert updated.status == "created"
    assert updated.priority == "high"
    assert updated.aiIntelligence is not None
    assert updated.aiIntelligence.source == "llm"
    assert updated.aiIntelligence.summary == "Updated by LLM"


def test_incident_creation_and_async_enrichment_flow():
    """Verify incident creation succeeds immediately with rule-based AI and enriches via background task."""
    token = user_store.create_token("9876543210")
    headers = {"Authorization": f"Bearer {token}"}
    client = TestClient(app)

    # 1. Create incident via POST /incidents
    payload = {
        "category": "womenSafety",
        "intent": "Immediate SOS Panic Trigger",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "priority": "critical",
        "notes": "Emergency SOS triggered from mobile",
    }

    resp = client.post("/incidents", json=payload, headers=headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "success"
    incident = data["incident"]

    # 2. Rule-based intelligence is present immediately
    assert incident["aiIntelligence"] is not None
    assert incident["aiIntelligence"]["source"] == "rule_based"
    assert incident["aiIntelligence"]["urgencyScore"] == "CRITICAL"
    assert len(incident["aiIntelligence"]["recommendedActions"]) > 0

    # 3. Simulate async enrichment background task
    enriched_ai = AIIntelligenceModel(
        summary="Rapid safety escort required.",
        urgencyScore="CRITICAL",
        hazards=["Active panic alert"],
        recommendedActions=["Dispatch unit immediate"],
        missingInfo=["Exact street location"],
        source="llm",
        confidence=0.95,
    )

    async def _enrich():
        with patch("app.routes.incidents.enrich_incident_with_llm", AsyncMock(return_value=enriched_ai)):
            await _async_enrich_incident_llm(
                incident_id=incident["id"],
                category="womenSafety",
                intent="Immediate SOS Panic Trigger",
                notes="Emergency SOS triggered from mobile",
                priority="critical",
            )

    asyncio.run(_enrich())

    # 4. Check that store now has enriched intelligence
    stored = store.get_by_id(incident["id"])
    assert stored is not None
    assert stored.aiIntelligence is not None
    assert stored.aiIntelligence.source == "llm"
    assert stored.aiIntelligence.summary == "Rapid safety escort required."
    assert stored.aiIntelligence.confidence == 0.95


def test_client_supplied_ai_intelligence_ignored():
    """Verify that client-supplied aiIntelligence in POST /incidents body is ignored.

    The server must always generate its own rule-based AI intelligence regardless
    of what the client sends. This guards against spoofed urgency scores, fake
    confidence values, or injected recommended actions.
    """
    token = user_store.create_token("9876543210")
    headers = {"Authorization": f"Bearer {token}"}
    client = TestClient(app)

    # Craft a malicious aiIntelligence payload
    payload = {
        "category": "medical",
        "intent": "Ambulance",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "priority": "high",
        "notes": "Need help",
        "aiIntelligence": {
            "summary": "ATTACKER CONTROLLED SUMMARY",
            "urgencyScore": "LOW",
            "hazards": ["Fake hazard"],
            "recommendedActions": ["Ignore the emergency"],
            "missingInfo": [],
            "source": "attacker",
            "confidence": 0.01,
        },
    }

    resp = client.post("/incidents", json=payload, headers=headers)
    assert resp.status_code == 201
    data = resp.json()
    incident = data["incident"]

    # Server-generated AI intelligence must be present
    assert incident["aiIntelligence"] is not None
    assert incident["aiIntelligence"]["source"] == "rule_based"

    # Client-supplied values must NOT appear
    assert incident["aiIntelligence"]["summary"] != "ATTACKER CONTROLLED SUMMARY"
    assert incident["aiIntelligence"]["urgencyScore"] != "LOW"
    assert incident["aiIntelligence"]["confidence"] != 0.01
    assert "attacker" not in incident["aiIntelligence"]["source"]
    assert "Ignore the emergency" not in incident["aiIntelligence"]["recommendedActions"]

    # Verify the stored incident matches
    stored = store.get_by_id(incident["id"])
    assert stored.aiIntelligence.source == "rule_based"
    assert "ATTACKER" not in stored.aiIntelligence.summary


def test_rule_based_confidence_case_insensitive():
    """Verify SOS/panic confidence detection works with any casing."""
    # Lowercase "sos" should trigger the higher 0.85 confidence
    ai_lower = generate_rule_based_intelligence(
        category="womenSafety",
        intent="sos button pressed",
        notes="Help me",
        priority="high",
    )
    assert ai_lower.confidence == 0.85

    # Mixed-case "Panic" should also trigger 0.85
    ai_mixed = generate_rule_based_intelligence(
        category="womenSafety",
        intent="PANIC alert from campus",
        notes="",
        priority="high",
    )
    assert ai_mixed.confidence == 0.85

    # No sos/panic keyword should fall back to 0.70
    ai_none = generate_rule_based_intelligence(
        category="womenSafety",
        intent="Harassment report",
        notes="Followed by unknown person",
        priority="high",
    )
    assert ai_none.confidence == 0.70
