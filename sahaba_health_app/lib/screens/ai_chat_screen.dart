import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String? _userId;
  String _userContext = ''; // Context dữ liệu người dùng

  static const String _aiBaseUrl = 'http://localhost:8000';
  static const String _apiBaseUrl =
      'http://localhost:5188'; // ASP.NET Core - đổi IP nếu test Android

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _loadUserContext(); // Tải dữ liệu user trước
    _loadHistory();
  }

  // Lấy dữ liệu sinh hiệu + thuốc để truyền vào AI
  Future<void> _loadUserContext() async {
    if (_userId == null) return;
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse('$_apiBaseUrl/api/DailyHealthMetrics/User/$_userId/Today'),
        ),
        http.get(
          Uri.parse('$_apiBaseUrl/api/MedicationSchedules/User/$_userId'),
        ),
      ]);

      final healthRes = results[0];
      final medRes = results[1];

      String contextParts = '';

      // Sinh hiệu
      if (healthRes.statusCode == 200) {
        final health = jsonDecode(healthRes.body);
        final hr = health['heartRate'] ?? 0;
        final bp = health['bloodPressure'] ?? '0/0';
        final weight = health['weight'] ?? 0;
        final water = health['waterIntakeMl'] ?? 0;
        contextParts +=
            'Sinh hiệu hôm nay: nhịp tim $hr bpm, huyết áp $bp mmHg, cân nặng $weight kg, đã uống $water ml nước. ';
      }

      // Danh sách thuốc
      if (medRes.statusCode == 200) {
        final meds = jsonDecode(medRes.body) as List;
        if (meds.isNotEmpty) {
          final medNames = meds
              .map(
                (m) =>
                    '${m['medicineName']} (${m['dosage']}, ${m['timeToTake'].toString().substring(0, 5)})',
              )
              .join(', ');
          contextParts += 'Đang uống thuốc: $medNames.';
        }
      }

      setState(() => _userContext = contextParts);
    } catch (e) {
      debugPrint('Không lấy được context user: $e');
      // Không có context vẫn chat bình thường được
    }
  }

  Future<void> _loadHistory() async {
    if (_userId == null) return;
    try {
      final response = await http.get(
        Uri.parse('$_aiBaseUrl/api/chat/history/$_userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List messages = data['messages'] ?? [];
        setState(() {
          _messages.clear();
          for (var msg in messages) {
            _messages.add({
              'role': msg['role'] == 'model' ? 'assistant' : 'user',
              'content': msg['content'],
            });
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Lỗi load history: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _userId == null) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_aiBaseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'user_id': _userId,
          'user_context': _userContext, // Truyền context vào
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add({'role': 'assistant', 'content': data['answer']});
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Xin lỗi, có lỗi xảy ra. Vui lòng thử lại!',
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Không thể kết nối server. Kiểm tra lại kết nối mạng!',
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa lịch sử'),
        content: const Text('Bạn có chắc muốn xóa toàn bộ lịch sử chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await http.delete(Uri.parse('$_aiBaseUrl/api/chat/history/$_userId'));
      setState(() => _messages.clear());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa lịch sử chat')));
      }
    } catch (e) {
      debugPrint('Lỗi xóa history: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SaHa AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Trợ lý sức khỏe',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Xóa lịch sử',
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_messages.isEmpty) _buildEmptyState(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTypingIndicator();
                final msg = _messages[index];
                return _buildMessageBubble(msg['role']!, msg['content']!);
              },
            ),
          ),
          _buildInputBox(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 45,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Xin chào! Mình là SaHa ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trợ lý sức khỏe cá nhân của bạn.\nHỏi mình bất cứ điều gì về sức khỏe nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            // Hiển thị context đã load được
            if (_userContext.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Đã tải dữ liệu sức khỏe của bạn',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gợi ý câu hỏi:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            ...[
              ' Tôi nên uống thuốc lúc nào tốt nhất?',
              ' Nhịp tim bình thường là bao nhiêu?',
              ' Mỗi ngày nên uống bao nhiêu nước?',
              ' Phân tích chỉ số sức khỏe của tôi hôm nay',
            ].map((q) => _buildSuggestionChip(q)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String question) {
    return GestureDetector(
      onTap: () {
        _controller.text = question.substring(2).trim();
        _sendMessage();
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(question, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildMessageBubble(String role, String content) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2E7D32) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(children: [_dot(0), _dot(150), _dot(300)]),
        ),
      ],
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, value, __) => Opacity(
        opacity: value,
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(
            color: Color(0xFF2E7D32),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Hỏi SaHa về sức khỏe...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.grey : const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Icon(
                  _isLoading ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
