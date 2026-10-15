from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import get_settings


settings = get_settings()


app = FastAPI(
    title=settings.app_name,
    description=(
        "API central de MIGO DRIVE para pasajeros, "
        "conductores y administracion."
    ),
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.include_router(
    api_router,
    prefix=settings.api_v1_prefix,
)


@app.get(
    "/",
    include_in_schema=False,
)
def root() -> dict[str, str]:
    return {
        "message": "MIGO DRIVE API",
        "environment": settings.environment,
        "documentation": "/docs",
    }

