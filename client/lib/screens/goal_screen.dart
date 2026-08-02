//goal_screen.dart
import 'package:flutter/material.dart';
import 'package:sdsd/server/services/auth_service.dart'; // ← 변경: 실제 위치(lib/server/services)에 맞춘 패키지 경로

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, required this.name});

  final String name;

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  int? _selectedGoal; // null = 아직 선택 안 함, 0/1/2 = 선택한 카드
  bool _isLoading = false; // ← 추가: Firebase 저장 진행 중 여부

  // Firebase 서비스 인스턴스
  final AuthService _authService = AuthService();

  // ==========================================
  // 카드 인덱스 → Firestore weeklyGoal 값
  // ==========================================
  // 카드 이름(Beginner/Regular/Eco Hero)을 그대로 반영한 값입니다.
  // (auth_service.updateWeeklyGoal()의 허용값도 이와 동일하게 맞춰뒀습니다)
  static const List<String> _goalValues = [
    'beginner', // index 0: Beginner
    'regular', // index 1: Regular
    'ecoHero', // index 2: Eco Hero
  ];

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  // ==========================================
  // Continue 버튼을 눌렀을 때 실행되는 함수
  // ==========================================
  Future<void> _handleContinue() async {
    // 선택 안 했으면 아무것도 하지 않음 (버튼이 disabled라 이 경우는 거의 없음)
    if (_selectedGoal == null) return;

    setState(() {
      _isLoading = true; // 로딩 시작
    });

    try {
      // 현재 로그인한 사용자의 UID 가져오기
      final uid = _authService.currentUserId;

      if (uid == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      // 선택한 카드 인덱스를 Firestore가 허용하는 문자열로 변환
      final goalValue = _goalValues[_selectedGoal!];

      // Firebase에 weeklyGoal 저장
      await _authService.updateWeeklyGoal(uid, goalValue);

      // ★ 여기서 온보딩을 "완료"로 표시합니다.
      //   이 호출이 없으면 사용자는 다음에 로그인해도
      //   영원히 "온보딩 안 끝난 사용자"로 남게 됩니다.
      await _authService.completeOnboarding(uid);

      // 저장 성공 → 홈 화면으로 이동
      if (mounted) {
        // TODO: 실제 홈 화면이 만들어지면 아래 주석을 해제하고 경로를 맞춰주세요.
        // Navigator.of(context).pushReplacementNamed('/home');
        _showSuccessSnackBar('목표가 설정되었습니다!');
      }
    } catch (e) {
      // 저장 실패 → 오류 메시지 표시
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
                // 전달받은 이름 표시!
                Text(
                  'Welcome!\n${widget.name}.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Let's set your weekly goal.",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 32),
                _buildGoalCard(
                  index: 0,
                  title: 'Beginner',
                  subtitle: '3 cleans / week',
                  description: 'Perfect for starting a new habit',
                  selectedImage: 'assets/images/card_beginner.png',
                  unselectedImage: 'assets/images/card_beginner_unselected.png',
                ),
                const SizedBox(height: 14),
                _buildGoalCard(
                  index: 1,
                  title: 'Regular',
                  subtitle: '5 cleans / week',
                  description: 'Build a consistent routine',
                  selectedImage: 'assets/images/card_regular.png',
                  unselectedImage: 'assets/images/card_regular_unselected.png',
                ),
                const SizedBox(height: 14),
                _buildGoalCard(
                  index: 2,
                  title: 'Eco Hero',
                  subtitle: '7 cleans / week',
                  description: 'Make an impact every day',
                  selectedImage: 'assets/images/card_hero.png',
                  unselectedImage: 'assets/images/card_hero_unselected.png',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_selectedGoal != null && !_isLoading)
                        ? _handleContinue // ← 변경: Firebase 저장 로직 연결
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.black.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
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
                        : Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: _selectedGoal != null
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
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

  // ---------- 목표 선택 카드 ----------
  Widget _buildGoalCard({
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required String selectedImage,
    required String unselectedImage,
  }) {
    final bool isSelected = _selectedGoal == index;

    return GestureDetector(
      onTap: _isLoading
          ? null // 저장 중에는 카드 선택 변경 못 하게 막음
          : () {
              setState(() => _selectedGoal = index);
            },
      child: Container(
        width: double.infinity,
        height: 110, // 카드 높이 — 이미지 비율 보고 조절
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isSelected ? selectedImage : unselectedImage),
            fit: BoxFit.fill,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
