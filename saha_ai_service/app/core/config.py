import os
import logging
from dotenv import load_dotenv
from google import genai

logger = logging.getLogger(__name__)
load_dotenv()

# === QUÉT TỰ ĐỘNG CÁC API KEYS ===
API_KEYS = []
for i in range(10):
    key = os.getenv(f"GEMINI_API_KEY_{i}")
    if key:
        API_KEYS.append(key.strip())

# Tương thích ngược với GEMINI_API_KEYS (dạng cũ, phân cách bằng dấu phẩy)
if not API_KEYS:
    old_keys = os.getenv("GEMINI_API_KEYS", "")
    API_KEYS = [k.strip() for k in old_keys.split(",") if k.strip()]

if not API_KEYS:
    raise ValueError("Lỗi: Không tìm thấy bất kỳ GEMINI_API_KEY nào trong file .env")

logger.info("Đã nạp thành công %d API Keys vào hệ thống.", len(API_KEYS))

# === SUPABASE ===
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not all([SUPABASE_URL, SUPABASE_KEY]):
    raise ValueError("Lỗi: Thiếu biến môi trường Supabase.")

# === MODEL ===
CHAT_MODEL = os.getenv("CHAT_MODEL", "gemini-2.5-flash")

# === SYSTEM PROMPT ===
SYSTEM_PROMPT = """Bạn là SaHa - trợ lý sức khỏe cá nhân thông minh của ứng dụng SaHaBa Health.

NHIỆM VỤ:
- Tư vấn sức khỏe cá nhân dựa trên thông tin người dùng cung cấp
- Giải thích các chỉ số sinh hiệu: nhịp tim, huyết áp, cân nặng, BMI
- Tư vấn về lịch uống thuốc, tác dụng phụ, tương tác thuốc
- Đưa lời khuyên về chế độ dinh dưỡng, uống nước hàng ngày
- Trả lời câu hỏi sức khỏe tổng quát

NGUYÊN TẮC:
- Luôn trả lời bằng tiếng Việt, thân thiện, dễ hiểu
- Không chẩn đoán bệnh thay bác sĩ
- Khuyến khích gặp bác sĩ khi có triệu chứng nghiêm trọng
- Câu trả lời ngắn gọn, tối đa 4-5 câu
- Xưng: gọi người dùng là "bạn", tự xưng là "SaHa"
- BMI: <18.5 thiếu cân | 18.5-24.9 bình thường | 25-29.9 thừa cân | >30 béo phì
- Khi nhắc thuốc: luôn nhắc uống đúng giờ và đủ liều
"""

# === GEMINI CONFIG ===
_config = genai.types.GenerateContentConfig(
    system_instruction=SYSTEM_PROMPT,
    temperature=0.7,
)