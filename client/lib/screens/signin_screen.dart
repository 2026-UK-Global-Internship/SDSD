//signin_screen.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:sdsd/server/services/auth_service.dart';
import 'name_screen.dart';

class SigninScreen extends StatefulWidget {
  // ← 변경: StatelessWidget → StatefulWidget
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  // ==========================================
  // 입력값을 관리하는 컨트롤러들
  // ==========================================
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Firebase 서비스 인스턴스
  final AuthService _authService = AuthService();

  // 로딩 상태 (이메일 로그인)
  bool _isLoading = false;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  @override
  void dispose() {
    // 화면을 나갈 때 컨트롤러 해제
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // 로그인 버튼을 눌렀을 때 실행되는 함수
  // ==========================================
  Future<void> _handleSignIn() async {
    // 입력값 가져오기
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 입력값 검증
    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('이메일과 비밀번호를 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true; // 로딩 시작
    });

    try {
      // Firebase에 로그인
      await _authService.signIn(email: email, password: password);

      // 로그인 성공 → 홈 화면으로 이동
      // (추후에 실제 홈 화면 경로로 변경 필요)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen(name: 'User')),
        );
      }
    } catch (e) {
      // 로그인 실패 → 오류 메시지 표시
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // 로딩 종료
        });
      }
    }
  }

  // ==========================================
  // SnackBar 표시 함수들
  // ==========================================
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 93),
                GestureDetector(
                  onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_ios, size: 24),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Ready to run\nand clean?',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Continue with email',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 1.0,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 32),
                // 이메일 입력창
                // 이메일 입력창
                TextField(
                  key: const ValueKey('emailField'), // ← Key 추가!
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    hintText: 'email',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.black54,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.black,
                        width: 2.0,
                      ), // width 추가시 더 확실함
                    ),
                    disabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 비밀번호 입력창
                TextField(
                  key: const ValueKey(
                    'passwordField',
                  ), // ← Key 추가! (이것 때문에 해결됩니다)
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    hintText: 'password',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.black54,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2.0),
                    ),
                    disabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black12),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Sign in 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF9C27B0),
                          Color(0xFFE91E63),
                          Color(0xFFFBBF24),
                        ],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      child:
                          _isLoading // ← 이메일 로딩 상태만 (구글 로딩 중엔 그대로 'Sign in' 표시)
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
