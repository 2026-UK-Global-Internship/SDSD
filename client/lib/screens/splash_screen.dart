//splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'package:sdsd/server/services/auth_service.dart';
import 'onboarding_screen.dart';
import 'name_screen.dart';
import 'login_screen.dart';
import '../screens/home_screen.dart'; // ← 추가: 실제 홈 화면

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ==========================================
  // 스플래시 화면 로직: "최소 3초 노출"과 "다음 화면 계산"을
  // 동시에 진행한 뒤, 둘 다 끝나면 이동합니다.
  // ==========================================
  Future<void> _initialize() async {
    // Future.wait: 여러 작업을 동시에 실행하고 전부 끝날 때까지 기다림
    // - 하나: 최소 3초 대기 (브랜드 노출 시간 확보)
    // - 둘: 다음으로 갈 화면 계산 (로그인/온보딩 상태 확인, 시간이 걸릴 수 있음)
    //
    // 예: 상태 확인이 0.5초 만에 끝나도 3초를 채울 때까지 기다리고,
    //     반대로 네트워크가 느려서 4초가 걸리면 4초를 기다립니다.
    //     (스플래시가 너무 빨리 깜빡이거나, 화면이 멈춘 것처럼 보이는 것 방지)
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      _resolveNextScreen(),
    ]);

    if (!mounted) return; // 화면이 이미 사라졌으면 이동하지 않음 (오류 방지)

    final nextScreen = results[1] as Widget;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  // ==========================================
  // 로그인 여부 + 온보딩(프로필 설정) 완료 여부를 확인해서
  // 다음에 보여줄 화면을 결정하는 함수
  // ==========================================
  Future<Widget> _resolveNextScreen() async {
    // 1. 로그인이 안 되어 있으면 → 인트로 캐러셀부터 시작
    if (!_authService.isLoggedIn) {
      return const OnboardingScreen();
    }

    // 2. 로그인은 되어 있음 → 프로필 설정(이름/username/goal)까지 끝냈는지 확인
    try {
      final uid = _authService.currentUserId!;

      // .timeout(): 5초 안에 응답이 없으면 강제로 실패 처리
      // (네트워크 문제로 Firestore 응답이 영영 안 오는 상황을 방지)
      final bool isComplete = await _authService
          .checkOnboardingComplete(uid)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('네트워크 응답 시간 초과'),
          );

      if (isComplete) {
        // 프로필 설정까지 끝난 기존 사용자 → 실제 홈 화면으로 이동
        // login_screen.dart의 기존 유저 처리와 동일한 방식:
        // Firestore에서 이름을 가져와 HomeScreen에 전달합니다.
        final profile = await _authService.getUserProfile(uid);
        final displayName = profile['displayName'] as String? ?? 'User';

        return HomeScreen(name: displayName);
      } else {
        // 로그인은 했지만 이름/username/goal 설정을 안 끝낸 사용자
        // → 캐러셀은 건너뛰고 바로 프로필 설정 화면으로 이어서 진행
        return NameScreen();
      }
    } catch (e) {
      // Firestore 조회 실패 등 예상 못한 오류 → 안전하게 로그인 화면으로 보냄
      // (예: 문서가 손상되었거나 네트워크 오류인 경우)
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/dusty.png', width: 150),
            const SizedBox(height: 24),
            Text(
              'SDSD',
              style: AppTextStyles.bold40.copyWith(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stop the Dump, Save Daily.',
              style: AppTextStyles.medium16.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
