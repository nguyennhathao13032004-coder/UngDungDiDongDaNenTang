import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SchedulesDetailScreen extends StatefulWidget {
  const SchedulesDetailScreen({super.key});

  @override
  State<SchedulesDetailScreen> createState() => _SchedulesDetailScreenState();
}

class _SchedulesDetailScreenState extends State<SchedulesDetailScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _schedulesData = [];
  Map<String, String> _userMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Tải 2 bảng ĐỘC LẬP
      final schedulesResponse = await supabase.from('medication_schedules').select('*');
      final usersResponse = await supabase.from('user_profiles').select('id, full_name');

      final Map<String, String> tempMap = {};
      for (var u in usersResponse as List) {
        if (u['id'] != null) {
          tempMap[u['id'].toString()] = (u['full_name'] ?? 'Chưa đặt tên').toString();
        }
      }

      setState(() {
        _schedulesData = schedulesResponse as List;
        _userMap = tempMap;
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lịch nhắc thuốc"), backgroundColor: Colors.teal.shade600),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _schedulesData.isEmpty
              ? const Center(child: Text("Không có lịch nhắc thuốc nào"))
              : ListView.builder(
                  itemCount: _schedulesData.length,
                  itemBuilder: (context, index) {
                    final item = _schedulesData[index];
                    final medicineName = item['medicine_name'] ?? 'Không tên thuốc';
                    final time = item['time_to_take'] ?? 'Chưa đặt giờ';
                    final dosage = item['dosage'] ?? '';
                    
                    // Lấy user_id và tra cứu tên từ Map
                    final userId = (item['user_id'] ?? '').toString();
                    final userName = _userMap[userId] ?? (userId.length > 8 ? "Mã: ${userId.substring(0,8)}" : "Ẩn danh");

                    return ListTile(
                      leading: const Icon(Icons.medication, color: Colors.teal, size: 30),
                      // Hiển thị Tên thuốc kèm theo Tên người dùng
                      title: Text("$medicineName - $userName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text("Giờ uống: $time | Liều lượng: $dosage"),
                    );
                  },
                ),
    );
  }
}