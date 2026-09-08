import os
import re
import json
import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
import httpx

from app.models import AIIntelligenceModel

logger = logging.getLogger("pukaar.ai")

# Regex patterns for PII sanitization
PHONE_REGEX = re.compile(r"\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b|\b\d{10,12}\b")
EMAIL_REGEX = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b")
TOKEN_REGEX = re.compile(r"\b(?:Bearer\s+)?[a-zA-Z0-9_\-]{28,}\b", re.IGNORECASE)
COORDINATES_REGEX = re.compile(r"[-+]?\d{1,2}\.\d{4,}[,\s]+[-+]?\d{1,3}\.\d{4,}")


def sanitize_incident_notes(notes: Optional[str]) -> str:
    """Sanitizes user notes by stripping phone numbers, emails, tokens, and raw coordinates."""
    if not notes or not notes.strip():
        return ""
    sanitized = notes.strip()
    sanitized = PHONE_REGEX.sub("[REDACTED_PHONE]", sanitized)
    sanitized = EMAIL_REGEX.sub("[REDACTED_EMAIL]", sanitized)
    sanitized = TOKEN_REGEX.sub("[REDACTED_TOKEN]", sanitized)
    sanitized = COORDINATES_REGEX.sub("[REDACTED_COORDINATES]", sanitized)
    return sanitized


def generate_rule_based_intelligence(
    category: str,
    intent: str,
    notes: Optional[str] = None,
    priority: str = "high",
) -> AIIntelligenceModel:
    """Deterministic, rule-based emergency triage intelligence engine.
    
    Infers structured intelligence exclusively from authoritative category, intent,
    sanitized notes, and priority using conservative domain rules without external calls.
    """
    sanitized_notes = sanitize_incident_notes(notes)
    notes_lower = sanitized_notes.lower()
    intent_lower = (intent or "").lower()
    cat_lower = (category or "").lower()

    # Determine urgency score conservatively
    is_critical_priority = priority.lower() in ("critical", "high")
    has_critical_keyword = any(
        kw in notes_lower or kw in intent_lower
        for kw in ("panic", "unconscious", "cardiac", "heart", "bleeding", "fire", "smoke", "flood", "threat", "attack", "weapon")
    )

    if priority.lower() == "critical" or (is_critical_priority and has_critical_keyword):
        urgency_score = "CRITICAL"
    elif is_critical_priority or "injury" in intent_lower or "harassment" in intent_lower:
        urgency_score = "HIGH"
    elif priority.lower() == "medium":
        urgency_score = "MEDIUM"
    else:
        urgency_score = "LOW"

    # Domain specific heuristics
    if cat_lower == "medical":
        summary = f"Medical emergency reported: {intent}. Immediate paramedic response and clinical triage recommended."
        hazards = ["Airway, breathing, or circulation compromise", "Potential trauma or rapid patient deterioration"]
        if "unconscious" in intent_lower or "unconscious" in notes_lower:
            hazards.append("Unconscious patient — airway obstruction hazard")
        if "cardiac" in intent_lower or "heart" in notes_lower:
            hazards.append("Suspected acute cardiac distress")

        actions = [
            "Dispatch nearest Advanced/Basic Life Support ambulance unit",
            "Verify patient consciousness and vital signs upon arrival",
            "Prepare automated external defibrillator (AED) and trauma kit",
            "Maintain unobstructed stretcher access corridor",
        ]
        missing_info = [
            "Patient consciousness and breathing status",
            "Specific room, floor, or indoor access details",
            "Known chronic conditions or recent trauma context",
        ]
        confidence = 0.80 if intent != "Other" else 0.65

    elif cat_lower in ("womensafety", "women_safety", "safety"):
        summary = f"Safety distress alert triggered: {intent}. Immediate patrol dispatch and escort required."
        hazards = ["Potential hostile presence or immediate safety risk", "Low ambient visibility or isolated area"]
        if "panic" in intent_lower or "immediate" in intent_lower:
            hazards.append("High acute distress indicated by panic SOS trigger")

        actions = [
            "Dispatch rapid safety patrol unit to the broadcast coordinates",
            "Prioritize citizen safety; maintain continuous communication channel",
            "Assess perimeter for threats before approach; avoid escalation",
            "Prepare secure escort to designated safe zone",
        ]
        missing_info = [
            "Presence, description, or count of potential aggressors",
            "Indoor or outdoor specific landmark indicators",
            "Safe ingress and extraction route status",
        ]
        confidence = 0.85 if "sos" in intent_lower or "panic" in intent_lower else 0.70

    elif cat_lower == "disaster":
        summary = f"Disaster event reported: {intent}. Rapid scene assessment and multi-agency response recommended."
        hazards = ["Structural instability or physical entrapment", "Environmental hazards (fire, smoke, or floodwaters)"]
        if "fire" in intent_lower or "smoke" in notes_lower:
            hazards.append("Toxic smoke inhalation and active flame spread")
        if "flood" in intent_lower or "water" in notes_lower:
            hazards.append("Rapidly rising water or electrical current hazards")

        actions = [
            "Assess scene safety and establish a controlled perimeter",
            "Keep first responders clear of immediate collapse hazards",
            "Request specialized fire brigade or disaster management units",
            "Identify trapped individuals and clear primary evacuation routes",
        ]
        missing_info = [
            "Estimated count of individuals trapped or affected",
            "Progression rate of the hazard (spread or depth)",
            "Utility status (gas and main electrical power cut-off)",
        ]
        confidence = 0.80 if intent != "Other" else 0.65

    elif cat_lower == "campus":
        summary = f"Campus security event: {intent}. Rapid university safety verification advised."
        hazards = ["Crowd density or student population exposure", "Unverified safety threat in educational facility"]
        actions = [
            "Notify campus security control and dispatch patrol officers",
            "Verify specific campus building, block, or quad location",
            "Coordinate with campus administrative authorities",
            "Secure zone perimeter and ensure student/faculty safety",
        ]
        missing_info = [
            "Specific campus building number, wing, or classroom",
            "Count of individuals involved or in direct distress",
            "Presence of university security personnel on site",
        ]
        confidence = 0.75 if intent != "Other" else 0.60

    else:
        summary = f"Emergency incident reported: {intent}. Response verification required."
        hazards = ["Unverified emergency scene conditions"]
        actions = [
            "Dispatch local emergency unit for on-site assessment",
            "Establish direct voice contact with caller to confirm details",
            "Maintain situational awareness upon scene arrival",
        ]
        missing_info = [
            "Specific incident nature and severity",
            "Precise location landmark details",
            "Number of people requiring assistance",
        ]
        confidence = 0.50

    return AIIntelligenceModel(
        summary=summary,
        urgencyScore=urgency_score,
        hazards=hazards,
        recommendedActions=actions,
        missingInfo=missing_info,
        source="rule_based",
        confidence=confidence,
        generatedAt=datetime.now(timezone.utc).isoformat(),
    )


async def enrich_incident_with_llm(
    category: str,
    intent: str,
    notes: Optional[str] = None,
    priority: str = "high",
    client: Optional[httpx.AsyncClient] = None,
) -> Optional[AIIntelligenceModel]:
    """Asynchronously calls Google Gemini API to produce enriched structured intelligence.
    
    Guarantees:
    - Never blocks initial incident creation.
    - Uses GEMINI_API_KEY environment variable only.
    - If key is missing, network times out, or output is invalid: returns None without crashing.
    - Never sends raw PII, phone numbers, auth tokens, or exact GPS coordinates.
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key or not api_key.strip():
        logger.info("[AI Service] GEMINI_API_KEY not configured. Rule-based intelligence will be retained.")
        return None

    sanitized_notes = sanitize_incident_notes(notes)

    # Construct strict sanitized input payload
    prompt_payload = {
        "emergencyCategory": category,
        "emergencyIntent": intent,
        "reportedPriority": priority,
        "callerContextRemarks": sanitized_notes if sanitized_notes else "None provided",
    }

    system_instruction = (
        "You are an Emergency Response Triage and Responder Dispatch Assistant. "
        "Analyze the emergency incident facts provided and return a STRICT JSON object conforming to the schema. "
        "CONSTRAINTS:\n"
        "1. Do NOT invent facts, diagnoses, names, or phone numbers.\n"
        "2. recommendedActions must be safe, conservative, SOP-oriented responder guidance (e.g. check consciousness, prepare AED, secure perimeter).\n"
        "3. urgencyScore must be one of: 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'.\n"
        "4. Output MUST be pure JSON with keys: summary, urgencyScore, hazards, recommendedActions, missingInfo, confidence.\n"
        "5. confidence must be a number between 0.0 and 1.0."
    )

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key.strip()}"
    request_body = {
        "contents": [
            {
                "parts": [
                    {"text": f"{system_instruction}\n\nIncident Data:\n{json.dumps(prompt_payload)}"}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.2,
            "responseMimeType": "application/json",
        },
    }

    should_close_client = False
    if client is None:
        client = httpx.AsyncClient(timeout=4.0)
        should_close_client = True

    try:
        response = await client.post(url, json=request_body)
        if response.status_code != 200:
            logger.warning(f"[AI Service] Gemini API returned status code {response.status_code}")
            return None

        response_data = response.json()
        candidates = response_data.get("candidates", [])
        if not candidates:
            return None

        content_parts = candidates[0].get("content", {}).get("parts", [])
        if not content_parts:
            return None

        raw_json_str = content_parts[0].get("text", "").strip()
        # Parse JSON
        parsed_dict = json.loads(raw_json_str)

        # Validate with AIIntelligenceModel
        return AIIntelligenceModel(
            summary=str(parsed_dict.get("summary", "")).strip()[:500] or f"Emergency: {intent}",
            urgencyScore=str(parsed_dict.get("urgencyScore", "HIGH")).strip().upper()[:50],
            hazards=[str(h).strip() for h in parsed_dict.get("hazards", [])][:20],
            recommendedActions=[str(a).strip() for a in parsed_dict.get("recommendedActions", [])][:20],
            missingInfo=[str(m).strip() for m in parsed_dict.get("missingInfo", [])][:20],
            source="llm",
            confidence=max(0.0, min(1.0, float(parsed_dict.get("confidence", 0.85)))),
            generatedAt=datetime.now(timezone.utc).isoformat(),
        )
    except (httpx.TimeoutException, httpx.RequestError) as exc:
        logger.warning(f"[AI Service] Network error calling LLM: {type(exc).__name__}")
        return None
    except (json.JSONDecodeError, ValueError, KeyError) as exc:
        logger.warning(f"[AI Service] Failed to parse or validate LLM response: {type(exc).__name__}")
        return None
    except Exception as exc:
        logger.warning(f"[AI Service] Unexpected error in LLM enrichment: {type(exc).__name__}")
        return None
    finally:
        if should_close_client:
            await client.aclose()
