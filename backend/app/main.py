from fastapi import FastAPI, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional

from app.routes.health import router as health_router
from app.routes.incidents import router as incidents_router
from app.routes.auth import router as auth_router
from app.store import user_store
from app.ws import connection_manager

app = FastAPI(
    title="Pukaar Emergency Response API",
    description="Backend API for Pukaar Emergency Coordination Platform",
    version="1.0.0",
)

# Enable CORS for Flutter mobile/web development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include endpoint routers
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(incidents_router)


@app.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: Optional[str] = None,
):
    # Extract auth token from query params or headers
    auth_token = token or websocket.query_params.get("token")
    if auth_token:
        auth_token = auth_token.strip()

    if not auth_token:
        auth_header = websocket.headers.get("Authorization") or websocket.headers.get("authorization")
        if auth_header and auth_header.startswith("Bearer "):
            auth_token = auth_header[7:].strip()
        elif auth_header:
            auth_token = auth_header.strip()
        else:
            auth_token = websocket.headers.get("X-Auth-Token") or websocket.headers.get("x-auth-token")
            if auth_token:
                auth_token = auth_token.strip()

    if not auth_token:
        # Reject unauthorized connection
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user = user_store.get_user_by_token(auth_token)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await connection_manager.connect(websocket, user)
    try:
        while True:
            # Keep connection open and consume incoming client frames / pings
            await websocket.receive_text()
    except WebSocketDisconnect:
        connection_manager.disconnect(websocket)
    except Exception:
        connection_manager.disconnect(websocket)


@app.get("/")
def root():
    return {
        "message": "Pukaar Emergency Response Backend API is running.",
        "health_check": "/health",
        "docs": "/docs",
    }

