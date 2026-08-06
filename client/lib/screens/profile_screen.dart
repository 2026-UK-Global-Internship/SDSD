import 'package:flutter/material.dart';
import 'package:sdsd/server/services/auth_service.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // TODO(backend): Firestore에서 실제 데이터 가져오기
  final int _daysSaving = 732;
  final int _totalCleans = 583;
  final int _totalSteps = 1749320;
  final int _totalKcal = 87500;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F6F4), // 배경 살짝 회색 (섹션 구분용)
      child: SafeArea(
        bottom: false, // 바텀 네비 영역까지는 SafeArea 무시
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // My 타이틀
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Text(
                  'My',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    color: Colors.black,
                  ),
                ),
              ),
              // Saving the Earth 배너
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8FFC2), // 연한 초록 배경
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 20,
                              color: Color(0xFF59AB50), // 진한 초록 글자
                            ),
                            children: [
                              const TextSpan(
                                text: 'Saving the Earth for ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: '$_daysSaving days',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Image.asset(
                        'assets/images/icons/ic_earth.png',
                        width: 24,
                        height: 24,
                      ),
                    ],
                  ),
                ),
              ),
              // 통계 카드 3개
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        iconPath: 'assets/images/icons/ic_broom_pink.png',
                        value: '$_totalCleans',
                        label: 'CLEANS',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        iconPath: 'assets/images/icons/ic_steps.png',
                        value: _formatNumber(_totalSteps),
                        label: 'STEPS',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        iconPath: 'assets/images/icons/ic_kcal.png',
                        value: _formatNumber(_totalKcal),
                        label: 'KCAL',
                      ),
                    ),
                  ],
                ),
              ),
              // Account 섹션
              _buildSectionHeader('Account'),
              _buildMenuItem(
                iconPath: 'assets/images/icons/ic_profile.png',
                label: 'Profile',
                onTap: () {
                  // TODO: Profile 상세 화면 만들면 연결
                },
              ),
              _buildMenuItem(
                iconPath: 'assets/images/icons/ic_friends_menu.png',
                label: 'Friends',
                onTap: () {
                  // TODO: FriendsScreen으로 이동
                },
              ),
              _buildMenuItem(
                iconPath: 'assets/images/icons/ic_history.png',
                label: 'History',
                onTap: () {
                  // TODO: History 화면 만들면 연결
                },
              ),
              // App Settings 섹션
              _buildSectionHeader('App Settings'),
              _buildMenuItem(
                iconPath: 'assets/images/icons/ic_goals.png',
                label: 'Goals',
                onTap: () {
                  // TODO: Goals 화면 만들면 연결
                },
              ),
              _buildMenuItem(
                iconPath: 'assets/images/icons/ic_notifications.png',
                label: 'Notifications',
                onTap: () {
                  // TODO: Notifications 설정 화면 만들면 연결
                },
              ),
              _buildMenuItem(
                iconPath: 'assets/images/icons/ic_preferences.png',
                label: 'Preferences',
                onTap: () {
                  // TODO: Preferences 화면 만들면 연결
                  // (여기에 로그아웃 기능도 들어갈 예정)
                },
              ),
              // Log Out (임시 위치 - 나중에 Preferences 화면 안으로 이동 예정)
              const SizedBox(height: 12),
              InkWell(
                onTap: _showLogoutDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 24, color: Colors.red[400]),
                      const SizedBox(width: 16),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.red[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 100), // 바텀 네비랑 안 겹치게 여유
            ],
          ),
        ),
      ),
    );
  }

  // 통계 카드 하나 만드는 헬퍼
  Widget _buildStatCard({
    required String iconPath,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Image.asset(iconPath, width: 32, height: 32),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 11,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 숫자 포맷: 1749320 → "1,749,320"
  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  // 섹션 헤더 (Account, App Settings 등)
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 13,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  // 메뉴 아이템 (아이콘 + 라벨, 탭 가능)
  Widget _buildMenuItem({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Image.asset(iconPath, width: 24, height: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 로그아웃 확인 다이얼로그
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // 다이얼로그 먼저 닫기
              await AuthService().signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
              );
            },
            child: Text(
              'Log Out',
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
