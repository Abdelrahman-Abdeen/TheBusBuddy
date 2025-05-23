from typing import Any, Generic, TypeVar
from sqlalchemy import Connection
from src.domain.entities.base_entity import BaseEntity
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.infrastructure.repositories.base_repo import BaseRepo

E = TypeVar("E", bound=BaseEntity)

class BaseServices(Generic[E]):
    def __init__(self, repo: BaseRepo[E], uow: UnitOfWork) -> None:
        self.repo = repo

    async def get_all(self) -> list[E]:
        async with UnitOfWork() as uow:
            return await self.repo.get_all(uow.connection)

    async def get_by_id(self, id: int | str) -> E:
        async with UnitOfWork() as uow:
            return await self.repo.get_by_id(id, uow.connection)

    async def create(self, data: dict[str, Any]) -> E:
        async with UnitOfWork() as uow:
            try:
                entity: E = self.repo.entity_type(**data)
                await self.repo.add(uow.connection, entity)
                return entity
            except Exception as e:
                raise ValueError(str(e))

    async def update(self, id: int | str, data: dict[str, Any]) -> E:
        async with UnitOfWork() as uow:
            if not await self.repo.update(uow.connection, id, data):
                raise ValueError('Failed to update entity')
            return await self._get_entity(id, uow.connection)

    async def delete(self, id: int | str) -> dict[str, str]:
        async with UnitOfWork() as uow:
            if not await self.repo.delete(id, uow.connection):
                raise ValueError('Failed to delete entity')
            return {'message': 'Entity deleted successfully'}

    async def _get_entity(self, id: int | str, connection: Connection) -> E:
        entity = await self.repo.get_by_id(id, connection)
        if not entity:
            raise ValueError('Entity not found')
        return entity

    def _validate_creation(self, entity: E, connection: Connection) -> None:
        if not entity:
            raise ValueError('Entity creation failed')
