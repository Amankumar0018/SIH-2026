from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status, Depends
from typing import Dict, Any

from app.models import (
    EmergencyIncidentModel,
    IncidentCreateSchema,
    StatusUpdateSchema,
    CancelIncidentSchema,
    AssignResponderSchema,
    EmergencyCategoryEnum,
    EmergencyPriorityEnum,
    EmergencyStatusEnum,
    UserModel,
)
from app.security import get_current_user, require_responder, check_incident_access
from app.store import store

router = APIRouter(prefix="/incidents", tags=["Incidents"])


@router.post("", status_code=status.HTTP_201_CREATED)
def create_incident(
    payload: IncidentCreateSchema,
    user: UserModel = Depends(get_current_user),
) -> Dict[str, Any]:
    # Category validation
    valid_categories = [e.value for e in EmergencyCategoryEnum]
    if payload.category not in valid_categories:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid category '{payload.category}'. Valid categories are: {valid_categories}",
        )

    # Priority validation
    valid_priorities = [e.value for e in EmergencyPriorityEnum]
    priority = payload.priority or EmergencyPriorityEnum.high.value
    if priority not in valid_priorities:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid priority '{payload.priority}'. Valid priorities are: {valid_priorities}",
        )

    # Server-owned and server-controlled fields
    incident_id = store.generate_id(payload.category)
    now_iso = datetime.now(timezone.utc).isoformat()
    user_id = user.mobileNumber
    initial_status = EmergencyStatusEnum.created.value

    incident = EmergencyIncidentModel(
        id=incident_id,
        userId=user_id,
        category=payload.category,
        intent=payload.intent,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy=payload.accuracy,
        timestamp=now_iso,
        priority=priority,
        status=initial_status,
        notes=payload.notes,
    )

    created = store.save(incident)
    return {
        "status": "success",
        "incident": created.model_dump(),
    }


@router.get("/active")
def get_active_incidents(
    user: UserModel = Depends(require_responder),
) -> Dict[str, Any]:
    incidents = store.get_active()
    return {
        "status": "success",
        "incidents": [inc.model_dump() for inc in incidents],
    }


@router.get("")
def get_all_incidents(
    user: UserModel = Depends(require_responder),
) -> Dict[str, Any]:
    incidents = store.get_all()
    return {
        "status": "success",
        "incidents": [inc.model_dump() for inc in incidents],
    }


@router.get("/{incident_id}")
def get_incident(
    incident_id: str,
    user: UserModel = Depends(get_current_user),
) -> Dict[str, Any]:
    incident = store.get_by_id(incident_id)
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident with ID '{incident_id}' not found.",
        )

    if not check_incident_access(user, incident.userId):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: You do not have permission to view this incident.",
        )

    return {
        "status": "success",
        "incident": incident.model_dump(),
    }


@router.put("/{incident_id}/status")
@router.patch("/{incident_id}/status")
def update_incident_status(
    incident_id: str,
    payload: StatusUpdateSchema,
    user: UserModel = Depends(require_responder),
) -> Dict[str, Any]:
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
def cancel_incident(
    incident_id: str,
    payload: CancelIncidentSchema = CancelIncidentSchema(),
    user: UserModel = Depends(get_current_user),
) -> Dict[str, Any]:
    incident = store.get_by_id(incident_id)
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Incident with ID '{incident_id}' not found.",
        )

    if not check_incident_access(user, incident.userId):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: You do not have permission to cancel this incident.",
        )

    cancelled = store.cancel(incident_id, reason=payload.reason)
    return {
        "status": "success",
        "incident": cancelled.model_dump(),
    }


@router.post("/{incident_id}/assign-responder")
def assign_responder(
    incident_id: str,
    payload: AssignResponderSchema,
    user: UserModel = Depends(require_responder),
) -> Dict[str, Any]:
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

