import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'admin_dashboard_screen.dart'; // Import trang Admin

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final supabase = Supabase.instance.client;

  // 1. HÀM ĐĂNG NHẬP (CÓ KÈM KIỂM TRA QUYỀN ADMIN)
  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (res.user != null) {
        try {
          // Soi thẻ quyền lực trong database
          final profileData = await supabase
              .from('user_profiles') 
              .select('role')
              .eq('id', res.user!.id)
              .single();

          final String role = profileData['role'] ?? 'user';

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng nhập thành công!'), backgroundColor: Colors.green),
            );

            // Rẽ nhánh: Admin đi đường VIP, User đi đường thường
            if (role == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          }
        } catch (e) {
          print("Lỗi kiểm tra quyền: $e");
          // Lỗi mạng lúc soi quyền thì cho vào trang khách an toàn
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xảy ra lỗi không xác định'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. HÀM QUÊN MẬT KHẨU
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Email của bạn vào ô bên trên để lấy lại mật khẩu!'), 
          backgroundColor: Colors.orange
        ),
      );
      return;
    }
    
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi link đặt lại mật khẩu! Vui lòng kiểm tra hộp thư Email của bạn.'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 3. HÀM ĐĂNG NHẬP BẰNG GOOGLE
  Future<void> _signInWithGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // Dùng cho việc quay lại app sau khi đăng nhập web xong (Deeplink)
        redirectTo: 'io.supabase.sahaba://login-callback', 
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi kết nối Google. Vui lòng thử lại!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, 
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'assets/images/sahaba_logo.jpg', 
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Chào mừng trở lại!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đăng nhập để tiếp tục hành trình\nchăm sóc sức khỏe cùng SaHaBa',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Nhập địa chỉ email của bạn',
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    hintText: 'Nhập mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                    ),
                  ),
                ),
                
                // NÚT QUÊN MẬT KHẨU
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // NÚT ĐĂNG NHẬP BẰNG TÀI KHOẢN
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                    : ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3, 
                          shadowColor: Colors.teal.withOpacity(0.4),
                        ),
                        child: const Text(
                          'Đăng Nhập',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                
                const SizedBox(height: 24),

                // ĐƯỜNG KẺ "HOẶC"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Hoặc', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 24),

                // NÚT ĐĂNG NHẬP BẰNG GOOGLE ĐÃ FIX LỖI
                OutlinedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: Image.network(
                    'https://cdn-icons-png.flaticon.com/512/300/300221.png', // Link ảnh Google ổn định hơn
                    height: 24,
                    // Lớp giáp: Nếu mạng lỗi không tải được ảnh, hiện icon chữ G mặc định của Flutter
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.g_mobiledata, size: 32, color: Colors.redAccent);
                    },
                  ),
                  label: const Text(
                    'Đăng nhập bằng Google',
                    style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // NÚT ĐĂNG KÝ
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Bạn chưa có tài khoản? ',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(
                          color: Colors.teal,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}