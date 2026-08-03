//signup_screen.dart
import 'package:flutter/material.dart';
import 'signin_screen.dart';
import 'name_screen.dart';
import 'package:sdsd/server/services/auth_service.dart'; // ← 변경: 실제 위치(lib/server/services)에 맞춘 패키지 경로

class SignupScreen extends StatefulWidget {
  // ← 변경: StatelessWidget → StatefulWidget
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ==========================================
  // 입력값을 관리하는 컨트롤러들
  // ==========================================
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Firebase 서비스 인스턴스
  final AuthService _authService = AuthService();

  // 로딩 상태 (이메일 회원가입 중일 때 버튼 비활성화)
  bool _isLoading = false;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  @override
  void dispose() {
    // 화면을 나갈 때 컨트롤러 해제 (메모리 누수 방지)
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // 회원가입 버튼을 눌렀을 때 실행되는 함수
  // ==========================================
  Future<void> _handleSignUp() async {
    // 입력값 가져오기
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 입력값 검증 (공백 확인)
    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('이메일과 비밀번호를 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true; // 로딩 시작
    });

    try {
      // 임시 displayName 설정 (NameScreen에서 받을 예정)
      await _authService.signUp(
        email: email,
        password: password,
        displayName: '사용자', // 기본값 (NameScreen에서 변경 예정)
      );

      // 회원가입 성공 → NameScreen으로 이동
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => NameScreen()));
      }
    } catch (e) {
      // 회원가입 실패 → 오류 메시지 표시
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
  // SnackBar 표시 함수
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
                // 뒤로가기 버튼
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_ios, size: 24),
                ),
                const SizedBox(height: 32),
                // 제목
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
                  'Start with email.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                // 이메일 입력창
                TextField(
                  controller: _emailController, // ← 변경: 컨트롤러 연결
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading, // 로딩 중이면 비활성화
                  decoration: InputDecoration(
                    hintText: 'email',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.black54,
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                    disabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 비밀번호 입력창
                TextField(
                  controller: _passwordController, // ← 변경: 컨트롤러 연결
                  obscureText: true,
                  enabled: !_isLoading, // 로딩 중이면 비활성화
                  decoration: InputDecoration(
                    hintText: 'password',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.black54,
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                    disabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black12),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Sign up 버튼
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
                      onPressed: _isLoading
                          ? null
                          : _handleSignUp, // ← 변경: 로그인 로직 연결
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      child: _isLoading
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
                              'Sign up',
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
                const SizedBox(height: 16),
                // Sign in 링크
                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SigninScreen(),
                              ),
                            );
                          },
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
