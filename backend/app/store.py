from typing import Dict, List, Optional
from datetime import datetime, timezone
import time
from app.models import EmergencyIncidentModel


class IncidentStore:
    """In-memory data store for Pukaar emergency incidents."""

    def __init__(self):
        self._incidents: Dict[str, EmergencyIncidentModel] = {}

    def clear(self):
        self._incidents.clear()

    def generate_id(self, category: str) -> str:
        timestamp_ms = int(time.time() * 1000)
        return f"INC_{timestamp_ms}_{category.upper()}"

    def save(self, incident: EmergencyIncidentModel) -> EmergencyIncidentModel:
        self._incidents[incident.id] = incident
        return incident

    def get_by_id(self, incident_id: str) -> Optional[EmergencyIncidentModel]:
        return self._incidents.get(incident_id)

    def get_all(self) -> List[EmergencyIncidentModel]:
        return list(self._incidents.values())

    def get_active(self) -> List[EmergencyIncidentModel]:
        return [
            inc for inc in self._incidents.values()
            if inc.status not in ("resolved", "cancelled")
        ]

    def update_status(self, incident_id: str, new_status: str) -> Optional[EmergencyIncidentModel]:
        inc = self.get_by_id(incident_id)
        if not inc:
            return None
        updated = inc.model_copy(update={"status": new_status})
        self._incidents[incident_id] = updated
        return updated

    def cancel(self, incident_id: str, reason: Optional[str] = None) -> Optional[EmergencyIncidentModel]:
        inc = self.get_by_id(incident_id)
        if not inc:
            return None
        notes = inc.notes
        if reason:
            notes = f"{notes}\nCancellation Reason: {reason}".strip() if notes else f"Cancellation Reason: {reason}"
        updated = inc.model_copy(update={"status": "cancelled", "notes": notes})
        self._incidents[incident_id] = updated
        return updated

    def assign_responder(
        self,
        incident_id: str,
        responder_id: str,
        responder_name: str,
        responder_phone: Optional[str] = None,
        responder_type: Optional[str] = None,
        responder_lat: Optional[float] = None,
        responder_lng: Optional[float] = None,
        eta_minutes: Optional[int] = None,
    ) -> Optional[EmergencyIncidentModel]:
        inc = self.get_by_id(incident_id)
        if not inc:
            return None
        updated = inc.model_copy(
            update={
                "assignedResponderId": responder_id,
                "assignedResponderName": responder_name,
                "assignedResponderPhone": responder_phone or inc.assignedResponderPhone,
                "assignedResponderType": responder_type or inc.assignedResponderType,
                "responderLatitude": responder_lat if responder_lat is not None else inc.responderLatitude,
                "responderLongitude": responder_lng if responder_lng is not None else inc.responderLongitude,
                "estimatedArrivalMinutes": eta_minutes if eta_minutes is not None else inc.estimatedArrivalMinutes,
            }
        )
        self._incidents[incident_id] = updated
        return updated


# Global singleton instance for local dev backend
store = IncidentStore()
