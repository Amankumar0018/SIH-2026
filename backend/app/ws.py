import json
from typing import Dict, Optional
from fastapi import WebSocket
from app.models import EmergencyIncidentModel, UserModel


class ConnectionManager:
    """Manages active authenticated WebSocket connections and delivers isolated realtime events."""

    def __init__(self):
        # Maps active WebSocket instance to the authenticated UserModel
        self.active_connections: Dict[WebSocket, UserModel] = {}

    async def connect(self, websocket: WebSocket, user: UserModel):
        await websocket.accept()
        self.active_connections[websocket] = user

    def disconnect(self, websocket: WebSocket):
        self.active_connections.pop(websocket, None)

    async def broadcast_incident_event(
        self,
        event_type: str,
        incident: EmergencyIncidentModel,
    ):
        """Dispatches incident event to authorized clients.
        
        - Responders and Dual users receive all incident events.
        - Citizens receive events ONLY if the incident belongs to them.
        """
        payload = {
            "type": event_type,
            "incident": incident.model_dump(),
        }
        message_text = json.dumps(payload)

        # Snapshot active connections to avoid mutation issues during iteration
        connections_snapshot = list(self.active_connections.items())
        disconnected_sockets = []

        for ws, user in connections_snapshot:
            should_send = False

            if user.role in ["responder", "dual"]:
                should_send = True
            elif incident.userId == user.mobileNumber or incident.userId == user.id:
                should_send = True

            if should_send:
                try:
                    await ws.send_text(message_text)
                except Exception:
                    disconnected_sockets.append(ws)

        for ws in disconnected_sockets:
            self.disconnect(ws)


connection_manager = ConnectionManager()
