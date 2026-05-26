import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VitalsDetailScreen extends StatefulWidget {
  const VitalsDetailScreen({super.key});

  @override
  State<VitalsDetailScreen> createState() => _VitalsDetailScreenState();
}

class _VitalsDetailScreenState extends State<VitalsDetailScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _vitalsData = [];
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
      // Tải 2 bảng ĐỘC LẬP để tránh lỗi Relationship của Supabase
      final vitalsResponse = await supabase.from('DailyHealthMetrics').select('*');
      final usersResponse = await supabase.from('user_profiles').select('id, full_name');

      // Tạo Map để tra cứu tên người dùng cho nhanh
      final Map<String, String> tempMap = {};
      for (var u in usersResponse as List) {
        if (u['id'] != null) {
          tempMap[u['id'].toString()] = (u['full_name'] ?? 'Chưa đặt tên').toString();
        }
      }

      setState(() {
        _vitalsData = vitalsResponse as List;
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
      appBar: AppBar(title: const Text("Chi tiết Sinh hiệu"), backgroundColor: Colors.pink.shade600),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pink))
          : _vitalsData.isEmpty
              ? const Center(child: Text("Không có dữ liệu"))
              : ListView.builder(
                  itemCount: _vitalsData.length,
                  itemBuilder: (context, index) {
                    final item = _vitalsData[index];
                    final heartRate = item['heart_rate'] ?? item['HeartRate'] ?? 0;
                    final weight = item['weight'] ?? item['Weight'] ?? 0;
                    
                    // Lấy user_id và tra cứu tên từ Map
                    final userId = (item['user_id'] ?? item['UserId'] ?? '').toString();
                    final userName = _userMap[userId] ?? (userId.length > 8 ? "Mã: ${userId.substring(0,8)}" : "Ẩn danh");

                    return ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.red, size: 30),
                      title: Text("Người dùng: $userName", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Nhịp tim: $heartRate bpm | Cân nặng: $weight kg"),
                    );
                  },
                ),
    );
  }
}