from typing import List, Optional
from fastapi import APIRouter, Query
from app.database import db_manager
from app.models.schemas import KnowledgeReference
from app.services.knowledge_service import KnowledgeRetrievalService

router = APIRouter(prefix="/api/v1/knowledge", tags=["Clinical Knowledge"])


@router.get("", response_model=List[KnowledgeReference])
async def get_knowledge(
    q: Optional[str] = Query(None, description="Search term or vernacular expression")
):
    """Retrieve verified clinical guidelines and evidence references."""
    service = KnowledgeRetrievalService(db_manager)
    if q and q.strip():
        return await service.retrieve_relevant_knowledge(
            symptoms=[q.strip()],
            query_text=q.strip(),
            limit=10
        )
    return await service.get_all_knowledge()

