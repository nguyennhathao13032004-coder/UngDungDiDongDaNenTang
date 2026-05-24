import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'home_screen.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Tạo độ trễ 2.5 giây để hiển thị logo thương hiệu
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    // Kiểm tra xem máy đã có phiên đăng nhập của Supabase chưa
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
        // Đã đăng nhập -> Chuyển thẳng vào Màn hình chính
        Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      } else {
        // Chưa đăng nhập -> Chuyển ra màn hình Login
        Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Bạn có thể đổi màu nền tùy ý
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hiển thị ảnh Logo
            Image.asset(
              'assets/images/sahaba_logo.jpg',
              width: 180, // Điều chỉnh kích thước logo cho phù hợp
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),
            // Vòng tròn load nhẹ nhàng bên dưới logo
            const CircularProgressIndicator(
              color: Colors.teal,
            ),
          ],
        ),
      ),
    );
  }
}