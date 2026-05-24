import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ai_chat_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final supabase = Supabase.instance.client;
  
  List<dynamic> _medications = [];
  Map<String, dynamic>? _healthMetric; // <-- Thêm biến lưu dữ liệu sinh hiệu
  bool _isLoading = true;
  
  // 1. Khai báo biến lưu tên người dùng
  String _userName = ''; 

  @override
  void initState() {
    super.initState();
    _getUserName(); // 2. Gọi hàm lấy tên
    _fetchData(); // <-- Đổi thành _fetchData để tải cả thuốc và sinh hiệu cùng lúc
  }

  // 3. Hàm trích xuất tên từ Supabase Session
  void _getUserName() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      // Tìm tên trong metadata, nếu trống thì dự phòng bằng cách cắt phần đầu của email
      final metadataName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
      
      setState(() {
        if (metadataName != null && metadataName.toString().trim().isNotEmpty) {
          _userName = metadataName.toString();
        } else {
          _userName = user.email?.split('@')[0] ?? 'bạn';
        }
      });
    }
  }

  // --- API LẤY TẤT CẢ DỮ LIỆU ---
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchMedications(),
      _fetchHealthMetrics(), // Gọi thêm API lấy sinh hiệu
    ]);
    setState(() => _isLoading = false);
  }

  // Hàm gọi API lấy danh sách thuốc từ Backend
  Future<void> _fetchMedications() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      // ⚠️ LƯU Ý: Nếu chạy máy thật, nhớ đổi 10.0.2.2 thành IP Wi-Fi của bạn (VD: 192.168.1.x)
      final url = Uri.parse('http://10.0.2.2:5188/api/MedicationSchedules/User/$userId');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        _medications = json.decode(response.body);
      } else {
        print('Lỗi gọi API Thuốc: ${response.statusCode}');
      }
    } catch (e) {
      print('Lỗi kết nối mạng: $e');
    }
  }

  // --- API LẤY DỮ LIỆU SINH HIỆU ---
  Future<void> _fetchHealthMetrics() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final url = Uri.parse('http://10.0.2.2:5188/api/DailyHealthMetrics/User/$userId/Today');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        _healthMetric = json.decode(response.body);
      }
    } catch (e) {
      print('Lỗi tải sinh hiệu: $e');
    }
  }

  // --- API CỘNG NƯỚC UỐNG ---
  Future<void> _addWater(int amount) async {
    if (_healthMetric == null) return;
    try {
      // 👇 Đã xóa dòng "final userId = supabase..." ở đây 👇
      final url = Uri.parse('http://10.0.2.2:5188/api/DailyHealthMetrics/Upsert');
      
      // Tạo bản sao dữ liệu và cộng thêm nước
      final updatedMetric = Map<String, dynamic>.from(_healthMetric!);
      updatedMetric['waterIntakeMl'] = (updatedMetric['waterIntakeMl'] ?? 0) + amount;
      
      // Chuyển ngày hiện tại sang chuẩn yyyy-MM-dd để gửi cho ASP.NET Core
      updatedMetric['date'] = DateTime.now().toIso8601String().split('T')[0];

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatedMetric),
      );

      if (response.statusCode == 200) {
        setState(() {
          _healthMetric = json.decode(response.body); // Cập nhật UI với số nước mới nhất
        });
      }
    } catch (e) {
      print('Lỗi thêm nước: $e');
    }
  }
  // --- API CẬP NHẬT SINH HIỆU ---
  Future<void> _updateVitals(int hr, String bp, double weight) async {
    if (_healthMetric == null) return;
    try {
      final url = Uri.parse('http://10.0.2.2:5188/api/DailyHealthMetrics/Upsert');
      
      final updatedMetric = Map<String, dynamic>.from(_healthMetric!);
      updatedMetric['heartRate'] = hr;
      updatedMetric['bloodPressure'] = bp;
      updatedMetric['weight'] = weight;
      updatedMetric['date'] = DateTime.now().toIso8601String().split('T')[0];

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatedMetric),
      );

      if (response.statusCode == 200) {
        setState(() {
          _healthMetric = json.decode(response.body); // Cập nhật ngay lên UI
        });
        _analyzeVitalsWithAI(hr, bp, weight);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật sinh hiệu!'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      print('Lỗi cập nhật sinh hiệu: $e');
    }
  }

  // Khung Popup nhập liệu sinh hiệu CÓ VOICE VÀ CAMERA OCR
  void _showUpdateVitalsDialog() {
    final hrController = TextEditingController(text: _healthMetric?['heartRate']?.toString() == '0' ? '' : _healthMetric?['heartRate']?.toString());
    final bpController = TextEditingController(text: _healthMetric?['bloodPressure']?.toString() == '0/0' ? '' : _healthMetric?['bloodPressure']?.toString());
    final weightController = TextEditingController(text: _healthMetric?['weight']?.toString() == '0' ? '' : _healthMetric?['weight']?.toString());

    stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;
    bool isScanning = false;
    String statusText = "Dùng Micro hoặc Camera để nhập...";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // 1. Hàm xử lý thu âm (Đã làm)
            void listen() async {
              if (!isListening) {
                bool available = await speech.initialize();
                if (available) {
                  setDialogState(() { isListening = true; statusText = "Đang nghe..."; });
                  speech.listen(
                    localeId: 'vi_VN',
                    onResult: (val) => setDialogState(() {
                      statusText = val.recognizedWords;
                      final textLower = statusText.toLowerCase();
                      
                      final hrMatch = RegExp(r'nhịp tim\s*(\d+)').firstMatch(textLower);
                      if (hrMatch != null) hrController.text = hrMatch.group(1)!;

                      final bpMatch = RegExp(r'huyết áp\s*(\d+)\s*(trên|phần|\/)\s*(\d+)').firstMatch(textLower);
                      if (bpMatch != null) bpController.text = '${bpMatch.group(1)}/${bpMatch.group(3)}';

                      final weightMatch = RegExp(r'cân nặng\s*(\d+)').firstMatch(textLower);
                      if (weightMatch != null) weightController.text = weightMatch.group(1)!;
                    }),
                  );
                }
              } else {
                setDialogState(() => isListening = false);
                speech.stop();
              }
            }

            // 2. Hàm xử lý quét Camera bằng Google ML Kit
            Future<void> scanImage() async {
              final picker = ImagePicker();
              // Mở camera để chụp
              final pickedFile = await picker.pickImage(source: ImageSource.camera);

              if (pickedFile != null) {
                setDialogState(() { isScanning = true; statusText = "AI đang phân tích ảnh..."; });
                try {
                  final inputImage = InputImage.fromFilePath(pickedFile.path);
                  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
                  final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

                  String text = recognizedText.text;
                  await textRecognizer.close();

                  // Thuật toán: Lọc ra tất cả các số có 2-3 chữ số trong ảnh
                  RegExp regExp = RegExp(r'\b\d{2,3}\b');
                  Iterable<RegExpMatch> matches = regExp.allMatches(text);
                  List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();

                  // Máy đo huyết áp điện tử thường hiển thị từ trên xuống: [SYS, DIA, PULSE]
                  if (numbers.length >= 3) {
                    setDialogState(() {
                      bpController.text = '${numbers[0]}/${numbers[1]}'; // 2 số đầu là huyết áp
                      hrController.text = '${numbers[2]}'; // Số thứ 3 là nhịp tim
                      statusText = "Đã trích xuất thành công!";
                    });
                  } else {
                    setDialogState(() => statusText = "Không tìm thấy đủ thông số trên máy đo.");
                  }
                } catch (e) {
                  print("Lỗi quét ảnh ML Kit: $e");
                  setDialogState(() => statusText = "Có lỗi xảy ra khi quét ảnh.");
                }
                setDialogState(() => isScanning = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Cập nhật sinh hiệu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // KHU VỰC NÚT BẤM AI (VOICE & CAMERA)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Nút Voice
                        GestureDetector(
                          onTap: isScanning ? null : listen,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: isListening ? Colors.red.shade100 : Colors.grey.shade200,
                            child: Icon(Icons.mic, color: isListening ? Colors.red : Colors.teal, size: 30),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Nút Camera OCR
                        GestureDetector(
                          onTap: isListening || isScanning ? null : scanImage,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: isScanning ? Colors.blue.shade100 : Colors.blue.shade50,
                            child: isScanning
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2))
                                : const Icon(Icons.camera_alt, color: Colors.blue, size: 30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                    
                    // CÁC Ô NHẬP LIỆU
                    TextField(controller: hrController, decoration: InputDecoration(labelText: 'Nhịp tim (bpm)', prefixIcon: const Icon(Icons.favorite, color: Colors.red), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    TextField(controller: bpController, decoration: InputDecoration(labelText: 'Huyết áp (VD: 120/80)', prefixIcon: const Icon(Icons.bloodtype, color: Colors.purple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                    TextField(controller: weightController, decoration: InputDecoration(labelText: 'Cân nặng (kg)', prefixIcon: const Icon(Icons.monitor_weight, color: Colors.orange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () {
                    final hr = int.tryParse(hrController.text) ?? 0;
                    final bp = bpController.text.isNotEmpty ? bpController.text : "0/0";
                    final weight = double.tryParse(weightController.text) ?? 0;
                    _updateVitals(hr, bp, weight);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Lưu'),
                )
              ],
            );
          }
        );
      }
    );
  }

  // --- BÁC SĨ AI PHÂN TÍCH SINH HIỆU ---
  Future<void> _analyzeVitalsWithAI(int hr, String bp, double weight) async {
    // 1. Hiện vòng xoay chờ AI suy nghĩ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );

    try {
      // 2. Cấu hình Gemini API bằng Key của bạn
      final apiKey = 'AIzaSyCTY0lNSxvukbDpjDpm0pr0gpVtPcSWHkA';
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

      // 3. Viết Prompt (Câu lệnh) ép AI đóng vai bác sĩ
      final prompt = '''
      Tôi là người dùng ứng dụng chăm sóc sức khỏe. Tôi vừa đo các chỉ số sinh hiệu hôm nay:
      - Nhịp tim: $hr bpm
      - Huyết áp: $bp mmHg
      - Cân nặng: $weight kg

      Hãy đóng vai một bác sĩ gia đình hoặc chuyên gia y tế. Nhận xét cực kỳ ngắn gọn (tối đa 3 câu) về các chỉ số này.
      Nếu có chỉ số nào đáng báo động (như huyết áp cao/thấp hoặc nhịp tim bất thường), hãy đưa ra lời khuyên khẩn cấp.
      Giọng điệu: Thân thiện, chuyên nghiệp, quan tâm.
      ''';

      // 4. Gửi dữ liệu và chờ AI trả lời
      final response = await model.generateContent([Content.text(prompt)]);
      final aiAdvice = response.text ?? 'Hệ thống AI đang bận, vui lòng thử lại sau.';

      // 5. Tắt vòng xoay và hiện kết quả
      if (mounted) {
        Navigator.pop(context); // Đóng vòng xoay
        _showAIAdviceDialog(aiAdvice); // Mở khung báo cáo
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('Lỗi gọi AI: $e');
    }
  }

  // Khung giao diện Bác sĩ AI kết luận
  void _showAIAdviceDialog(String advice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.teal, size: 28),
            SizedBox(width: 8),
            Text('Bác sĩ AI tư vấn', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          advice, 
          style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Đã hiểu và ghi nhận', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  // Hàm gọi API thêm thuốc mới
  Future<void> _addMedication(String name, String dosage, TimeOfDay time) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      
      // Chuyển đổi giờ từ Flutter (TimeOfDay) sang chuỗi chuẩn HH:mm:ss của PostgreSQL
      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
      
      // ⚠️ LƯU Ý: Nhớ đổi IP này cho khớp với IP ở hàm _fetchMedications
      final url = Uri.parse('http://10.0.2.2:5188/api/MedicationSchedules'); 

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          "userId": userId,
          "medicineName": name,
          "dosage": dosage,
          "timeToTake": timeString,
          "isTaken": false
        }),
      );

      if (response.statusCode == 201) {
        // Nếu tạo thành công, tải lại danh sách thuốc
        _fetchMedications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm lịch uống thuốc!'), backgroundColor: Colors.green),
          );
        }
      } else {
        print('Lỗi thêm thuốc: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Lỗi mạng khi thêm thuốc: $e');
    }
  }

  // Hiển thị khung nhập liệu từ dưới lên
  void _showAddBottomSheet() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép khung trượt lên khi bàn phím xuất hiện
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // Né bàn phím
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thêm lịch uống thuốc',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  // Nhập tên thuốc
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Tên thuốc',
                      prefixIcon: const Icon(Icons.medication),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Nhập liều lượng
                  TextField(
                    controller: dosageController,
                    decoration: InputDecoration(
                      labelText: 'Liều lượng (VD: 2 viên, 1 gói...)',
                      prefixIcon: const Icon(Icons.monitor_weight_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Chọn giờ uống
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    leading: const Icon(Icons.access_time, color: Colors.teal),
                    title: const Text('Giờ uống thuốc'),
                    trailing: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    onTap: () async {
                      final TimeOfDay? timeOfDay = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (timeOfDay != null) {
                        setModalState(() {
                          selectedTime = timeOfDay;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Nút Lưu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty && dosageController.text.isNotEmpty) {
                          _addMedication(nameController.text, dosageController.text, selectedTime);
                          Navigator.pop(context); // Đóng form sau khi thêm
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Lưu lịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Hàm gọi API cập nhật trạng thái uống thuốc (PUT)
  Future<void> _updateMedicationStatus(Map<String, dynamic> med, bool isTaken) async {
    try {
      final id = med['id'];
      // ⚠️ LƯU Ý: Giữ đúng IP giống các hàm trên (10.0.2.2 cho máy ảo)
      final url = Uri.parse('http://10.0.2.2:5188/api/MedicationSchedules/$id');

      // Gói lại dữ liệu cũ nhưng đổi trạng thái isTaken mới
      final updatedMed = Map<String, dynamic>.from(med);
      updatedMed['isTaken'] = isTaken;

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(updatedMed),
      );

      // Backend ASP.NET Core trả về 204 (NoContent) khi Update thành công
      if (response.statusCode == 204) {
        print('Cập nhật trạng thái thành công!');
        // Không cần gọi _fetchMedications() vì UI đã tự đổi màu trước cho mượt rồi
      } else {
        print('Lỗi cập nhật: ${response.statusCode} - ${response.body}');
        _fetchMedications(); // Lỗi thì tải lại data gốc
      }
    } catch (e) {
      print('Lỗi mạng khi cập nhật: $e');
      _fetchMedications(); // Lỗi thì tải lại data gốc
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardScreen(),
          _buildAIAssistantScreen(),
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Lịch thuốc',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy),
              label: 'Trợ lý AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddBottomSheet, // <-- ĐÃ GẮN HÀM VÀO ĐÂY
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add),
              label: const Text('Thêm lịch', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

// --- TAB 1: DASHBOARD SỨC KHỎE TỔNG QUAN ---
  Widget _buildDashboardScreen() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchData, // <-- Sửa thành _fetchData để làm mới toàn bộ
        color: Colors.teal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER: Lời chào
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chào ngày mới, $_userName',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tổng quan sức khỏe hôm nay',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    radius: 24,
                    child: const Icon(Icons.person, color: Colors.teal, size: 28),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // 2. MỤC TIÊU UỐNG NƯỚC (Water Tracker)
              _buildWaterTrackerCard(),
              const SizedBox(height: 24),

              // 3. CHỈ SỐ SINH HIỆU (Vitals)
              Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text('Chỉ số sinh hiệu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    InkWell(
      onTap: _showUpdateVitalsDialog,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.teal, size: 20),
            SizedBox(width: 4),
            Text('Cập nhật', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    )
  ],
),
              const SizedBox(height: 12),
              _buildVitalsGrid(),
              const SizedBox(height: 24),

              // 4. LỊCH UỐNG THUỐC (Đã làm)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch uống thuốc',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  TextButton(
                    onPressed: () {}, // Tương lai có thể mở trang xem lịch sử uống thuốc
                    child: const Text('Xem tất cả', style: TextStyle(color: Colors.teal)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              
              // Hiển thị danh sách thuốc (Dùng shrinkWrap để nhúng ListView vào ScrollView)
              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.teal)))
                  : _medications.isEmpty
                      ? _buildEmptyMedication()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(), // Tắt cuộn của ListView để cuộn chung với trang
                          itemCount: _medications.length,
                          itemBuilder: (context, index) {
                            final med = _medications[index];
                            final timeString = med['timeToTake'].toString().substring(0, 5);

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: med['isTaken'] ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.medication,
                                    color: med['isTaken'] ? Colors.green : Colors.orange,
                                  ),
                                ),
                                title: Text(
                                  med['medicineName'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(timeString, style: TextStyle(color: Colors.grey.shade600)),
                                      const SizedBox(width: 16),
                                      Icon(Icons.monitor_weight_outlined, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(med['dosage'], style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: med['isTaken'],
                                  activeColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      setState(() {
                                        med['isTaken'] = value;
                                      });
                                      _updateMedicationStatus(med, value);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
              const SizedBox(height: 80), // Chừa khoảng trống cho nút Floating Action Button không che mất nội dung
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET PHỤ GIAO DIỆN MỚI ---

  Widget _buildWaterTrackerCard() {
    // Trích xuất dữ liệu thực tế
    final currentWater = _healthMetric?['waterIntakeMl'] ?? 0;
    final targetWater = _healthMetric?['targetWaterMl'] ?? 2000;
    final double progress = targetWater > 0 ? (currentWater / targetWater) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.water_drop, color: Colors.blue, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mục tiêu uống nước', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress > 1.0 ? 1.0 : progress,
                          backgroundColor: Colors.blue.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$currentWater / ${targetWater}ml', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          // NÚT UỐNG NƯỚC (+200ml)
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 36),
            onPressed: () => _addWater(200), // Cộng 200ml mỗi lần bấm
          )
        ],
      ),
    );
  }

  Widget _buildVitalsGrid() {
    // Trích xuất dữ liệu thực tế từ Database
    final hr = _healthMetric?['heartRate']?.toString() ?? '0';
    final bp = _healthMetric?['bloodPressure']?.toString() ?? '0/0';
    final weight = _healthMetric?['weight']?.toString() ?? '0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildVitalCard('Nhịp tim', hr, 'bpm', Icons.favorite, Colors.red),
        _buildVitalCard('Huyết áp', bp, 'mmHg', Icons.bloodtype, Colors.purple),
        _buildVitalCard('Cân nặng', weight, 'kg', Icons.monitor_weight, Colors.orange),
      ],
    );
  }

  Widget _buildVitalCard(String title, String value, String unit, IconData icon, MaterialColor color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color.shade400, size: 24),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            // ĐÃ THÊM FITTEDBOX
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMedication() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
            child: Icon(Icons.medication_liquid, size: 50, color: Colors.teal.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có lịch uống thuốc nào.\nHãy thêm đơn thuốc mới!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, height: 1.5),
          ),
        ],
      ),
    );
  }

    // --- TAB 2: TRỢ LÝ ẢO AI ---
  Widget _buildAIAssistantScreen() {
    return const AiChatScreen();
  }

  // --- TAB 3: HỒ SƠ & ĐĂNG XUẤT ---
  Widget _buildProfileScreen() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          await supabase.auth.signOut();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 0,
        ),
      ),
    );
  }
}