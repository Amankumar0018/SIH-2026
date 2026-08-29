from datetime import datetime, timezone
from enum import Enum
from typing import Optional, Any, Dict, List
from pydantic import BaseModel, Field


class EmergencyCategoryEnum(str, Enum):
    medical = "medical"
    womenSafety = "womenSafety"
    disaster = "disaster"
    campus = "campus"


class EmergencyStatusEnum(str, Enum):
    created = "created"
    searching = "searching"
    dispatched = "dispatched"
    accepted = "accepted"
    inProgress = "inProgress"
    resolved = "resolved"
    cancelled = "cancelled"


class EmergencyPriorityEnum(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class EmergencyIncidentModel(BaseModel):
    id: str
    userId: str = "guest_user"
    category: str = "medical"
    intent: str = "General Emergency"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy: Optional[float] = None
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    priority: str = "high"
    status: str = "created"
    assignedResponderId: Optional[str] = None
    assignedResponderName: Optional[str] = None
    assignedResponderPhone: Optional[str] = None
    assignedResponderType: Optional[str] = None
    responderLatitude: Optional[float] = None
    responderLongitude: Optional[float] = None
    estimatedArrivalMinutes: Optional[int] = None
    notes: Optional[str] = None


class IncidentCreateSchema(BaseModel):
    id: Optional[str] = None
    userId: Optional[str] = "guest_user"
    category: str = "medical"
    intent: str = "General Emergency"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy: Optional[float] = None
    timestamp: Optional[str] = None
    priority: Optional[str] = "high"
    status: Optional[str] = "created"
    notes: Optional[str] = None


class StatusUpdateSchema(BaseModel):
    status: str


class CancelIncidentSchema(BaseModel):
    reason: Optional[str] = "User requested cancellation"


class AssignResponderSchema(BaseModel):
    responderId: str
    responderName: str
    responderPhone: Optional[str] = None
    responderType: Optional[str] = None
    responderLatitude: Optional[float] = None
    responderLongitude: Optional[float] = None
    estimatedArrivalMinutes: Optional[int] = None
