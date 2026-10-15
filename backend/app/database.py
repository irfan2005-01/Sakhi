import logging
import re
from typing import Optional, Dict, Any, List
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from app.config import settings

logger = logging.getLogger("sakhi.database")


class InMemoryAsyncCursor:
    """Async cursor emulation for in-memory fallback during local development or offline mode."""
    def __init__(self, items: List[Dict[str, Any]]):
        self._items = items
        self._index = 0

    def __aiter__(self):
        return self

    async def __anext__(self):
        if self._index < len(self._items):
            item = self._items[self._index]
            self._index += 1
            return item
        raise StopAsyncIteration

    async def to_list(self, length: Optional[int] = None) -> List[Dict[str, Any]]:
        if length is None:
            return list(self._items)
        return list(self._items[:length])


class InMemoryAsyncCollection:
    """Emulates MongoDB collection operations with async methods for high-reliability fallback."""
    def __init__(self, name: str):
        self.name = name
        self._data: List[Dict[str, Any]] = []

    async def insert_one(self, document: Dict[str, Any]):
        doc_copy = dict(document)
        if "_id" not in doc_copy:
            doc_copy["_id"] = str(len(self._data) + 1)
        self._data.append(doc_copy)
        class InsertResult:
            def __init__(self, inserted_id):
                self.inserted_id = inserted_id
        return InsertResult(doc_copy["_id"])

    async def insert_many(self, documents: List[Dict[str, Any]]):
        ids = []
        for doc in documents:
            res = await self.insert_one(doc)
            ids.append(res.inserted_id)
        class InsertManyResult:
            def __init__(self, inserted_ids):
                self.inserted_ids = inserted_ids
        return InsertManyResult(ids)

    async def find_one(self, filter: Optional[Dict[str, Any]] = None, sort: Optional[List] = None) -> Optional[Dict[str, Any]]:
        cursor = self.find(filter)
        items = await cursor.to_list(1)
        return items[0] if items else None

    def find(self, filter: Optional[Dict[str, Any]] = None, sort: Optional[List] = None) -> InMemoryAsyncCursor:
        results = []
        filter = filter or {}
        for item in self._data:
            match = True
            for k, v in filter.items():
                if k == "$text":
                    search_str = v.get("$search", "").lower()
                    text_blob = " ".join(str(val).lower() for val in item.values())
                    if search_str not in text_blob:
                        match = False
                        break
                elif isinstance(v, dict) and "$in" in v:
                    val_list = item.get(k, [])
                    if isinstance(val_list, list):
                        if not any(x in v["$in"] for x in val_list):
                            match = False
                            break
                    else:
                        if item.get(k) not in v["$in"]:
                            match = False
                            break
                elif item.get(k) != v:
                    match = False
                    break
            if match:
                results.append(item)

        if sort:
            # Simple sorting by single key
            for key, direction in reversed(sort):
                results.sort(key=lambda x: x.get(key, ""), reverse=(direction < 0))

        return InMemoryAsyncCursor(results)

    async def count_documents(self, filter: Optional[Dict[str, Any]] = None) -> int:
        cursor = self.find(filter)
        items = await cursor.to_list(None)
        return len(items)

    async def aggregate(self, pipeline: List[Dict[str, Any]]) -> InMemoryAsyncCursor:
        # Basic aggregate fallback for cycle analytics
        docs = list(self._data)
        for stage in pipeline:
            if "$match" in stage:
                match_filter = stage["$match"]
                docs = [d for d in docs if all(d.get(k) == v for k, v in match_filter.items())]
            elif "$sort" in stage:
                for k, direction in stage["$sort"].items():
                    docs.sort(key=lambda x: x.get(k, ""), reverse=(direction < 0))
            elif "$limit" in stage:
                docs = docs[:stage["$limit"]]
        return InMemoryAsyncCursor(docs)


class DatabaseManager:
    def __init__(self):
        self.client: Optional[AsyncIOMotorClient] = None
        self.db: Optional[AsyncIOMotorDatabase] = None
        self.is_connected: bool = False
        self.use_fallback: bool = False
        self.last_error: Optional[str] = None
        self._fallback_collections: Dict[str, InMemoryAsyncCollection] = {}

    async def connect(self):
        """Ping MongoDB before use; allow in-memory storage only in explicit demo mode."""
        if not settings.MONGODB_URI.strip():
            self.last_error = "ConfigurationError: MONGODB_URI is not configured."
            if not settings.DEMO_MODE:
                raise RuntimeError(self.last_error)
            self.use_fallback = True
            self._init_fallback_store()
            logger.warning("%s Using in-memory storage because DEMO_MODE=true.", self.last_error)
            return

        try:
            logger.info("Connecting to MongoDB database %s...", settings.MONGODB_DATABASE)
            self.client = AsyncIOMotorClient(
                settings.MONGODB_URI,
                serverSelectionTimeoutMS=15000,
                connectTimeoutMS=10000,
            )
            # Ping database to confirm live connection
            await self.client.admin.command('ping')
            self.db = self.client[settings.MONGODB_DATABASE]
            self.is_connected = True
            self.use_fallback = False
            self.last_error = None
            logger.info("Successfully connected to live MongoDB (%s)", settings.MONGODB_DATABASE)
        except Exception as e:
            error_message = str(e).replace(settings.MONGODB_URI, "<MongoDB URI redacted>")
            error_message = re.sub(
                r"(?i)(mongodb(?:\+srv)?://)[^/@\s]+@",
                r"\1<credentials-redacted>@",
                error_message,
            )
            self.last_error = f"{type(e).__name__}: {error_message}"
            if self.client:
                self.client.close()
                self.client = None
            if not settings.DEMO_MODE:
                self.is_connected = False
                self.use_fallback = False
                raise RuntimeError(f"MongoDB ping failed: {self.last_error}") from None
            logger.warning(
                "Could not connect to MongoDB (%s). Using in-memory storage because DEMO_MODE=true.",
                self.last_error,
            )
            self.is_connected = False
            self.use_fallback = True
            self._init_fallback_store()

    def _init_fallback_store(self):
        colls = [
            "clinical_knowledge_base",
            "patient_symptom_logs",
            "safety_audit_logs",
            "menstrual_cycles",
        ]
        for name in colls:
            if name not in self._fallback_collections:
                self._fallback_collections[name] = InMemoryAsyncCollection(name)

    async def disconnect(self):
        if self.client:
            self.client.close()
            logger.info("MongoDB connection closed.")

    def get_collection(self, name: str):
        if not self.use_fallback and self.db is not None:
            return self.db[name]
        if name not in self._fallback_collections:
            self._fallback_collections[name] = InMemoryAsyncCollection(name)
        return self._fallback_collections[name]

    @property
    def knowledge_collection(self):
        return self.get_collection("clinical_knowledge_base")

    @property
    def symptom_logs_collection(self):
        return self.get_collection("patient_symptom_logs")

    @property
    def safety_audit_collection(self):
        return self.get_collection("safety_audit_logs")

    @property
    def cycles_collection(self):
        return self.get_collection("menstrual_cycles")


db_manager = DatabaseManager()

