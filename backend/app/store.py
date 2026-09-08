from typing import Dict, List, Optional
from datetime import datetime, timezone
import time
import hashlib
import os
import secrets
from app.models import EmergencyIncidentModel, UserModel, AIIntelligenceModel


class IncidentStore:
    """In-memory data store for Pukaar emergency incidents."""

    def __init__(self):
        self._incidents: Dict[str, EmergencyIncidentModel] = {}

    def clear(self):
        self._incidents.clear()

    def generate_id(self, category: str) -> str:
        while True:
            timestamp_ms = int(time.time() * 1000)
            rand_suffix = secrets.token_hex(4)
            new_id = f"INC_{timestamp_ms}_{category.upper()}_{rand_suffix}"
            if new_id not in self._incidents:
                return new_id

    def save(self, incident: EmergencyIncidentModel) -> EmergencyIncidentModel:
        if incident.id in self._incidents:
            raise ValueError(f"Incident with ID '{incident.id}' already exists.")
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

    def update_ai_intelligence(
        self,
        incident_id: str,
        ai_intelligence: AIIntelligenceModel,
    ) -> Optional[EmergencyIncidentModel]:
        inc = self.get_by_id(incident_id)
        if not inc:
            return None
        updated = inc.model_copy(update={"aiIntelligence": ai_intelligence})
        self._incidents[incident_id] = updated
        return updated


class UserStore:
    """In-memory data store for Pukaar user accounts and auth tokens."""

    def __init__(self):
        self._users_by_mobile: Dict[str, UserModel] = {}
        self._tokens: Dict[str, str] = {}  # token -> mobile_number
        self._seed_default_users()

    def _hash_password(self, password: str, salt_hex: Optional[str] = None) -> tuple[str, str]:
        if not salt_hex:
            salt_bytes = os.urandom(16)
            salt_hex = salt_bytes.hex()
        else:
            salt_bytes = bytes.fromhex(salt_hex)
        hash_bytes = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt_bytes, 100000)
        return hash_bytes.hex(), salt_hex

    def _seed_default_users(self):
        # Default citizen
        c_hash, c_salt = self._hash_password("password123")
        citizen = UserModel(
            id="USR_CITIZEN_001",
            mobileNumber="9876543210",
            passwordHash=c_hash,
            salt=c_salt,
            role="citizen",
            name="Demo Citizen",
            emergencyContactName="Family Contact",
            emergencyContactPhone="9999999999",
        )
        self._users_by_mobile[citizen.mobileNumber] = citizen

        # Default responder
        r_hash, r_salt = self._hash_password("responder123")
        responder = UserModel(
            id="USR_RESPONDER_001",
            mobileNumber="9000000000",
            passwordHash=r_hash,
            salt=r_salt,
            role="responder",
            name="Responder Unit 1",
            emergencyContactName="Dispatch Center",
            emergencyContactPhone="102",
        )
        self._users_by_mobile[responder.mobileNumber] = responder

        # Default dual user (Citizen + Responder capabilities)
        d_hash, d_salt = self._hash_password("dual123")
        dual_user = UserModel(
            id="USR_DUAL_001",
            mobileNumber="9999999999",
            passwordHash=d_hash,
            salt=d_salt,
            role="dual",
            name="Demo Dual User",
            emergencyContactName="Dispatch & Family",
            emergencyContactPhone="112",
        )
        self._users_by_mobile[dual_user.mobileNumber] = dual_user

    def clear(self):
        self._users_by_mobile.clear()
        self._tokens.clear()
        self._seed_default_users()

    def get_by_mobile(self, mobile: str) -> Optional[UserModel]:
        return self._users_by_mobile.get(mobile)

    def create_user(
        self,
        mobile: str,
        password: str,
        name: str,
        role: str = "citizen",
        email: Optional[str] = None,
        emergency_contact_name: Optional[str] = "",
        emergency_contact_phone: Optional[str] = "",
        blood_group: Optional[str] = None,
        allergies: Optional[str] = None,
        medications: Optional[str] = None,
    ) -> UserModel:
        password_hash, salt = self._hash_password(password)
        user_id = f"USR_{int(time.time() * 1000)}_{role.upper()}"
        user = UserModel(
            id=user_id,
            mobileNumber=mobile,
            passwordHash=password_hash,
            salt=salt,
            role=role,
            name=name,
            email=email,
            emergencyContactName=emergency_contact_name or "",
            emergencyContactPhone=emergency_contact_phone or "",
            bloodGroup=blood_group,
            allergies=allergies,
            medications=medications,
        )
        self._users_by_mobile[mobile] = user
        return user

    def verify_credentials(self, mobile: str, password: str) -> Optional[UserModel]:
        user = self.get_by_mobile(mobile)
        if not user:
            return None
        check_hash, _ = self._hash_password(password, user.salt)
        if secrets.compare_digest(check_hash, user.passwordHash):
            return user
        return None

    def create_token(self, mobile: str) -> str:
        token = f"pukaar_token_{secrets.token_urlsafe(32)}"
        self._tokens[token] = mobile
        return token

    def get_user_by_token(self, token: str) -> Optional[UserModel]:
        mobile = self._tokens.get(token)
        if not mobile:
            return None
        return self.get_by_mobile(mobile)

    def revoke_token(self, token: str):
        self._tokens.pop(token, None)


# Global singleton instances for local dev backend
store = IncidentStore()
user_store = UserStore()
