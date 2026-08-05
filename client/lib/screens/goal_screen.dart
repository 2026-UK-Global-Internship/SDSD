import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:sdsd/server/services/auth_service.dart';
import 'package:sdsd/server/services/character_service.dart'; // ← 추가: 캐릭터 색상 변경은 여기 있음

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, required this.name});

  final String name;

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  int? _selectedGoal;
  static const List<String> _goalValues = ['beginner', 'regular', 'ecoHero'];

  Color? _selectedColor;
  bool _showPalette = false;

  bool _isLoading = false;
  final AuthService _authService = AuthService();
  final CharacterService _characterService = CharacterService(); // ← 추가

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

  // ==========================================
  // Color 객체 → '#RRGGBB' 문자열 변환
  // ==========================================
  // auth_service.updateCharacterColor()는 '#RRGGBB'(7글자, 투명도 없음)만
  // 허용하므로, ColorPicker/팔레트가 주는 Color 객체(투명도 포함 32비트 값)에서
  // 투명도 부분을 잘라내고 변환합니다.
  String _colorToHex(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2).toUpperCase()}';
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUserId;
      if (uid == null) throw Exception('로그인된 사용자가 없습니다');

      // 1. 선택한 목표(weeklyGoal) 저장
      final goalValue = _goalValues[_selectedGoal!];
      await _authService.updateWeeklyGoal(uid, goalValue);

      // 2. 선택한 캐릭터 색상 저장 (캐릭터 관련 기능은 CharacterService 담당)
      final hexColor = _colorToHex(_selectedColor!);
      await _characterService.updateCharacterColor(uid, hexColor);

      // 3. 온보딩 완료 처리
      //    (이 호출이 있어야 다음 로그인부터 "온보딩 끝난 사용자"로 인식됩니다)
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
    final bool canContinue = _currentPage == 0
        ? _selectedGoal != null
        : _selectedColor != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [_buildGoalPage(), _buildColorPage()],
                ),
              ),
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
          const SizedBox(height: 100),
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

          if (!_showPalette) ...[
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
          ],

          if (_showPalette) _buildPalette(),

          const SizedBox(height: 24),

          Expanded(
            child: Center(
              child: SizedBox(
                width: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildDusty(),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _showPalette = !_showPalette);
                        },
                        child: Image.asset(
                          'assets/images/icons/ic_settings.png',
                          width: 32,
                          height: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDusty() {
    Widget dustyWidget;

    if (_selectedColor == null || _selectedColor == const Color(0xFF000000)) {
      dustyWidget = Image.asset(
        'assets/images/dusty_default.png',
        width: 231,
        height: 221,
      );
    } else {
      dustyWidget = Stack(
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dustyWidget,
        const SizedBox(height: 1),
        Image.asset('assets/images/dusty_shadow.png', width: 265),
      ],
    );
  }

  Widget _buildPalette() {
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
    final List<double> lightness = [0.9, 0.75, 0.6, 0.45, 0.3, 0.15];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: lightness.map((l) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: hues.map((hue) {
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
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
