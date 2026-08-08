"""AI服务 — 诊断Agent API"""
import time
import uuid

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.diagnosis_agent import DiagnosisAgent, DiagnosisSession, QuestionType

router = APIRouter()

# 简单内存存储，生产环境换Redis
_sessions: dict[str, DiagnosisSession] = {}


class AgentRequest(BaseModel):
    session_id: str = ""
    version: str = "vegetable"
    language: str = "zh"
    answer: str = ""  # 用户对上一个问题的回答
    answer_key: str = ""  # 回答对应的键


class AgentResponse(BaseModel):
    session_id: str
    step: int
    completed: bool
    question_text_zh: str
    question_text_lo: str
    question_type: str
    options: list = []
    multi_select: bool = False
    image_help: bool = False
    diagnosis: dict | None = None  # 完成时返回诊断结果


@router.post("/diagnose")
async def start_or_continue_diagnosis(request: AgentRequest):
    """启动或继续诊断会话"""

    # 获取或创建会话
    session_id = request.session_id or f"diag_{uuid.uuid4().hex[:8]}"
    if session_id not in _sessions:
        session = DiagnosisSession(session_id=session_id)
        _sessions[session_id] = session
    else:
        session = _sessions[session_id]

    # 创建Agent
    agent = DiagnosisAgent(version=request.version, language=request.language)

    # 如果用户提交了答案
    if request.answer_key and request.answer:
        session.add_answer(request.answer_key, request.answer)

    # 获取下一个问题
    next_q = agent.get_next_question(session)

    if next_q is None:
        return AgentResponse(
            session_id=session_id,
            step=session.step,
            completed=True,
            question_text_zh="诊断完成",
            question_text_lo="ການວິນິດໄສສຳເລັດ",
            question_type="completed",
        )

    diagnosis = None
    if next_q.question_type == QuestionType.DIAGNOSIS:
        diagnosis = {
            "text_zh": next_q.text_zh,
            "text_lo": next_q.text_lo,
            "possible_diseases": next_q.options,
            "answers": session.answers,
        }
        session.completed = True

    return AgentResponse(
        session_id=session_id,
        step=session.step,
        completed=session.completed,
        question_text_zh=next_q.text_zh,
        question_text_lo=next_q.text_lo,
        question_type=next_q.question_type.value,
        options=[{
            "value": o["value"],
            "label_zh": o.get("label_zh", o.get("label", "")),
            "label_lo": o.get("label_lo", ""),
            "confidence": o.get("confidence", 0),
        } for o in next_q.options],
        multi_select=next_q.multi_select,
        image_help=next_q.image_help,
        diagnosis=diagnosis,
    )


@router.post("/diagnose/reset")
async def reset_diagnosis(request: AgentRequest):
    """重置诊断会话"""
    if request.session_id in _sessions:
        del _sessions[request.session_id]
    return {"status": "reset"}


@router.get("/diagnose/health")
async def diagnose_health():
    return {"status": "ok", "active_sessions": len(_sessions)}
