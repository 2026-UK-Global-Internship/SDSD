//home_screen.dart
import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'package:sdsd/server/services/auth_service.dart';
import 'package:sdsd/server/services/flogging_service.dart';
import 'package:sdsd/server/services/hotspots_service.dart';
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

  // 신고 완료 토스트를 "한 번만" 보여주기 위한 상태
  // widget.showMapToast는 고정값이라 그대로 쓰면 지도 탭을 오갈 때마다
  // 계속 다시 뜨므로, 한 번 보여준 뒤 false로 꺼지는 별도 변수로 관리합니다.
  late bool _pendingMapToast;

  // ==========================================
  // 활동 카드용 상태
  // ==========================================
  final FloggingService _floggingService = FloggingService();
  final HotspotService _hotspotService = HotspotService();

  int _weeklyDays = 0;
  int _weeklyCleans = 0;
  double _cleanlinessPercent = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _pendingMapToast = widget.showMapToast;
    _loadStats();
  }

  // ==========================================
  // 이번 주 활동 통계 + 전체 청결도 불러오기
  // ==========================================
  Future<void> _loadStats() async {
    try {
      // 두 요청을 동시에 진행 (하나씩 순서대로 기다릴 필요 없음)
      final results = await Future.wait([
        _floggingService.getWeeklyStats(),
        _hotspotService.getCleanlinessPercentage(),
      ]);

      if (!mounted) return;
      setState(() {
        _weeklyDays = (results[0] as Map<String, int>)['days'] ?? 0;
        _weeklyCleans = (results[0] as Map<String, int>)['cleans'] ?? 0;
        _cleanlinessPercent = results[1] as double;
        _isLoadingStats = false;
      });
    } catch (e) {
      // 홈 화면 진입 자체를 막을 정도는 아니라서, 조용히 0으로 표시하고 넘어감
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
    }
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
          showSubmittedToast: _pendingMapToast,
          onToastShown: () {
            // 토스트를 이미 보여줬으니, 다음에 지도 탭에 다시 들어와도
            // 또 뜨지 않도록 소비(consume) 처리
            _pendingMapToast = false;
          },
        );
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
    // 로딩 중엔 '-' 로 표시 (0을 보여주면 "진짜 0회"인지 "아직 안 불러왔는지" 헷갈림)
    final String daysText = _isLoadingStats ? '-' : '$_weeklyDays';
    final String cleansText = _isLoadingStats ? '-' : '$_weeklyCleans';
    final String percentText = _isLoadingStats
        ? '-'
        : '${_cleanlinessPercent.round()}%';
    final double progressValue = _isLoadingStats
        ? 0
        : (_cleanlinessPercent / 100).clamp(0, 1);

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
                _buildStat(daysText, 'days'), // ← 실제 이번 주 활동일수
                const SizedBox(width: 120),
                _buildStat(cleansText, 'cleans'), // ← 실제 이번 주 청소 횟수
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
                Text(
                  percentText, // ← 실제 전체 hotspot 청소완료 비율
                  style: const TextStyle(
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
                value: progressValue, // ← 실제 비율로 채워짐
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

  // ---------- Weekly Ranking (하드코딩 유지) ----------
  // 다른 사용자의 조깅/청소 기록은 Security Rules상 본인만 읽을 수 있어서
  // 지금 구조로는 실시간 랭킹을 만들 수 없습니다.
  // 나중에 랭킹용 공개 컬렉션(예: leaderboard)이나 별도 Security Rules를
  // 설계하게 되면 이 부분을 실제 데이터로 교체하면 됩니다.
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
