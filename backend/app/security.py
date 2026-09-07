from typing import List, Optional
from fastapi import Depends, HTTPException, Header, status, Request
from app.models import UserModel
from app.store import user_store


def get_current_user(
    request: Request,
    authorization: Optional[str] = Header(None, alias="Authorization"),
    x_auth_token: Optional[str] = Header(None, alias="X-Auth-Token"),
) -> UserModel:
    """Extracts and validates the authentication token from incoming request headers."""
    token: Optional[str] = None

    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:].strip()
    elif authorization:
        token = authorization.strip()
    elif x_auth_token:
        token = x_auth_token.strip()

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication credentials.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = user_store.get_user_by_token(token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


def require_role(allowed_roles: List[str]):
    """Dependency factory returning a dependency that enforces specified role(s)."""
    def role_checker(user: UserModel = Depends(get_current_user)) -> UserModel:
        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Action forbidden for role '{user.role}'. Required role(s): {allowed_roles}.",
            )
        return user
    return role_checker


require_responder = require_role(["responder", "dual"])
require_citizen_or_responder = require_role(["citizen", "responder", "dual"])


def check_incident_access(user: UserModel, incident_user_id: str) -> bool:
    """Verifies whether the authenticated user has authorization to view or cancel the incident.

    - Responders and Dual users have authorization under the responder authority model.
    - Citizens have authorization ONLY if the incident belongs to them.
    """
    if user.role in ["responder", "dual"]:
        return True
    return incident_user_id == user.mobileNumber or incident_user_id == user.id

