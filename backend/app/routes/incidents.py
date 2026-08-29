from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status
from typing import Dict, Any

from app.models import (
    EmergencyIncidentModel,
    IncidentCreateSchema,
    StatusUpdateSchema,
    CancelIncidentSchema,
    AssignResponderSchema,
    EmergencyStatusEnum,
)
from app.store import store

router = APIRouter(prefix="/incidents", tags=["Incidents"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_incident(payload: IncidentCreateSchema) -> Dict[str, Any]:
    incident_id = payload.id if payload.id and payload.id.strip() else store.generate_id(payload.category)
    now_iso = datetime.now(timezone.utc).isoformat()

    incident = EmergencyIncidentModel(
        id=incident_id,
        userId=payload.userId or "guest_user",
        category=payload.category,
        intent=payload.intent,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy=payload.accuracy,
        timestamp=payload.timestamp or now_iso,
        priority=payload.priority or "high",
        status=payload.status or "created",
        notes=payload.notes,
    )

    created = store.save(incident)
    return {
        "status": "success",
        "incident": created.model_dump(),
    }


@router.get("/active")
def get_active_incidents() -> Dict[str, Any]:
    incidents = store.get_active()
    return {
        "status": "success",
        "incidents": [inc.model_dump() for inc in incidents],
    }


@router.get("")
def get_all_incidents() -> Dict[str, Any]:
    incidents = store.get_all()
    return {
        "status": "success",
        "incidents": [inc.model_dump() for inc in incidents],
    }


@router.get("/{incident_id}")
def get_incident(incident_id: str) -> Dict[str, Any]:
    incident = store.get_by_id(incident_id)
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident with ID '{incident_id}' not found.",
        )
    return {
        "status": "success",
        "incident": incident.model_dump(),
    }


@router.put("/{incident_id}/status")
@router.patch("/{incident_id}/status")
def update_incident_status(incident_id: str, payload: StatusUpdateSchema) -> Dict[str, Any]:
    # Validate status name
    valid_statuses = [e.value for e in EmergencyStatusEnum]
    if payload.status not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status '{payload.status}'. Valid statuses are: {valid_statuses}",
        )

    updated = store.update_status(incident_id, payload.status)
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident with ID '{incident_id}' not found.",
        )

    return {
        "status": "success",
        "incident": updated.model_dump(),
    }


@router.post("/{incident_id}/cancel")
def cancel_incident(incident_id: str, payload: CancelIncidentSchema = CancelIncidentSchema()) -> Dict[str, Any]:
    cancelled = store.cancel(incident_id, reason=payload.reason)
    if not cancelled:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident with ID '{incident_id}' not found.",
        )

    return {
        "status": "success",
        "incident": cancelled.model_dump(),
    }


@router.post("/{incident_id}/assign-responder")
def assign_responder(incident_id: str, payload: AssignResponderSchema) -> Dict[str, Any]:
    updated = store.assign_responder(
        incident_id,
        responder_id=payload.responderId,
        responder_name=payload.responderName,
        responder_phone=payload.responderPhone,
        responder_type=payload.responderType,
        responder_lat=payload.responderLatitude,
        responder_lng=payload.responderLongitude,
        eta_minutes=payload.estimatedArrivalMinutes,
    )

    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident with ID '{incident_id}' not found.",
        )

    return {
        "status": "success",
        "incident": updated.model_dump(),
    }
