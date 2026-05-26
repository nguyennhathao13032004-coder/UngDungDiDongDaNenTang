import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Đã fix lỗi dòng 19: Thêm settings:
    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  static Future<void> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  static Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'water_channel_id',
      'Nhắc nhở uống nước',
      channelDescription: 'Kênh thông báo nhắc nhở uống nước định kỳ',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    
    // Đã fix lỗi dòng 33: Thêm id:, title:, body:, notificationDetails:
    await _notificationsPlugin.show(
      id: 0, 
      title: title, 
      body: body, 
      notificationDetails: notificationDetails
    );
  }

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'water_scheduled_channel_id',
      'Lịch nhắc uống nước',
      channelDescription: 'Kênh lên lịch nhắc nhở uống nước tự động',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, 
    );
  }

  static Future<void> scheduleMedicationNotification({
    required int id,
    required String pillName,
    required String dosage,
    required int hour,
    required int minute,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_channel_id',
      'Nhắc nhở uống thuốc',
      channelDescription: 'Kênh báo thức uống thuốc đúng giờ',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF4CAF50),
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: '💊 Đến giờ uống thuốc rồi!',
      body: 'Bạn nhớ uống $dosage $pillName đúng giờ để mau khỏe nhé.',
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelNotification(int id) async {
    // Đã fix: Thêm id:
    await _notificationsPlugin.cancel(id: id);
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    // 1. ÉP BUỘC LẤY MÚI GIỜ VIỆT NAM
    final vnLocation = tz.getLocation('Asia/Ho_Chi_Minh');
    final tz.TZDateTime now = tz.TZDateTime.now(vnLocation);
    
    // 2. Tạo lịch hẹn (Reset giây và mili-giây về 0 để so sánh chuẩn xác)
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      vnLocation, now.year, now.month, now.day, hour, minute, 0, 0
    );
    
    // 3. Nếu giờ hẹn đã qua, đẩy sang ngày mai
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}