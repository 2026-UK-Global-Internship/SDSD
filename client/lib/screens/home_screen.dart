import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'package:sdsd/server/services/auth_service.dart';
import 'splash_screen.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.name,
    this.initialTab = 0,
    this.showMapToast = false, // ← 추가
  });
  final String name;
  final int initialTab; // 처음 열 때 어떤 탭 보여줄지 (0=홈, 1=지도, ...)
  final bool showMapToast; // ← 추가: true면 지도 진입 시 "Report submitted!" 알림 표시

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFFF0F0F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, 'nav_home', 'nav_home_active'),
                _buildNavItem(1, 'nav_map', 'nav_map_active'),
                _buildNavItem(2, 'nav_camera', 'nav_camera_active'),
                _buildNavItem(3, 'nav_dusty', 'nav_dusty_active'),
                _buildNavItem(4, 'nav_profile', 'nav_profile_active'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 1:
        return MapScreen(
          showSubmittedToast: widget.showMapToast,
        ); // const 지우고 파라미터 전달
      case 4:
        return _buildTempLogout();
      default:
        return _buildHomePage();
    }
  }

  // 임시 로그아웃 화면 (나중에 프로필 화면으로 교체)
  Widget _buildTempLogout() {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await AuthService().signOut();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
        },
        child: const Text('로그아웃 (임시)'),
      ),
    );
  }

  // ---------- 홈 탭 콘텐츠 ----------
  Widget _buildHomePage() {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  'assets/images/home_header_cloud.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
                Positioned(
                  left: 24,
                  top: 94,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello ${widget.name},',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Continue\nPlogging!',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 70,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: 400,
                  child: _buildActivityCard(),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _currentTab = 1); // 지도 탭으로 전환
                      },
                      child: Image.asset(
                        'assets/images/btn_start_plogging.png',
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CameraScreen(),
                          ),
                        );
                      },
                      child: Image.asset('assets/images/btn_report_trash.png'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/icons/ic_friends.png',
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Friends',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 40,
                      color: Color(0xFFFFAD3B),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: GestureDetector(
                onTap: () {
                  // TODO: 친구 추가 화면으로 이동
                },
                child: Image.asset(
                  'assets/images/btn_add_friends.png',
                  width: double.infinity,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 20, 5, 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildPodium()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 활동 카드 ----------
  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1B039), Color(0xFFFF9C67)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 15, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/icons/ic_home_small.png',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Camden, London',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'My activities this week',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 19,
                    letterSpacing: -1,
                    height: 20 / 19,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'assets/images/icons/ic_broom.png',
                  width: 36,
                  height: 36,
                ),
              ],
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                _buildStat('5', 'days'),
                const SizedBox(width: 120),
                _buildStat('7', 'cleans'),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'Neighborhood Cleanliness',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Text(
                  '75%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: 0.75,
                minHeight: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.35),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String number, String unit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          number,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w900,
            fontSize: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          unit,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w900,
            fontSize: 25,
            height: 30 / 25,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, String icon, String activeIcon) {
    final bool isSelected = _currentTab == index;
    return GestureDetector(
      onTap: () {
        // 카메라 탭(2)은 새 화면으로 push
        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
          return;
        }
        setState(() {
          _currentTab = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Image.asset(
          'assets/images/icons/${isSelected ? activeIcon : icon}.png',
          width: 50,
          height: 50,
        ),
      ),
    );
  }

  Widget _buildPodium() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Image.asset(
          'assets/images/ranking_podium.png',
          width: double.infinity,
          fit: BoxFit.contain,
        ),
        const Positioned(
          top: 24,
          left: 50,
          child: Text(
            'Weekly Ranking',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
        Positioned(
          top: 40,
          child: _buildRanker(
            'assets/images/icons/character_black.png',
            'James',
            '7 cleans',
          ),
        ),
        Positioned(
          top: 70,
          left: 20,
          child: _buildRanker(
            'assets/images/icons/character_pink.png',
            'Chris',
            '5 cleans',
          ),
        ),
        Positioned(
          top: 100,
          right: 20,
          child: _buildRanker(
            'assets/images/icons/character_green.png',
            'Kim',
            '3 cleans',
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Ranking: 15th',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 20 / 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                '3 cleans',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 20 / 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRanker(String character, String name, String cleans) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Image.asset(character, width: 54, height: 54),
        const SizedBox(height: 0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24),
            borderRadius: BorderRadius.circular(20),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: cleans.split(' ')[0],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: ' cleans',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
