"""全局异常处理"""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class AppException(Exception):
    """应用基础异常"""
    def __init__(self, message: str, code: int = 400):
        self.message = message
        self.code = code


class NotFoundException(AppException):
    """资源不存在"""
    def __init__(self, message: str = "资源不存在"):
        super().__init__(message, code=404)


class AIServiceException(AppException):
    """AI服务异常"""
    def __init__(self, message: str = "AI服务暂时不可用"):
        super().__init__(message, code=502)


class ValidationException(AppException):
    """参数校验异常"""
    def __init__(self, message: str = "请求参数错误"):
        super().__init__(message, code=400)


def register_exception_handlers(app: FastAPI):
    """注册全局异常处理器"""

    @app.exception_handler(AppException)
    async def app_exception_handler(request: Request, exc: AppException):
        return JSONResponse(
            status_code=exc.code,
            content={"code": exc.code, "message": exc.message, "data": None},
        )

    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        # 生产环境不暴露内部错误详情
        return JSONResponse(
            status_code=500,
            content={"code": 500, "message": "服务器内部错误", "data": None},
        )
