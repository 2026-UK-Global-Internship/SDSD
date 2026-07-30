import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

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
                  onPressed: () {
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
                  onPressed: () {
                    // TODO: Google 로그인
                  },
                ),
                const SizedBox(height: 16),
                // 이메일로 계속하기 링크
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // TODO: 이메일 회원가입 페이지로 이동
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
  });

  final String iconPath;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Row(
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
