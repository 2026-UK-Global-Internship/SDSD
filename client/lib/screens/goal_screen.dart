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

  // 페이지 2: 색 선택 (초기값 null로 설정하여 미선택 상태 구분)
  Color? _selectedColor;
  bool _showPalette = false;

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

  void _onContinue() {
    if (_currentPage == 0) {
      if (_selectedGoal == null) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (_selectedColor == null) return;
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
    // 페이지별 활성화 상태 조건 정의
    final bool canContinue = _currentPage == 0
        ? _selectedGoal != null
        : _selectedColor != null; // 2페이지는 색을 클릭해서 지정해야 활성화

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics:
                      const NeverScrollableScrollPhysics(), // 뒤로가기 버튼 컨트롤을 위해 스와이프 차단 시 유용
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [_buildGoalPage(), _buildColorPage()],
                ),
              ),
              // 하단 인디케이터 + Continue 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
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
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (canContinue && !_isLoading)
                            ? _onContinue
                            : null,
                        style: ElevatedButton.styleFrom(
                          // 활성화 시 검정, 미선택 시 opacity 50% 검정 적용
                          backgroundColor: canContinue
                              ? Colors.black
                              : Colors.black.withValues(alpha: 0.5),
                          disabledBackgroundColor: Colors.black.withValues(
                            alpha: 0.5,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
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
          const SizedBox(height: 120),
          Text(
            'Welcome!\n${widget.name}.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 40,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Let's set your weekly goal.",
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 18,
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
          const SizedBox(height: 20),
          // 뒤로가기 (페이지 1로)
          GestureDetector(
            onTap: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: const Icon(Icons.arrow_back_ios, size: 24),
          ),
          const SizedBox(height: 32),
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
          // Dusty 영역 (팔레트 or 캐릭터)
          Expanded(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // 팔레트 (톱니바퀴 누르면 위쪽에 뜸)
                if (_showPalette)
                  Positioned(top: 0, left: 0, right: 0, child: _buildPalette()),
                // Dusty (가운데 정렬)
                Align(
                  alignment: _showPalette
                      ? Alignment.bottomCenter
                      : Alignment.center,
                  child: _buildDusty(),
                ),
                // 톱니바퀴 (Dusty 오른쪽 위)
                Positioned(
                  top: _showPalette ? 240 : 40, // 팔레트 있으면 아래로
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showPalette = !_showPalette);
                    },
                    child: const Icon(
                      Icons.settings,
                      size: 32,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDusty() {
    // null이거나 검정이면 기본 Dusty
    if (_selectedColor == null || _selectedColor == const Color(0xFF000000)) {
      return Image.asset(
        'assets/images/dusty_default.png',
        width: 231,
        height: 221,
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(_selectedColor!, BlendMode.srcIn),
          child: Image.asset(
            'assets/images/dusty_body.png',
            width: 231,
            height: 221,
          ),
        ),
        Image.asset('assets/images/dusty_eyes.png', width: 231, height: 221),
      ],
    );
  }

  // 색 팔레트 (피그마 격자식)
  Widget _buildPalette() {
    // 각 행: 하나의 색조가 명도별로 세로 배치
    // 열: 다양한 색조 (빨→노→초→파→보 등)
    final List<Color> hues = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.yellow,
      Colors.lime,
      Colors.green,
      Colors.teal,
      Colors.cyan,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.brown,
      Colors.grey,
    ];
    // 명도 (밝은 것 → 어두운 것)
    final List<double> lightness = [0.9, 0.75, 0.6, 0.45, 0.3, 0.15];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: lightness.map((l) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: hues.map((hue) {
              // HSL로 명도 조절해서 격자 색 만들기
              final hsl = HSLColor.fromColor(hue).withLightness(l);
              final color = hsl.toColor();
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
