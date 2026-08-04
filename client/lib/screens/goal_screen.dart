import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:sdsd/server/services/auth_service.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, required this.name});

  final String name;

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 페이지 1: 목표 선택
  int? _selectedGoal;
  static const List<String> _goalValues = ['beginner', 'regular', 'ecoHero'];

  // 페이지 2: 색 선택
  Color _selectedColor = Colors.black; // 기본은 검정 Dusty
  bool _showPalette = false; // 톱니바퀴 토글: 팔레트 보이기/숨기기

  bool _isLoading = false;
  final AuthService _authService = AuthService();

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 다음 버튼 눌렀을 때
  void _onContinue() {
    if (_currentPage == 0) {
      // 페이지 1 → 페이지 2
      if (_selectedGoal == null) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 페이지 2 → Firebase 저장 + 홈 이동
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUserId;
      if (uid == null) throw Exception('로그인된 사용자가 없습니다');

      final goalValue = _goalValues[_selectedGoal!];
      await _authService.updateWeeklyGoal(uid, goalValue);
      await _authService.completeOnboarding(uid);
      // TODO: 나중에 색상도 Firebase에 저장

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(name: widget.name)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 다음 버튼 활성화 조건
    final bool canContinue = _currentPage == 0
        ? _selectedGoal != null
        : true; // 색 선택은 기본값이 있으니 항상 활성화

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Column(
            children: [
              // 스와이프 되는 페이지 영역
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [_buildGoalPage(), _buildColorPage()],
                ),
              ),
              // 하단: 점 인디케이터 + Continue 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
                    // 점 인디케이터
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(2, (i) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == i
                                ? Colors.black
                                : Colors.black.withValues(alpha: 0.25),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    // Continue 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (canContinue && !_isLoading)
                            ? _onContinue
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
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 페이지 1: 목표 선택 ----------
  Widget _buildGoalPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
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
        ],
      ),
    );
  }

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
      onTap: _isLoading ? null : () => setState(() => _selectedGoal = index),
      child: Container(
        width: double.infinity,
        height: 110,
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

  // ---------- 페이지 2: 색 선택 ----------
  Widget _buildColorPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          const Text(
            "Choose Dusty's\ncolor.",
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 40,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Personalize your pet with a color.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          // Dusty + 톱니바퀴
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dusty (색 입힌 몸통 + 눈)
                _buildDusty(),
                // 톱니바퀴 (오른쪽 위)
                Positioned(
                  top: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showPalette = !_showPalette);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.settings,
                        size: 22,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                // 팔레트 (톱니바퀴 눌렀을 때만)
                if (_showPalette)
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: _buildPalette(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 색 입힌 Dusty (몸통 + 눈 겹침)
  Widget _buildDusty() {
    // 기본 검정이면 default 이미지 그대로, 색 있으면 흰 밑판에 색 입히기
    if (_selectedColor == Colors.black) {
      return Image.asset('assets/images/dusty_default.png', width: 240);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        // 색 입힌 몸통
        ColorFiltered(
          colorFilter: ColorFilter.mode(_selectedColor, BlendMode.srcIn),
          child: Image.asset('assets/images/dusty_body.png', width: 240),
        ),
        // 눈 (색 위에 겹침)
        Image.asset('assets/images/dusty_eyes.png', width: 240),
      ],
    );
  }

  // 색 팔레트 (간단한 격자)
  Widget _buildPalette() {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.brown,
      Colors.teal,
      Colors.cyan,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: colors.map((color) {
          final isSelected = _selectedColor == color;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
