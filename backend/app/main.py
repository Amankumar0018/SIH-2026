from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.health import router as health_router
from app.routes.incidents import router as incidents_router
from app.routes.auth import router as auth_router

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



@app.get("/")
def root():
    return {
        "message": "Pukaar Emergency Response Backend API is running.",
        "health_check": "/health",
        "docs": "/docs",
    }
