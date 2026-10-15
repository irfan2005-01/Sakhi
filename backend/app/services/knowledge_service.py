import re
from typing import List, Dict, Any, Optional
from app.models.schemas import KnowledgeReference
from app.seed.knowledge_seed import CLINICAL_KNOWLEDGE_ENTRIES
import logging

logger = logging.getLogger("sakhi.knowledge_service")


class KnowledgeRetrievalService:
    def __init__(self, db_manager):
        self.db_manager = db_manager

    async def retrieve_relevant_knowledge(
        self,
        symptoms: List[str],
        query_text: str,
        limit: int = 3
    ) -> List[KnowledgeReference]:
        """
        Multi-stage retrieval:
        1. Attempt database search based on matching vernacular terms & concepts
        2. Fallback to ranked keyword matching if indexes or database not ready
        """
        collection = self.db_manager.knowledge_collection
        search_terms = [s.lower() for s in symptoms]
        query_words = set(re.findall(r"\w+", query_text.lower()))
        search_terms.extend(query_words)

        matched_entries: List[Dict[str, Any]] = []

        try:
            # Query all entries to perform robust multi-lingual vernacular matching
            cursor = collection.find({})
            all_entries = await cursor.to_list(length=50)
            if not all_entries:
                all_entries = list(CLINICAL_KNOWLEDGE_ENTRIES)
        except Exception as e:
            logger.warning("Database query failed in knowledge retrieval: %s. Using default seed.", str(e))
            all_entries = list(CLINICAL_KNOWLEDGE_ENTRIES)

        # Score entries by keyword and vernacular overlap
        scored_entries = []
        for entry in all_entries:
            score = 0
            v_terms = [v.lower() for v in entry.get("vernacular_terms", [])]
            title = entry.get("title", "").lower()
            concept = entry.get("concept", "").lower()
            explanation = entry.get("plain_explanation", "").lower()

            for term in search_terms:
                if len(term) < 3:
                    continue
                # Exact or partial match in vernacular expressions
                if any(term in vt or vt in term for vt in v_terms):
                    score += 4
                if term in title:
                    score += 3
                if term in concept:
                    score += 2
                if term in explanation:
                    score += 1

            if score > 0:
                scored_entries.append((score, entry))

        # Sort by score descending
        scored_entries.sort(key=lambda x: x[0], reverse=True)
        matched_entries = [entry for _, entry in scored_entries[:limit]]

        # If no specific match, provide foundational Rotterdam criteria entry
        if not matched_entries and all_entries:
            matched_entries = [all_entries[0]]

        return [
            KnowledgeReference(
                id=item.get("id", "kb-general"),
                title=item.get("title", "Clinical Reference"),
                topic=item.get("topic", "General"),
                concept=item.get("concept", ""),
                plain_explanation=item.get("plain_explanation", ""),
                vernacular_terms=item.get("vernacular_terms", []),
                source_org=item.get("source_org", "Verifiable Medical Authority"),
                source_url=item.get("source_url", "https://www.acog.org"),
                evidence_excerpt=item.get("evidence_excerpt", ""),
                review_status=item.get("review_status", "reviewed"),
                is_demo=item.get("is_demo", False),
            )
            for item in matched_entries
        ]

    async def get_all_knowledge(self) -> List[KnowledgeReference]:
        """Return all available clinical knowledge entries."""
        collection = self.db_manager.knowledge_collection
        try:
            cursor = collection.find({})
            docs = await cursor.to_list(length=100)
            if not docs:
                docs = list(CLINICAL_KNOWLEDGE_ENTRIES)
        except Exception:
            docs = list(CLINICAL_KNOWLEDGE_ENTRIES)

        return [
            KnowledgeReference(
                id=d.get("id", ""),
                title=d.get("title", ""),
                topic=d.get("topic", ""),
                concept=d.get("concept", ""),
                plain_explanation=d.get("plain_explanation", ""),
                vernacular_terms=d.get("vernacular_terms", []),
                source_org=d.get("source_org", ""),
                source_url=d.get("source_url", ""),
                evidence_excerpt=d.get("evidence_excerpt", ""),
                review_status=d.get("review_status", "reviewed"),
                is_demo=d.get("is_demo", False),
            )
            for d in docs
        ]

