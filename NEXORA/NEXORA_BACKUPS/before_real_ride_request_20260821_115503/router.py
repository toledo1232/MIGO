from fastapi import APIRouter

from app.api.v1.endpoints import auth, health, places
from app.api.v1.endpoints import routes as routes_endpoint


api_router = APIRouter()

api_router.include_router(
    health.router,
)

api_router.include_router(
    auth.router,
)
api_router.include_router(places.router)
api_router.include_router(routes_endpoint.router)
