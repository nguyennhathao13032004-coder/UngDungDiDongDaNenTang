import logging
from google import genai
from app.core.config import API_KEYS, CHAT_MODEL, _config

logger = logging.getLogger(__name__)

current_key_idx = 0
_client = None

def _init_client():
    global _client, current_key_idx
    key = API_KEYS[current_key_idx]
    logger.info("Khởi tạo Gemini Client với Key số %d/%d", current_key_idx + 1, len(API_KEYS))
    _client = genai.Client(api_key=key)

try:
    _init_client()
except Exception as e:
    logger.error("Lỗi khởi tạo Client: %s", e)

def chat_with_saha(user_message: str, history: list = None) -> str:
    global current_key_idx, _client

    if history is None:
        history = []

    for attempt in range(len(API_KEYS)):
        try:
            chat_session = _client.chats.create(
                model=CHAT_MODEL,
                config=_config,
                history=history
            )
            response = chat_session.send_message(user_message)
            logger.info("Phản hồi thành công từ Key số %d", current_key_idx + 1)
            return response.text

        except Exception as e:
            error_msg = str(e)
            if any(err in error_msg for err in [
                "429", "RESOURCE_EXHAUSTED",
                "403", "PERMISSION_DENIED",
                "503", "500"
            ]):
                logger.warning(
                    "Key %d/%d bị giới hạn, chuyển sang key tiếp theo...",
                    current_key_idx + 1, len(API_KEYS)
                )
                current_key_idx = (current_key_idx + 1) % len(API_KEYS)
                _init_client()
                continue
            else:
                logger.error("Lỗi không xác định: %s", error_msg)
                raise e

    raise RuntimeError("Tất cả %d API Keys đã bị giới hạn, thử lại sau!" % len(API_KEYS))