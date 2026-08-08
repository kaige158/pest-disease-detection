"""响应模型定义"""
from typing import Any, Optional, TypeVar, Generic
from pydantic import BaseModel

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    """统一API响应"""
    code: int = 200
    message: str = "success"
    data: Optional[T] = None

    @classmethod
    def ok(cls, data: Any = None, message: str = "success"):
        return cls(code=200, message=message, data=data)

    @classmethod
    def error(cls, code: int, message: str):
        return cls(code=code, message=message, data=None)


class PaginatedData(BaseModel, Generic[T]):
    """分页数据"""
    items: list[T] = []
    total: int = 0
    page: int = 1
    page_size: int = 20
