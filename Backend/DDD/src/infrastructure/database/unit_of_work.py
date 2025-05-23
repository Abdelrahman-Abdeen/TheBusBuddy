from types import TracebackType
from typing import Any, Type

from sqlalchemy import Result
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine, AsyncTransaction

from src.infrastructure.database.connection import engine


class UnitOfWork:
    def __init__(self) -> None:
        self.engine: AsyncEngine = engine
        self._connection: AsyncConnection | None = None
        self._transaction: AsyncTransaction | None = None

    async def __aenter__(self) -> 'UnitOfWork':
        self._connection = await engine.connect()
        self._transaction = await self._connection.begin()
        return self

    async def __aexit__(
        self,
        exc_type: Type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        if self._transaction is None:
            raise RuntimeError('Transaction not initialized')

        if exc_type is None:
            await self._transaction.commit()
        else:
            await self._transaction.rollback()

    @property
    def connection(self) -> AsyncConnection:
        if self._connection is None:
            raise RuntimeError('Connection not initialized')
        return self._connection

    async def execute(self, statement: Any) -> Result[Any]:
        return await self.connection.execute(statement)

    async def fetchone(self, statement: Any) -> Any:
        result = await self.execute(statement)
        return result.fetchone()

    async def fetchall(self, statement: Any) -> Any:
        result = await self.execute(statement)
        return result.fetchall()