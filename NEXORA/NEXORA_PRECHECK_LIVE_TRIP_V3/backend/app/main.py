from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import settings


app = FastAPI(
    title=settings.app_name,
)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "message": "MIGO DRIVE API",
        "environment": settings.environment,
        "documentation": "/docs",
    }


app.include_router(
    api_router,
    prefix="/api/v1",
)
