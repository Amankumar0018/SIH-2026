from typing import Dict, Any, Optional
from fastapi import APIRouter, HTTPException, Depends, status, Header

from app.models import (
    UserLoginSchema,
    UserRegisterSchema,
    TokenResponseSchema,
    UserModel,
)
from app.security import get_current_user
from app.store import user_store

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=TokenResponseSchema)
def login(payload: UserLoginSchema) -> TokenResponseSchema:
    mobile = payload.mobileNumber.strip()
    user = user_store.verify_credentials(mobile, payload.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = user_store.create_token(user.mobileNumber)
    return TokenResponseSchema(
        accessToken=token,
        tokenType="bearer",
        role=user.role,
        mobileNumber=user.mobileNumber,
        name=user.name,
    )


@router.post("/register", response_model=TokenResponseSchema, status_code=status.HTTP_201_CREATED)
def register(payload: UserRegisterSchema) -> TokenResponseSchema:
    mobile = payload.mobileNumber.strip()
    if user_store.get_by_mobile(mobile):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"An account with mobile number '{mobile}' already exists.",
        )

    role = payload.role if payload.role in ["citizen", "responder", "dual"] else "citizen"

    user = user_store.create_user(
        mobile=mobile,
        password=payload.password,
        name=payload.name,
        role=role,
        email=payload.email,
        emergency_contact_name=payload.emergencyContactName,
        emergency_contact_phone=payload.emergencyContactPhone,
        blood_group=payload.bloodGroup,
        allergies=payload.allergies,
        medications=payload.medications,
    )

    token = user_store.create_token(user.mobileNumber)
    return TokenResponseSchema(
        accessToken=token,
        tokenType="bearer",
        role=user.role,
        mobileNumber=user.mobileNumber,
        name=user.name,
    )


@router.get("/me")
def get_current_user_profile(user: UserModel = Depends(get_current_user)) -> Dict[str, Any]:
    return {
        "status": "success",
        "user": {
            "id": user.id,
            "name": user.name,
            "mobileNumber": user.mobileNumber,
            "role": user.role,
            "email": user.email,
            "emergencyContactName": user.emergencyContactName,
            "emergencyContactPhone": user.emergencyContactPhone,
            "bloodGroup": user.bloodGroup,
            "allergies": user.allergies,
            "medications": user.medications,
        },
    }

@router.post("/logout")
def logout(
    authorization: Optional[str] = Header(None, alias="Authorization"),
    x_auth_token: Optional[str] = Header(None, alias="X-Auth-Token"),
) -> Dict[str, Any]:
    token: Optional[str] = None
    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:].strip()
    elif authorization:
        token = authorization.strip()
    elif x_auth_token:
        token = x_auth_token.strip()
    
    if token:
        user_store.revoke_token(token)
    
    return {"status": "success", "message": "Successfully logged out"}
