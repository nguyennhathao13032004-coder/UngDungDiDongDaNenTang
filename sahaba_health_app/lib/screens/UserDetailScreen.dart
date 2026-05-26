import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final data = await supabase.from('user_profiles').select('*');
    setState(() {
      _users = data;
      _isLoading = false;
    });
  }

  // Hàm xóa người dùng
  Future<void> _deleteUser(String userId) async {
    await supabase.from('user_profiles').delete().eq('id', userId);
    _loadUsers(); // Load lại danh sách sau khi xóa
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa người dùng!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết Người dùng"), backgroundColor: Colors.teal),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user['full_name'] ?? 'Không tên'),
                subtitle: Text('Role: ${user['role']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user['id']),
                ),
              );
            },
          ),
    );
  }
}