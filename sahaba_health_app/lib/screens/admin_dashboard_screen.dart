import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart'; // Đổi đường dẫn nếu file login của bạn khác tên
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'VitalsDetailScreen.dart';
import 'UserDetailScreen.dart';
import 'SchedulesDetailScreen.dart';
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  final supabase = Supabase.instance.client;

  // Xử lý đăng xuất
  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // Danh sách các màn hình tương ứng với từng Tab
  final List<Widget> _pages = [
    const AdminOverviewTab(),
    const AdminUsersTab(),
    const AdminAIChatTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị hệ thống SaHa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              // Bật dialog xác nhận trước khi đăng xuất
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Xác nhận'),
                  content: const Text('Bạn muốn đăng xuất khỏi tài khoản Admin?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _signOut();
                      }, 
                      child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Tổng quan'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Người dùng'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'Giám sát AI'),
        ],
      ),
    );
  }
}

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalVitals = 0;
  int _totalSchedules = 0;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  // Hàm gọi API lấy số liệu từ Backend C#
  Future<void> _fetchStatistics() async {
    setState(() => _isLoading = true);
    try {
      // ĐƯỜNG LINK ĐÃ ĐƯỢC CẬP NHẬT CHUẨN XÁC:
      final response = await http.get(Uri.parse('http://10.0.2.2:5188/api/Admin/Statistics'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Bắt cả trường hợp chữ hoa lẫn chữ thường để không trượt phát nào
          _totalUsers = data['totalUsers'] ?? data['TotalUsers'] ?? 0;
          _totalVitals = data['totalVitalsRecords'] ?? data['TotalVitalsRecords'] ?? 0;
          _totalSchedules = data['totalSchedules'] ?? data['TotalSchedules'] ?? 0;
          _isLoading = false;
        });
      } else {
        // Nếu vẫn lỗi, nó sẽ in ra mã lỗi cụ thể (VD: 404, 400) chứ không báo chung chung nữa
        print("❌ LỖI TỪ C#: Trả về mã ${response.statusCode}");
        throw Exception('Lỗi Server: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Lỗi kết nối: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.teal));
    }

    return RefreshIndicator(
      onRefresh: _fetchStatistics, // Vuốt xuống để cập nhật lại số liệu mới
      color: Colors.teal,
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Text(
            'Hệ thống SaHaBa ổn định',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.green),
          ),
          const SizedBox(height: 5),
          const Text(
            'Số liệu tổng quan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // THẺ 1: NGƯỜI DÙNG
          // Trong AdminOverviewTab, hãy sửa phần gọi _buildStatCard cho thẻ Người dùng:
           _buildStatCard(
            title: 'Tổng số người dùng',
            value: '$_totalUsers',
            subtitle: 'Tài khoản hoạt động trên hệ thống',
            icon: Icons.people_alt,
            color: Colors.blue.shade600,
            onTap: () {
              Navigator.push(
              context,
                  MaterialPageRoute(builder: (context) => const UserDetailScreen()),
    );
  },
),
          const SizedBox(height: 16),

          // THẺ 2: SINH HIỆU
          _buildStatCard(
            title: 'Bản ghi sinh hiệu',
            value: '$_totalVitals',
            subtitle: 'Lượt đo huyết áp, nhịp tim, cân nặng',
            icon: Icons.favorite_border,
            color: Colors.pink.shade600,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VitalsDetailScreen())),
          ),
          const SizedBox(height: 16),

          // THẺ 3: LỊCH UỐNG THUỐC
          _buildStatCard(
            title: 'Lịch nhắc thuốc',
            value: '$_totalSchedules',
            subtitle: 'Đơn thuốc được AI và người dùng tạo',
            icon: Icons.medication_liquid,
            color: Colors.teal.shade600,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SchedulesDetailScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap, // Thêm dòng này
  }) {
    return Card( // Dùng Card để có đổ bóng đẹp hơn Container
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      child: InkWell( // Bọc InkWell để tạo hiệu ứng khi bấm
        borderRadius: BorderRadius.circular(20),
        onTap: onTap, // Gán sự kiện bấm vào đây
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 80, color: Colors.teal.shade200),
          const SizedBox(height: 16),
          const Text('Khu vực Thống kê dữ liệu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Sẽ kết nối API C# để hiển thị biểu đồ', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

// ==========================================
// TAB 2: QUẢN LÝ NGƯỜI DÙNG
// ==========================================
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final supabase = Supabase.instance.client;
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // TẢI DANH SÁCH
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase.from('user_profiles').select('*').order('full_name', ascending: true);
      setState(() {
        _users = response;
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi: $e");
      setState(() => _isLoading = false);
    }
  }

  // HỘP THOẠI XÁC NHẬN XÓA
  Future<void> _confirmDelete(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: const Text("Bạn có chắc chắn muốn xóa tài khoản này? Dữ liệu sẽ không thể khôi phục."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Xóa", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('user_profiles').delete().eq('id', userId);
        _fetchUsers(); // Tải lại danh sách
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa thành công!")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  // HỘP THOẠI THÊM / SỬA NGƯỜI DÙNG
  Future<void> _showUserDialog({Map<String, dynamic>? user}) async {
    final bool isEdit = user != null; // Có data truyền vào nghĩa là Đang Sửa
    final nameController = TextEditingController(text: isEdit ? user['full_name'] : '');
    String selectedRole = isEdit ? (user['role'] ?? 'user') : 'user';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? "Chỉnh sửa tài khoản" : "Thêm người dùng mới"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Họ và tên", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: "Phân quyền", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text("Người dùng (User)")),
                      DropdownMenuItem(value: 'admin', child: Text("Quản trị viên (Admin)")),
                    ],
                    onChanged: (value) {
                      if (value != null) setStateDialog(() => selectedRole = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    
                    try {
                      if (isEdit) {
                        // SỬA
                        await supabase.from('user_profiles').update({
                          'full_name': nameController.text.trim(),
                          'role': selectedRole,
                        }).eq('id', user['id']);
                      } else {
                        // THÊM
                        await supabase.from('user_profiles').insert({
                          'full_name': nameController.text.trim(),
                          'role': selectedRole,
                        });
                      }
                      
                      Navigator.pop(context);
                      _fetchUsers();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "Cập nhật thành công!" : "Thêm thành công!")));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                    }
                  },
                  child: const Text("Lưu", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Bọc Scaffold ở đây để có thể dùng nút nổi (FloatingActionButton)
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : RefreshIndicator(
            onRefresh: _fetchUsers,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final bool isAdmin = user['role'] == 'admin';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAdmin ? Colors.teal : Colors.blueGrey.shade100,
                      child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.white),
                    ),
                    title: Text(user['full_name'] ?? 'Chưa đặt tên', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Quyền: ${user['role']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min, // Giữ cho các nút sát nhau
                      children: [
                        // NÚT SỬA
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showUserDialog(user: user),
                        ),
                        // NÚT XÓA
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(user['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      // NÚT THÊM NỔI
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal.shade700,
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
// ==========================================
// TAB 3: GIÁM SÁT CHAT AI (CẬP NHẬT CHUẨN DATABASE)
// ==========================================
class AdminAIChatTab extends StatefulWidget {
  const AdminAIChatTab({super.key});

  @override
  State<AdminAIChatTab> createState() => _AdminAIChatTabState();
}

class _AdminAIChatTabState extends State<AdminAIChatTab> {
  final supabase = Supabase.instance.client;
  List<dynamic> _chatMessages = [];
  Map<String, String> _sessionToUserMap = {}; // Lưu ID Session -> Tên người dùng
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatLogs();
  }

  Future<void> _loadChatLogs() async {
    setState(() => _isLoading = true);
    try {
      // 1. Lấy dữ liệu tin nhắn từ đúng bảng 'ai_chat_messages' (Mới nhất lên đầu)
      final messagesResponse = await supabase
          .from('ai_chat_messages')
          .select('*')
          .order('created_at', ascending: false);

      // 2. Lấy danh sách session và user để tự kết nối tên (Tránh lỗi khóa ngoại)
      final sessionsResponse = await supabase.from('ai_chat_sessions').select('*');
      final usersResponse = await supabase.from('user_profiles').select('id, full_name');

      // 3. Map (Từ UserID ra Tên)
      final Map<String, String> userMap = {};
      for (var u in usersResponse as List) {
        if (u['id'] != null) userMap[u['id'].toString()] = (u['full_name'] ?? 'Chưa đặt tên').toString();
      }

      // 4. Map (Từ SessionID ra Tên)
      final Map<String, String> sessionMap = {};
      for (var s in sessionsResponse as List) {
        final sId = s['id'].toString();
        final uId = (s['user_id'] ?? '').toString();
        sessionMap[sId] = userMap[uId] ?? 'Ẩn danh';
      }

      setState(() {
        _chatMessages = messagesResponse as List;
        _sessionToUserMap = sessionMap;
        _isLoading = false;
      });
    } catch (e) {
      print("Lỗi tải lịch sử chat AI: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Giám sát AI", style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.purple.shade600,
        automaticallyImplyLeading: false, // Ẩn nút back nếu có
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : _chatMessages.isEmpty
              ? const Center(child: Text("Chưa có lượt chat nào với trợ lý ảo"))
              : RefreshIndicator(
                  onRefresh: _loadChatLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _chatMessages[index];

                      // Lấy đúng tên cột theo Database của bạn
                      final role = msg['role'] ?? '';
                      final content = msg['content'] ?? 'Không có nội dung';
                      final sessionId = (msg['session_id'] ?? '').toString();
                      
                      // Dò tìm tên người dùng dựa vào session_id
                      final userName = _sessionToUserMap[sessionId] ?? 'Phiên: $sessionId';
                      
                      // Kiểm tra xem ai là người nhắn
                      final isUser = role == 'user';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          // Tô viền thẻ để dễ phân biệt: Xanh cho User, Tím cho AI
                          side: BorderSide(color: isUser ? Colors.blue.shade100 : Colors.purple.shade100, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isUser ? Icons.account_circle : Icons.smart_toy,
                                    color: isUser ? Colors.blue : Colors.purple,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isUser ? "Người dùng: $userName" : "Trợ lý ảo SaHa",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isUser ? Colors.blue.shade800 : Colors.purple.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}