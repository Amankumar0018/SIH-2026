import hashlib
import os
import secrets
import sqlite3
import time
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

from app.database import get_connection, init_db
from app.models import AIIntelligenceModel, EmergencyIncidentModel, UserModel


class IncidentStore:
    """SQLite-backed persistent data store for Pukaar emergency incidents."""

    def __init__(self):
        init_db()

    def _row_to_incident(self, row: sqlite3.Row) -> EmergencyIncidentModel:
        ai_intel: Optional[AIIntelligenceModel] = None
        raw_ai = row["aiIntelligence"]
        if raw_ai:
            try:
                ai_intel = AIIntelligenceModel.model_validate_json(raw_ai)
            except Exception:
                ai_intel = None

        return EmergencyIncidentModel(
            id=row["id"],
            userId=row["userId"],
            category=row["category"],
            intent=row["intent"],
            latitude=row["latitude"],
            longitude=row["longitude"],
            accuracy=row["accuracy"],
            timestamp=row["timestamp"],
            priority=row["priority"],
            status=row["status"],
            assignedResponderId=row["assignedResponderId"],
            assignedResponderName=row["assignedResponderName"],
            assignedResponderPhone=row["assignedResponderPhone"],
            assignedResponderType=row["assignedResponderType"],
            responderLatitude=row["responderLatitude"],
            responderLongitude=row["responderLongitude"],
            estimatedArrivalMinutes=row["estimatedArrivalMinutes"],
            notes=row["notes"],
            aiIntelligence=ai_intel,
        )

    def clear(self):
        with get_connection() as conn:
            conn.execute("DELETE FROM incidents")

    def generate_id(self, category: str) -> str:
        while True:
            timestamp_ms = int(time.time() * 1000)
            rand_suffix = secrets.token_hex(4)
            new_id = f"INC_{timestamp_ms}_{category.upper()}_{rand_suffix}"
            with get_connection() as conn:
                cursor = conn.execute("SELECT 1 FROM incidents WHERE id = ?", (new_id,))
                if cursor.fetchone() is None:
                    return new_id

    def save(self, incident: EmergencyIncidentModel) -> EmergencyIncidentModel:
        ai_json = incident.aiIntelligence.model_dump_json() if incident.aiIntelligence else None
        with get_connection() as conn:
            cursor = conn.execute("SELECT 1 FROM incidents WHERE id = ?", (incident.id,))
            if cursor.fetchone() is not None:
                raise ValueError(f"Incident with ID '{incident.id}' already exists.")
            try:
                conn.execute(
                    """
                    INSERT INTO incidents (
                        id, userId, category, intent, latitude, longitude, accuracy,
                        timestamp, priority, status, assignedResponderId, assignedResponderName,
                        assignedResponderPhone, assignedResponderType, responderLatitude,
                        responderLongitude, estimatedArrivalMinutes, notes, aiIntelligence
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        incident.id,
                        incident.userId,
                        incident.category,
                        incident.intent,
                        incident.latitude,
                        incident.longitude,
                        incident.accuracy,
                        incident.timestamp,
                        incident.priority,
                        incident.status,
                        incident.assignedResponderId,
                        incident.assignedResponderName,
                        incident.assignedResponderPhone,
                        incident.assignedResponderType,
                        incident.responderLatitude,
                        incident.responderLongitude,
                        incident.estimatedArrivalMinutes,
                        incident.notes,
                        ai_json,
                    ),
                )
            except sqlite3.IntegrityError:
                raise ValueError(f"Incident with ID '{incident.id}' already exists.")
        return incident

    def get_by_id(self, incident_id: str) -> Optional[EmergencyIncidentModel]:
        with get_connection() as conn:
            cursor = conn.execute("SELECT * FROM incidents WHERE id = ?", (incident_id,))
            row = cursor.fetchone()
            if not row:
                return None
            return self._row_to_incident(row)

    def get_all(self) -> List[EmergencyIncidentModel]:
        with get_connection() as conn:
            cursor = conn.execute("SELECT * FROM incidents ORDER BY timestamp DESC")
            rows = cursor.fetchall()
            return [self._row_to_incident(row) for row in rows]

    def get_active(self) -> List[EmergencyIncidentModel]:
        with get_connection() as conn:
            cursor = conn.execute(
                "SELECT * FROM incidents WHERE status NOT IN ('resolved', 'cancelled') ORDER BY timestamp DESC"
            )
            rows = cursor.fetchall()
            return [self._row_to_incident(row) for row in rows]

    def update_status(self, incident_id: str, new_status: str) -> Optional[EmergencyIncidentModel]:
        with get_connection() as conn:
            cursor = conn.execute(
                "UPDATE incidents SET status = ? WHERE id = ?",
                (new_status, incident_id),
            )
            if cursor.rowcount == 0:
                return None
        return self.get_by_id(incident_id)

    def cancel(self, incident_id: str, reason: Optional[str] = None) -> Optional[EmergencyIncidentModel]:
        inc = self.get_by_id(incident_id)
        if not inc:
            return None
        notes = inc.notes
        if reason:
            notes = f"{notes}\nCancellation Reason: {reason}".strip() if notes else f"Cancellation Reason: {reason}"
        with get_connection() as conn:
            conn.execute(
                "UPDATE incidents SET status = 'cancelled', notes = ? WHERE id = ?",
                (notes, incident_id),
            )
        return self.get_by_id(incident_id)

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
        new_phone = responder_phone or inc.assignedResponderPhone
        new_type = responder_type or inc.assignedResponderType
        new_lat = responder_lat if responder_lat is not None else inc.responderLatitude
        new_lng = responder_lng if responder_lng is not None else inc.responderLongitude
        new_eta = eta_minutes if eta_minutes is not None else inc.estimatedArrivalMinutes

        with get_connection() as conn:
            cursor = conn.execute(
                """
                UPDATE incidents SET
                    assignedResponderId = ?,
                    assignedResponderName = ?,
                    assignedResponderPhone = ?,
                    assignedResponderType = ?,
                    responderLatitude = ?,
                    responderLongitude = ?,
                    estimatedArrivalMinutes = ?
                WHERE id = ?
                """,
                (
                    responder_id,
                    responder_name,
                    new_phone,
                    new_type,
                    new_lat,
                    new_lng,
                    new_eta,
                    incident_id,
                ),
            )
            if cursor.rowcount == 0:
                return None
        return self.get_by_id(incident_id)

    def update_ai_intelligence(
        self,
        incident_id: str,
        ai_intelligence: AIIntelligenceModel,
    ) -> Optional[EmergencyIncidentModel]:
        inc = self.get_by_id(incident_id)
        if not inc:
            return None
        ai_json = ai_intelligence.model_dump_json()
        with get_connection() as conn:
            cursor = conn.execute(
                "UPDATE incidents SET aiIntelligence = ? WHERE id = ?",
                (ai_json, incident_id),
            )
            if cursor.rowcount == 0:
                return None
        return self.get_by_id(incident_id)


class UserStore:
    """SQLite-backed persistent data store for Pukaar user accounts and auth tokens."""

    def __init__(self):
        init_db()
        self._seed_default_users()

    def _hash_password(self, password: str, salt_hex: Optional[str] = None) -> Tuple[str, str]:
        if not salt_hex:
            salt_bytes = os.urandom(16)
            salt_hex = salt_bytes.hex()
        else:
            salt_bytes = bytes.fromhex(salt_hex)
        hash_bytes = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt_bytes, 100000)
        return hash_bytes.hex(), salt_hex

    def _row_to_user(self, row: sqlite3.Row) -> UserModel:
        return UserModel(
            id=row["id"],
            mobileNumber=row["mobileNumber"],
            passwordHash=row["passwordHash"],
            salt=row["salt"],
            role=row["role"],
            name=row["name"],
            email=row["email"],
            emergencyContactName=row["emergencyContactName"] or "",
            emergencyContactPhone=row["emergencyContactPhone"] or "",
            bloodGroup=row["bloodGroup"],
            allergies=row["allergies"],
            medications=row["medications"],
        )

    def _seed_default_users(self):
        with get_connection() as conn:
            cursor = conn.execute(
                "SELECT mobileNumber FROM users WHERE mobileNumber IN (?, ?, ?)",
                ("9876543210", "9000000000", "9999999999"),
            )
            existing = {row["mobileNumber"] for row in cursor.fetchall()}

            # Default citizen
            if "9876543210" not in existing:
                c_hash, c_salt = self._hash_password("password123")
                conn.execute(
                    """
                    INSERT INTO users (
                        id, mobileNumber, passwordHash, salt, role, name,
                        emergencyContactName, emergencyContactPhone
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        "USR_CITIZEN_001",
                        "9876543210",
                        c_hash,
                        c_salt,
                        "citizen",
                        "Demo Citizen",
                        "Family Contact",
                        "9999999999",
                    ),
                )

            # Default responder
            if "9000000000" not in existing:
                r_hash, r_salt = self._hash_password("responder123")
                conn.execute(
                    """
                    INSERT INTO users (
                        id, mobileNumber, passwordHash, salt, role, name,
                        emergencyContactName, emergencyContactPhone
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        "USR_RESPONDER_001",
                        "9000000000",
                        r_hash,
                        r_salt,
                        "responder",
                        "Responder Unit 1",
                        "Dispatch Center",
                        "102",
                    ),
                )

            # Default dual user (Citizen + Responder capabilities)
            if "9999999999" not in existing:
                d_hash, d_salt = self._hash_password("dual123")
                conn.execute(
                    """
                    INSERT INTO users (
                        id, mobileNumber, passwordHash, salt, role, name,
                        emergencyContactName, emergencyContactPhone
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        "USR_DUAL_001",
                        "9999999999",
                        d_hash,
                        d_salt,
                        "dual",
                        "Demo Dual User",
                        "Dispatch & Family",
                        "112",
                    ),
                )

    def clear(self):
        with get_connection() as conn:
            conn.execute("DELETE FROM tokens")
            conn.execute("DELETE FROM users")
        self._seed_default_users()

    def get_by_mobile(self, mobile: str) -> Optional[UserModel]:
        with get_connection() as conn:
            cursor = conn.execute("SELECT * FROM users WHERE mobileNumber = ?", (mobile,))
            row = cursor.fetchone()
            if not row:
                return None
            return self._row_to_user(row)

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
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO users (
                    id, mobileNumber, passwordHash, salt, role, name,
                    email, emergencyContactName, emergencyContactPhone,
                    bloodGroup, allergies, medications
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user.id,
                    user.mobileNumber,
                    user.passwordHash,
                    user.salt,
                    user.role,
                    user.name,
                    user.email,
                    user.emergencyContactName,
                    user.emergencyContactPhone,
                    user.bloodGroup,
                    user.allergies,
                    user.medications,
                ),
            )
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
        now_iso = datetime.now(timezone.utc).isoformat()
        with get_connection() as conn:
            conn.execute(
                "INSERT INTO tokens (token, mobileNumber, createdAt) VALUES (?, ?, ?)",
                (token, mobile, now_iso),
            )
        return token

    def get_user_by_token(self, token: str) -> Optional[UserModel]:
        with get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT u.* FROM users u
                JOIN tokens t ON u.mobileNumber = t.mobileNumber
                WHERE t.token = ?
                """,
                (token,),
            )
            row = cursor.fetchone()
            if not row:
                return None
            return self._row_to_user(row)

    def revoke_token(self, token: str):
        with get_connection() as conn:
            conn.execute("DELETE FROM tokens WHERE token = ?", (token,))


# Global singleton instances for backend
store = IncidentStore()
user_store = UserStore()
