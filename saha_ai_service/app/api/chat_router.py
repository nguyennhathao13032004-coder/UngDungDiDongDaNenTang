import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.agent.chatbot import chat_with_saha
from supabase import create_client
from app.core.config import SUPABASE_URL, SUPABASE_KEY

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["Chat AI"])

class ChatRequest(BaseModel):
    message: str
    user_id: str
    user_context: str = "" 

class ChatResponse(BaseModel):
    status: str
    answer: str
    session_id: int

def _get_or_create_session(sb, user_id: str) -> int:
    try:
        existing = (
            sb.table("ai_chat_sessions")
            .select("id")
            .eq("user_id", user_id)  
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        if existing.data:
            return existing.data[0]["id"]

        new_session = (
            sb.table("ai_chat_sessions")
            .insert({
                "user_id": user_id,
                "title": "Cuộc trò chuyện mới"
            })
            .execute()
        )
        return new_session.data[0]["id"]
    except Exception as e:
        logger.error("Lỗi get/create session: %s", e)
        raise

@router.post("/chat", response_model=ChatResponse)
async def process_chat(request: ChatRequest):
    user_msg = request.message.strip()
    u_id = request.user_id.strip()

    if not user_msg:
        raise HTTPException(status_code=400, detail="Tin nhắn không được trống.")
    if not u_id:
        raise HTTPException(status_code=400, detail="user_id không được trống.")

    try:
        sb = create_client(SUPABASE_URL, SUPABASE_KEY)
        session_id = _get_or_create_session(sb, u_id)

        history_data = (
            sb.table("ai_chat_messages")
            .select("role, content")
            .eq("session_id", session_id)
            .order("created_at", desc=True)
            .limit(10)
            .execute()
        )

        context = [
            {
                "role": "model" if h["role"] in ["assistant", "model"] else "user",
                "parts": [{"text": h["content"]}]
            }
            for h in reversed(history_data.data)
        ]

        full_message = user_msg
        if request.user_context:
            full_message = f"[Thông tin người dùng: {request.user_context}]\n\nCâu hỏi: {user_msg}"

        answer = chat_with_saha(full_message, history=context)

        sb.table("ai_chat_messages").insert([
            {"session_id": session_id, "role": "user", "content": user_msg},
            {"session_id": session_id, "role": "model", "content": answer},
        ]).execute()

        sb.table("ai_chat_sessions").update(
            {"last_message_at": "now()"}
        ).eq("id", session_id).execute()

        return ChatResponse(status="success", answer=answer, session_id=session_id)

    except Exception as e:
        logger.error("Lỗi chat: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/chat/history/{user_id}")
async def get_history(user_id: str):
    try:
        sb = create_client(SUPABASE_URL, SUPABASE_KEY)

        session = (
            sb.table("ai_chat_sessions")
            .select("id")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )

        if not session.data:
            # Không có session → trả về rỗng, KHÔNG báo lỗi
            return {"status": "success", "messages": [], "session_id": None}

        session_id = session.data[0]["id"]

        messages = (
            sb.table("ai_chat_messages")
            .select("role, content, created_at")
            .eq("session_id", session_id)
            .order("created_at")
            .execute()
        )

        return {
            "status": "success",
            "session_id": session_id,
            "messages": messages.data
        }

    except Exception as e:
        logger.error("Lỗi get history: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/chat/history/{user_id}")
async def clear_history(user_id: str):
    try:
        sb = create_client(SUPABASE_URL, SUPABASE_KEY)
        sessions = (
            sb.table("ai_chat_sessions")
            .select("id")
            .eq("user_id", user_id)
            .execute()
        )
        if sessions.data:
            for s in sessions.data:
                sb.table("ai_chat_messages").delete().eq("session_id", s["id"]).execute()
            sb.table("ai_chat_sessions").delete().eq("user_id", user_id).execute()

        return {"status": "success", "message": "Đã xóa lịch sử chat."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def health_check():
    return {"status": "ok", "service": "SaHa AI Service"}