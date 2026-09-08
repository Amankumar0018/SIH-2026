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


class AIIntelligenceModel(BaseModel):
    summary: str = Field(..., max_length=500)
    urgencyScore: str = Field(..., max_length=50)
    hazards: List[str] = Field(default_factory=list)
    recommendedActions: List[str] = Field(default_factory=list)
    missingInfo: List[str] = Field(default_factory=list)
    source: str = Field(default="rule_based", max_length=50)
    confidence: float = Field(default=0.5, ge=0.0, le=1.0)
    generatedAt: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


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
    aiIntelligence: Optional[AIIntelligenceModel] = None


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


class UserRoleEnum(str, Enum):
    citizen = "citizen"
    responder = "responder"
    dual = "dual"


class UserRegisterSchema(BaseModel):
    mobileNumber: str
    password: str
    name: str
    role: str = "citizen"
    email: Optional[str] = None
    emergencyContactName: Optional[str] = ""
    emergencyContactPhone: Optional[str] = ""
    bloodGroup: Optional[str] = None
    allergies: Optional[str] = None
    medications: Optional[str] = None


class UserLoginSchema(BaseModel):
    mobileNumber: str
    password: str


class TokenResponseSchema(BaseModel):
    accessToken: str
    tokenType: str = "bearer"
    role: str
    mobileNumber: str
    name: str


class UserModel(BaseModel):
    id: str
    mobileNumber: str
    passwordHash: str
    salt: str
    role: str = "citizen"
    name: str
    email: Optional[str] = None
    emergencyContactName: Optional[str] = ""
    emergencyContactPhone: Optional[str] = ""
    bloodGroup: Optional[str] = None
    allergies: Optional[str] = None
    medications: Optional[str] = None


class AssignResponderSchema(BaseModel):
    responderId: str
    responderName: str
    responderPhone: Optional[str] = None
    responderType: Optional[str] = None
    responderLatitude: Optional[float] = None
    responderLongitude: Optional[float] = None
    estimatedArrivalMinutes: Optional[int] = None
