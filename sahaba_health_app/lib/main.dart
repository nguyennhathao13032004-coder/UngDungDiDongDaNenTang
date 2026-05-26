import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'package:sahaba_health_app/services/notification_service.dart';

// Import 2 thư viện timezone để xử lý múi giờ
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ==========================================
  // KHỞI TẠO MÚI GIỜ (ÉP CHUẨN GIỜ VIỆT NAM)
  // ==========================================
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

  // Khởi tạo dịch vụ thông báo thật
  await NotificationService.init();
  
  await Supabase.initialize(
    url: 'https://beovxpmddidgespeqkyp.supabase.co',
    anonKey: 'sb_publishable_xkYh3jq5ClXZAq4RGPdw9A_965k0dEH', 
  );

  runApp(const SaHaHealthApp());
}

class SaHaHealthApp extends StatelessWidget {
  const SaHaHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaHa Health App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class InitializationScreen extends StatelessWidget {
  const InitializationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SaHa Health'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Supabase đã kết nối thành công!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Bắt đầu sử dụng'),
            )
          ],
        ),
      ),
    );
  }
}