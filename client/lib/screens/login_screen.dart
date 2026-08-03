//login_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'signup_screen.dart';
import 'name_screen.dart';
import 'package:sdsd/server/services/auth_service.dart'; // ← 변경: 실제 위치(lib/server/services)에 맞춘 패키지 경로

class LoginScreen extends StatefulWidget {
  // ← 변경: StatelessWidget → StatefulWidget
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Firebase 서비스 인스턴스
  final AuthService _authService = AuthService();

  // 로딩 상태 (구글 로그인 진행 중인지)
  // 나중에 Apple 로그인도 연결하게 되면 _isAppleLoading을 똑같은 패턴으로 추가하면 됩니다.
  bool _isGoogleLoading = false;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  // ==========================================
  // Google 로그인 버튼을 눌렀을 때 실행되는 함수
  // ==========================================
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true; // 로딩 시작 → 버튼이 스피너로 바뀜
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
        _showSuccessSnackBar('로그인 성공했습니다!');
      }
    } catch (e) {
      // 실패 → 오류 메시지 표시 (예: 사용자가 Google 로그인 창을 닫아버린 경우)
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false; // 로딩 종료
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 네컷 사진
                  const Spacer(),
                  Image.asset(
                    'assets/images/login_photos.png',
                    width: double.infinity,
                    height: 500,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 5),
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
                  Text('Get started.', style: AppTextStyles.medium16),
                  const Spacer(flex: 10),
                  // Apple 버튼 (검정)
                  _SocialButton(
                    iconPath: 'assets/images/icons/ic_apple.png',
                    label: 'Continue with Apple',
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                    isLoading: false, // Apple 로그인은 아직 미구현
                    onPressed: _isGoogleLoading
                        ? null // 구글 로그인 중이면 Apple 버튼도 비활성화
                        : () {
                            // TODO: Apple 로그인
                          },
                  ),
                  const SizedBox(height: 12),
                  // Google 버튼 (흰색)
                  _SocialButton(
                    iconPath: 'assets/images/icons/ic_google.png',
                    label: 'Continue with Google',
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    isLoading: _isGoogleLoading, // ← 변경: 로딩 상태 전달
                    onPressed: _isGoogleLoading
                        ? null
                        : _handleGoogleSignIn, // ← 변경: 실제 로직 연결
                  ),
                  const SizedBox(height: 16),
                  // 이메일로 계속하기 링크
                  Center(
                    child: GestureDetector(
                      onTap: _isGoogleLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'Or continue with email',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- 소셜 로그인 버튼 (Apple/Google 공용) ----------
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.iconPath,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
    this.isLoading = false, // ← 추가: 로딩 여부 (기본값 false, 기존 호출부 안 깨짐)
  });

  final String iconPath;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onPressed; // ← 변경: null 허용 (비활성화를 위해)
  final bool isLoading; // ← 추가

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(iconPath, width: 20, height: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
