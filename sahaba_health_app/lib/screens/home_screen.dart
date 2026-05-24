import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'bmi_screen.dart';
import 'water_notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final supabase = Supabase.instance.client;
  List<dynamic> _medications = [];
  Map<String, dynamic>? _healthMetric;
  bool _isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _getUserName();
    _fetchData();
  }

  void _getUserName() {
    final user = supabase.auth.currentUser;
    if (user != null) {
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

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchMedications(), _fetchHealthMetrics()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchMedications() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final url = Uri.parse('http://10.0.2.2:5188/api/MedicationSchedules/User/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _medications = json.decode(response.body);
      }
    } catch (e) {
      print('Lỗi kết nối mạng: $e');
    }
  }

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

  Future<void> _addWater(int amount) async {
    if (_healthMetric == null) return;
    try {
      final url = Uri.parse('http://10.0.2.2:5188/api/DailyHealthMetrics/Upsert');
      final updatedMetric = Map<String, dynamic>.from(_healthMetric!);
      updatedMetric['waterIntakeMl'] = (updatedMetric['waterIntakeMl'] ?? 0) + amount;
      updatedMetric['date'] = DateTime.now().toIso8601String().split('T')[0];
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: json.encode(updatedMetric));
      if (response.statusCode == 200) {
        setState(() { _healthMetric = json.decode(response.body); });
      }
    } catch (e) {
      print('Lỗi thêm nước: $e');
    }
  }

  Future<void> _updateVitals(int hr, String bp, double weight) async {
    if (_healthMetric == null) return;
    try {
      final url = Uri.parse('http://10.0.2.2:5188/api/DailyHealthMetrics/Upsert');
      final updatedMetric = Map<String, dynamic>.from(_healthMetric!);
      updatedMetric['heartRate'] = hr;
      updatedMetric['bloodPressure'] = bp;
      updatedMetric['weight'] = weight;
      updatedMetric['date'] = DateTime.now().toIso8601String().split('T')[0];
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: json.encode(updatedMetric));
      if (response.statusCode == 200) {
        setState(() { _healthMetric = json.decode(response.body); });
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
        return StatefulBuilder(builder: (context, setDialogState) {
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

          Future<void> scanImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(source: ImageSource.camera);
            if (pickedFile != null) {
              setDialogState(() { isScanning = true; statusText = "AI đang phân tích ảnh..."; });
              try {
                final inputImage = InputImage.fromFilePath(pickedFile.path);
                final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
                final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
                String text = recognizedText.text;
                await textRecognizer.close();
                RegExp regExp = RegExp(r'\b\d{2,3}\b');
                Iterable<RegExpMatch> matches = regExp.allMatches(text);
                List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();
                if (numbers.length >= 3) {
                  setDialogState(() {
                    bpController.text = '${numbers[0]}/${numbers[1]}';
                    hrController.text = '${numbers[2]}';
                    statusText = "Đã trích xuất thành công!";
                  });
                } else {
                  setDialogState(() => statusText = "Không tìm thấy đủ thông số trên máy đo.");
                }
              } catch (e) {
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: isScanning ? null : listen,
                        child: CircleAvatar(radius: 30, backgroundColor: isListening ? Colors.red.shade100 : Colors.grey.shade200, child: Icon(Icons.mic, color: isListening ? Colors.red : Colors.teal, size: 30)),
                      ),
                      const SizedBox(width: 24),
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
                  Text(statusText, textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 13)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
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
        });
      },
    );
  }

  Future<void> _analyzeVitalsWithAI(int hr, String bp, double weight) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.teal)));
    try {
      final apiKey = 'AIzaSyCTY0lNSxvukbDpjDpm0pr0gpVtPcSWHkA';
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final prompt = '''
      Tôi là người dùng ứng dụng chăm sóc sức khỏe. Tôi vừa đo các chỉ số sinh hiệu hôm nay:
      - Nhịp tim: $hr bpm
      - Huyết áp: $bp mmHg
      - Cân nặng: $weight kg
      Hãy đóng vai một bác sĩ gia đình. Nhận xét ngắn gọn (tối đa 3 câu). Nếu có chỉ số đáng báo động hãy đưa ra lời khuyên khẩn cấp.
      Giọng điệu: Thân thiện, chuyên nghiệp, quan tâm.
      ''';
      final response = await model.generateContent([Content.text(prompt)]);
      final aiAdvice = response.text ?? 'Hệ thống AI đang bận, vui lòng thử lại sau.';
      if (mounted) { Navigator.pop(context); _showAIAdviceDialog(aiAdvice); }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showAIAdviceDialog(String advice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.smart_toy, color: Colors.teal, size: 28), SizedBox(width: 8), Text('Bác sĩ AI tư vấn', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 18))]),
        content: Text(advice, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), child: const Text('Đã hiểu và ghi nhận', style: TextStyle(fontWeight: FontWeight.bold)))],
      ),
    );
  }

  Future<void> _addMedication(String name, String dosage, TimeOfDay time) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
      final url = Uri.parse('http://10.0.2.2:5188/api/MedicationSchedules');
      final response = await http.post(url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode({"userId": userId, "medicineName": name, "dosage": dosage, "timeToTake": timeString, "isTaken": false}),
      );
      if (response.statusCode == 201) {
        _fetchMedications();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm lịch uống thuốc!'), backgroundColor: Colors.green));
      }
    } catch (e) { print('Lỗi mạng khi thêm thuốc: $e'); }
  }

  void _showAddBottomSheet() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thêm lịch uống thuốc', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: nameController, decoration: InputDecoration(labelText: 'Tên thuốc', prefixIcon: const Icon(Icons.medication), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: dosageController, decoration: InputDecoration(labelText: 'Liều lượng (VD: 2 viên, 1 gói...)', prefixIcon: const Icon(Icons.monitor_weight_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade400)),
                  leading: const Icon(Icons.access_time, color: Colors.teal),
                  title: const Text('Giờ uống thuốc'),
                  trailing: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: selectedTime);
                    if (t != null) setModalState(() => selectedTime = t);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty && dosageController.text.isNotEmpty) {
                        _addMedication(nameController.text, dosageController.text, selectedTime);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Lưu lịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _updateMedicationStatus(Map<String, dynamic> med, bool isTaken) async {
    try {
      final url = Uri.parse('http://10.0.2.2:5188/api/MedicationSchedules/${med['id']}');
      final updatedMed = Map<String, dynamic>.from(med);
      updatedMed['isTaken'] = isTaken;
      final response = await http.put(url, headers: {'Content-Type': 'application/json'}, body: json.encode(updatedMed));
      if (response.statusCode != 204) _fetchMedications();
    } catch (e) { _fetchMedications(); }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardScreen(),         // 0 - Lịch thuốc
          _buildAIAssistantScreen(),       // 1 - Trợ lý AI
          const BmiScreen(),               // 2 - BMI
          const WaterNotificationScreen(), // 3 - Nhắc nước
          _buildProfileScreen(),           // 4 - Hồ sơ
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Lịch thuốc'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'Trợ lý AI'),
            BottomNavigationBarItem(icon: Icon(Icons.monitor_weight_outlined), activeIcon: Icon(Icons.monitor_weight), label: 'BMI'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Nhắc nước'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Hồ sơ'),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddBottomSheet,
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add),
              label: const Text('Thêm lịch', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // --- TAB 1: DASHBOARD ---
  Widget _buildDashboardScreen() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchData,
        color: Colors.teal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Chào ngày mới, $_userName', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    const Text('Tổng quan sức khỏe hôm nay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ]),
                  CircleAvatar(backgroundColor: Colors.teal.shade100, radius: 24, child: const Icon(Icons.person, color: Colors.teal, size: 28)),
                ],
              ),
              const SizedBox(height: 24),
              _buildWaterTrackerCard(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chỉ số sinh hiệu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  InkWell(
                    onTap: _showUpdateVitalsDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(children: [Icon(Icons.edit_note, color: Colors.teal, size: 20), SizedBox(width: 4), Text('Cập nhật', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 14))]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildVitalsGrid(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lịch uống thuốc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  TextButton(onPressed: () {}, child: const Text('Xem tất cả', style: TextStyle(color: Colors.teal))),
                ],
              ),
              const SizedBox(height: 8),
              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.teal)))
                  : _medications.isEmpty
                      ? _buildEmptyMedication()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
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
                                  decoration: BoxDecoration(color: med['isTaken'] ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.medication, color: med['isTaken'] ? Colors.green : Colors.orange),
                                ),
                                title: Text(med['medicineName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(children: [
                                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(timeString, style: TextStyle(color: Colors.grey.shade600)),
                                    const SizedBox(width: 16),
                                    Icon(Icons.monitor_weight_outlined, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(med['dosage'], style: TextStyle(color: Colors.grey.shade600)),
                                  ]),
                                ),
                                trailing: Checkbox(
                                  value: med['isTaken'],
                                  activeColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      setState(() => med['isTaken'] = value);
                                      _updateMedicationStatus(med, value);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterTrackerCard() {
    final currentWater = _healthMetric?['waterIntakeMl'] ?? 0;
    final targetWater = _healthMetric?['targetWaterMl'] ?? 2000;
    final double progress = targetWater > 0 ? (currentWater / targetWater) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade100, shape: BoxShape.circle), child: const Icon(Icons.water_drop, color: Colors.blue, size: 32)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mục tiêu uống nước', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress > 1.0 ? 1.0 : progress, backgroundColor: Colors.blue.shade200, valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue), minHeight: 8))),
            const SizedBox(width: 12),
            Text('$currentWater / ${targetWater}ml', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ]),
        ])),
        IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue, size: 36), onPressed: () => _addWater(200)),
      ]),
    );
  }

  Widget _buildVitalsGrid() {
    final hr = _healthMetric?['heartRate']?.toString() ?? '0';
    final bp = _healthMetric?['bloodPressure']?.toString() ?? '0/0';
    final weight = _healthMetric?['weight']?.toString() ?? '0';
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _buildVitalCard('Nhịp tim', hr, 'bpm', Icons.favorite, Colors.red),
      _buildVitalCard('Huyết áp', bp, 'mmHg', Icons.bloodtype, Colors.purple),
      _buildVitalCard('Cân nặng', weight, 'kg', Icons.monitor_weight, Colors.orange),
    ]);
  }

  Widget _buildVitalCard(String title, String value, String unit, IconData icon, MaterialColor color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color.shade400, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyMedication() {
    return Center(child: Column(children: [
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle), child: Icon(Icons.medication_liquid, size: 50, color: Colors.teal.shade300)),
      const SizedBox(height: 16),
      Text('Chưa có lịch uống thuốc nào.\nHãy thêm đơn thuốc mới!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, height: 1.5)),
    ]));
  }

  // --- TAB 2: TRỢ LÝ AI ---
  Widget _buildAIAssistantScreen() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.smart_toy_outlined, size: 80, color: Colors.teal.shade200),
      const SizedBox(height: 16),
      const Text('Trợ lý ảo tư vấn sức khỏe AI\n(Sẽ tích hợp Gemini API vào đây)', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
    ]));
  }

  // --- TAB 5: HỒ SƠ ---
  Widget _buildProfileScreen() {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hồ sơ cá nhân', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 20),

            // CARD AVATAR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade600], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(email, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85))),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // THỐNG KÊ SỨC KHỎE
            const Text('Sức khỏe hôm nay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard('Nhịp tim', '${_healthMetric?['heartRate'] ?? 0}', 'bpm', Icons.favorite, Colors.red),
                const SizedBox(width: 12),
                _buildStatCard('Uống nước', '${_healthMetric?['waterIntakeMl'] ?? 0}', 'ml', Icons.water_drop, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard('Cân nặng', '${_healthMetric?['weight'] ?? 0}', 'kg', Icons.monitor_weight, Colors.orange),
              ],
            ),

            const SizedBox(height: 24),

            // MENU
            const Text('Cài đặt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Column(
                children: [
                  _buildMenuTile(Icons.notifications_outlined, Colors.blue, 'Nhắc nhở uống nước', 'Cài đặt lịch nhắc', () => setState(() => _selectedIndex = 3)),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _buildMenuTile(Icons.monitor_weight_outlined, Colors.green, 'Chỉ số BMI', 'Xem và tính BMI', () => setState(() => _selectedIndex = 2)),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _buildMenuTile(Icons.info_outline, Colors.teal, 'Về ứng dụng', 'SaHaBa Health v1.0.0', () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Về ứng dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('SaHaBa Health v1.0.0\n\nỨng dụng chăm sóc sức khỏe cá nhân.\nPhát triển bởi nhóm SaHaBa.', style: TextStyle(height: 1.6)),
                        actions: [ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), child: const Text('Đóng'))],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // NÚT ĐĂNG XUẤT
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text('Bạn có chắc muốn đăng xuất không?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text('Đăng xuất'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await supabase.auth.signOut();
                    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, IconData icon, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color.shade400, size: 20),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
    );
  }
}