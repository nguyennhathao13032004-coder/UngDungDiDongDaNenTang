import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/daily_health_report_model.dart';

class AiService {
  // Thay API Key của bạn vào đây
  static const String _apiKey = "AIzaSyB3iFI6m5Bix8zMPoO5PGv8L-efAz2In0M"; 

  static Future<String> generateHealthAssessment(DailyHealthReport report) async {
    try {
      // 1. Khởi tạo cấu hình vai trò hệ thống cho AI (System Instruction)
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // Dòng model tối ưu tốc độ và chi phí cho mobile
        apiKey: _apiKey,
        systemInstruction: Content.system(
          "Bạn là Trợ lý ảo tư vấn sức khỏe AI thông minh thuộc hệ thống SaHa Health. "
          "Nhiệm vụ của bạn là phân tích dữ liệu chỉ số sinh hiệu, lượng nước uống và nhật ký dùng thuốc "
          "thực tế của người dùng để đưa ra lời nhận xét y tế chuyên nghiệp, cảnh báo nguy cơ (nếu có) "
          "và hướng dẫn hành động cụ thể. Luôn phản hồi bằng tiếng Việt, giọng điệu ân cần, ngắn gọn, dễ hiểu. "
          "Tuyệt đối tuân thủ cấu trúc Markdown yêu cầu."
        ),
      );

      // 2. Kỹ nghệ thiết kế ngữ cảnh dữ liệu thật (Prompt Engineering)
      final String takenMedList = report.takenMedicines.isEmpty ? "- Không có" : report.takenMedicines.map((m) => "- $m").join("\n");
      final String missedMedList = report.missedMedicines.isEmpty ? "- Không bỏ sót viên nào" : report.missedMedicines.map((m) => "- $m").join("\n");

      final prompt = """
Hãy phân tích dữ liệu sức khỏe thực tế ngày ${report.date} của bệnh nhân sau đây và đưa ra đánh giá:

[DỮ LIỆU SINH HIỆU & NƯỚC UỐNG]
- Nhịp tim: ${report.heartRate} bpm
- Huyết áp: ${report.bloodPressure} mmHg
- Cân nặng: ${report.weight} kg
- Lượng nước đã uống: ${report.waterIntakeMl} ml / Mục tiêu: ${report.targetWaterMl} ml

[NHẬT KÝ DÙNG THUỐC]
* Thuốc ĐÃ uống hôm nay:
$takenMedList

* Thuốc CHƯA uống/BỎ SÓT hôm nay:
$missedMedList

Hãy xuất báo cáo chính xác theo cấu trúc Markdown dưới đây:
### 🩺 Đánh giá tổng quan ngày hôm nay
[Nhận xét tổng quát về các chỉ số sinh hiệu và mức độ tuân thủ uống nước, uống thuốc của người dùng]

### ⚠️ Cảnh báo nguy cơ (nếu có)
[Đưa ra cảnh báo đỏ nếu huyết áp tâm thu > 130 hoặc tâm trương > 85, nhịp tim bất thường, uống nước quá ít hoặc bỏ quên các loại thuốc quan trọng]

### 💡 Lời khuyên & Hướng dẫn hành động
- **Về sinh hiệu:** [Lời khuyên cụ thể]
- **Về nước uống:** [Lời khuyên cụ thể để đạt mục tiêu]
- **Về dùng thuốc:** [Nhắc nhở hoặc tuyên dương việc uống thuốc]
""";

      // 3. Thực thi gọi Gemini API
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "AI không thể đưa ra đánh giá lúc này.";
      
    } catch (e) {
      print("Lỗi gọi Gemini API: $e");
      return "❌ Đã xảy ra lỗi khi kết nối với hệ thống trí tuệ nhân tạo SaHa.";
    }
  }
}