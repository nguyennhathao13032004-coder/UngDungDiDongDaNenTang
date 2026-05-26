import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahaba_health_app/services/notification_service.dart';

class WaterNotificationScreen extends StatefulWidget {
  const WaterNotificationScreen({super.key});

  @override
  State<WaterNotificationScreen> createState() => _WaterNotificationScreenState();
}

class _WaterNotificationScreenState extends State<WaterNotificationScreen> {
  bool _isEnabled = false;
  int _intervalHours = 2;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSavedSettings(); // Tự động lấy dữ liệu thật từ máy lên khi mở màn hình
    NotificationService.requestPermission();
  }

  // Hàm đọc dữ liệu thật từ bộ nhớ SharedPreferences
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnabled = prefs.getBool('water_enabled') ?? false;
      _intervalHours = prefs.getInt('water_interval') ?? 2;
      
      final startHour = prefs.getInt('water_start_hour') ?? 7;
      final startMin = prefs.getInt('water_start_min') ?? 0;
      _startTime = TimeOfDay(hour: startHour, minute: startMin);

      final endHour = prefs.getInt('water_end_hour') ?? 22;
      final endMin = prefs.getInt('water_end_min') ?? 0;
      _endTime = TimeOfDay(hour: endHour, minute: endMin);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('water_enabled', _isEnabled);
    await prefs.setInt('water_interval', _intervalHours);
    await prefs.setInt('water_start_hour', _startTime.hour);
    await prefs.setInt('water_start_min', _startTime.minute);
    await prefs.setInt('water_end_hour', _endTime.hour);
    await prefs.setInt('water_end_min', _endTime.minute);

    // Trước khi lên lịch mới, hủy toàn bộ lịch nhắc cũ để tránh trùng lặp
    await NotificationService.cancelAllNotifications();

    if (_isEnabled) {
      // SỬA LẠI NỘI DUNG THÔNG BÁO BẮN RA NGAY LẬP TỨC KHI BẤM LƯU:
      await NotificationService.showInstantNotification(
        '💧 SaHaBa Health: Đã bật nhắc nhở!',
        'Trợ lý AI đã lên lịch nhắc bạn uống nước mỗi $_intervalHours giờ. Cùng giữ thói quen tốt nhé! 🎉',
      );

      // Lấy danh sách các mốc thời gian dạng ["07:00", "09:00", ...]
      List<String> scheduleTimes = _getScheduleTimes();

      // Duyệt qua từng mốc thời gian để đặt báo thức chạy ngầm
      for (int i = 0; i < scheduleTimes.length; i++) {
        List<String> parts = scheduleTimes[i].split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);

        // SỬA LẠI NỘI DUNG THÔNG BÁO CHẠY NGẦM ĐẾN ĐÚNG GIỜ SẼ HIỆN:
        await NotificationService.scheduleDailyNotification(
          id: i + 1,
          title: '💧 Đã đến giờ uống nước rồi, Hào ơi!',
          body: 'Nạp ngay 1 ly nước 250ml để cơ thể luôn tràn đầy năng lượng và tỉnh táo làm việc nhé! 🌟',
          hour: hour,
          minute: minute,
        );
      }
    }
  }

  List<String> _getScheduleTimes() {
    int startMinutes = _startTime.hour * 60 + _startTime.minute;
    int endMinutes = _endTime.hour * 60 + _endTime.minute;
    int intervalMinutes = _intervalHours * 60;
    List<String> times = [];
    for (int m = startMinutes; m <= endMinutes; m += intervalMinutes) {
      final h = m ~/ 60;
      final min = m % 60;
      times.add('${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
    }
    return times;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Nhắc nhở uống nước',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD BẬT/TẮT
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isEnabled ? Colors.blue.shade50 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.water_drop,
                        color: _isEnabled ? Colors.blue : Colors.grey, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nhắc nhở uống nước',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _isEnabled ? 'Đang bật' : 'Đang tắt',
                          style: TextStyle(
                              fontSize: 13,
                              color: _isEnabled ? Colors.blue : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEnabled,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      setState(() => _isEnabled = value);
                      _saveSettings(); // Tự động lưu và cập nhật hệ thống thông báo
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value
                              ? '✅ Đã lưu lịch nhắc nhở uống nước thật!'
                              : '🔕 Đã tắt nhắc nhở thành công!'),
                          backgroundColor: value ? Colors.blue : Colors.grey,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // CARD CÀI ĐẶT
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cài đặt nhắc nhở',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // TẦN SUẤT
                  const Text('Nhắc mỗi:', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 2, 3, 4].map((hour) {
                      final isSelected = _intervalHours == hour;
                      return GestureDetector(
                        onTap: () => setState(() => _intervalHours = hour),
                        child: Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text('$hour giờ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontSize: 14)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // GIỜ BẮT ĐẦU
                  _buildTimePicker(
                    label: 'Bắt đầu từ',
                    icon: Icons.wb_sunny_outlined,
                    iconColor: Colors.orange,
                    time: _startTime,
                    onTap: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: _startTime);
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                  const SizedBox(height: 12),

                  // GIỜ KẾT THÚC
                  _buildTimePicker(
                    label: 'Kết thúc lúc',
                    icon: Icons.nights_stay_outlined,
                    iconColor: Colors.indigo,
                    time: _endTime,
                    onTap: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: _endTime);
                      if (picked != null) setState(() => _endTime = picked);
                    },
                  ),

                  const SizedBox(height: 24),

                  // NÚT LƯU CÀI ĐẶT DỮ LIỆU THẬT
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isEnabled
                          ? () {
                              _saveSettings(); // Thực thi lưu dữ liệu thật xuống máy
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('✅ Đã lưu cấu hình mới thành công!'),
                                    backgroundColor: Colors.blue),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu cài đặt',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // CARD LỊCH NHẮC THẬT
            if (_isEnabled) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Lịch nhắc nhở của bạn',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 15)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'App sẽ nhắc bạn uống nước mỗi $_intervalHours giờ\ntừ ${_startTime.format(context)} đến ${_endTime.format(context)}',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _getScheduleTimes().map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(t,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // HƯỚNG DẪN LỢI ÍCH
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.tips_and_updates, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Lợi ích uống đủ nước',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 15)),
                  ]),
                  SizedBox(height: 12),
                  Text('💧 Tăng cường trao đổi chất\n'
                      '💧 Cải thiện tập trung và trí nhớ\n'
                      '💧 Giúp da khỏe đẹp hơn\n'
                      '💧 Hỗ trợ tiêu hóa tốt hơn\n'
                      '💧 Mục tiêu: 2000ml mỗi ngày',
                      style: TextStyle(fontSize: 14, height: 1.8, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required IconData icon,
    required Color iconColor,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}