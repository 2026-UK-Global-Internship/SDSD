import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const int _pageCount = 3;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      //TODO: Start 누르면 다음 화면(회원가입/홈)으로 이동
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        children: [_buildCloudsPage(), _buildDustyPage(), _buildMapPage()],
      ),
    );
  }

  // ---------- 페이지 1: 구름 ----------
  Widget _buildCloudsPage() {
    return Container(
      color: const Color(0xFFEFEFEF),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFEFEFEF),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/onboarding_clouds.png',
                    fit: BoxFit.cover,
                  ),
                  Center(
                    child: Image.asset(
                      'assets/images/dusty.png',
                      width: 170,
                      height: 163,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottom(
            title: 'Feed Your Pet,\nClean the Planet.',
            buttonLabel: 'Continue',
          ),
        ],
      ),
    );
  }

  // ---------- 페이지 2: Dusty ----------
  Widget _buildDustyPage() {
    return Container(
      decoration: const BoxDecoration(gradient: _gradient),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/onboarding_dusty.png',
                  width: 300,
                ),
              ),
            ),
            _buildBottom(
              title: "Meet 'Dusty',\nYour Clean-up Buddy!",
              buttonLabel: 'Continue',
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 페이지 3: 영국 지도 ----------
  Widget _buildMapPage() {
    return Container(
      decoration: const BoxDecoration(gradient: _gradient),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/onboarding_uk_map.png',
                  width: 280,
                ),
              ),
            ),
            _buildBottom(
              title: 'Run, Clean, and\nConquer Your Map.',
              buttonLabel: 'Start 🏃',
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 공통 하단 (텍스트 + 점 + 버튼) ----------
  Widget _buildBottom({required String title, required String buttonLabel}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 30,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pageCount, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.black
                      : Colors.black.withValues(alpha: 0.2),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                buttonLabel,
                style: AppTextStyles.semiBold20.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
