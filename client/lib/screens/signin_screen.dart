//signin_screen.dart
import 'package:flutter/material.dart';
import 'package:sdsd/server/services/auth_service.dart'; // ← 변경: 실제 위치(lib/server/services)에 맞춘 패키지 경로
import 'name_screen.dart'; // ← 추가: 신규 유저 온보딩 화면

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

  // 로딩 상태 (구글 로그인) - 이메일 로딩과 분리 관리
  bool _isGoogleLoading = false;

  // 둘 중 하나라도 로딩 중이면 true (버튼/입력창 비활성화용)
  bool get _isAnyLoading => _isLoading || _isGoogleLoading;

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
        _showSuccessSnackBar('로그인 성공했습니다!');
        // Navigator.of(context).pushReplacementNamed('/home');
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
  // 구글 로그인 버튼을 눌렀을 때 실행되는 함수
  // ==========================================
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true; // 구글 로딩 시작
    });

    try {
      // Firebase + Google 인증 요청
      // isNewUser: true면 이번에 처음 가입한 사용자, false면 기존 사용자
      final bool isNewUser = await _authService.signInWithGoogle();

      if (!mounted) return; // 비동기 작업 중 화면이 사라졌으면 아무것도 하지 않음

      if (isNewUser) {
        // 신규 사용자 → 온보딩 시작 (이름 입력부터)
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => NameScreen()));
      } else {
        // 기존 사용자 → 바로 홈 화면
        // TODO: 실제 홈 화면이 만들어지면 아래 주석을 해제하고 경로를 맞춰주세요.
        // Navigator.of(context).pushReplacementNamed('/home');
        _showSuccessSnackBar('Google 로그인 성공했습니다!');
      }
    } catch (e) {
      // 실패 → 오류 메시지 표시
      // 예: 사용자가 Google 로그인 창을 닫아버린 경우도 여기로 옴
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false; // 구글 로딩 종료
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
                  onTap: _isAnyLoading
                      ? null
                      : () => Navigator.of(context).pop(),
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
                  'Continue with email.',
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
                  enabled: !_isAnyLoading, // 둘 중 하나라도 로딩 중이면 비활성화
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
                  enabled: !_isAnyLoading, // 둘 중 하나라도 로딩 중이면 비활성화
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
                      onPressed: _isAnyLoading
                          ? null
                          : _handleSignIn, // ← 변경: 로그인 로직 연결
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
                // ----- 구분선: "or" -----
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: Colors.black38, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: Colors.black38, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ----- Google 로그인 버튼 -----
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isAnyLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: _isGoogleLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black54,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.google.com/favicon.ico',
                                height: 20,
                                width: 20,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.g_mobiledata, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
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
