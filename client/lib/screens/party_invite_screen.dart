//party_invite_screen.dart
import 'package:flutter/material.dart';
import 'package:sdsd/server/services/friendship_service.dart';
import 'package:sdsd/server/services/auth_service.dart';

class PartyInviteScreen extends StatefulWidget {
  const PartyInviteScreen({super.key});

  @override
  State<PartyInviteScreen> createState() => _PartyInviteScreenState();
}

class _PartyInviteScreenState extends State<PartyInviteScreen> {
  final FriendshipService _friendshipService = FriendshipService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  // ==========================================
  // 친구 목록 + 프로필 정보 불러오기
  // ==========================================
  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final friendships = await _friendshipService.getMyFriends();

      final friendsWithProfile = await Future.wait(
        friendships.map((f) async {
          try {
            final profile = await _authService.getUserProfile(
              f['friendUid'] as String,
            );
            return {
              ...f,
              'name': profile['displayName'] ?? 'Unknown',
              'characterColor': profile['character']?['color'] ?? '#FF5733',
              'selected': false, // 기본값: 아무도 선택 안 된 상태로 시작
            };
          } catch (_) {
            return {
              ...f,
              'name': 'Unknown',
              'characterColor': '#FF5733',
              'selected': false,
            };
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _friends = friendsWithProfile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // HEX 문자열('#RRGGBB') → Color 변환
  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return const Color(0xFFFF5733);
    }
  }

  // 친구가 된 날짜를 "Friends since Jan 2026" 형태로 표시
  // ("함께 플로깅한 횟수"는 다른 사용자의 기록이라 조회할 수 없어서 대체함)
  String _friendsSinceLabel(dynamic updatedAt) {
    if (updatedAt == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final DateTime date = (updatedAt as dynamic).toDate();
    return 'Friends since ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 70, left: 10), // ← 이 숫자로 조절
          child: Column(
            children: [
              // 뒤로가기 버튼
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  padding: EdgeInsets.zero, // ← 추가
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 0),
              // 캐릭터 삼총사 이미지
              Image.asset(
                'assets/images/plogging_together_characters.png',
                width: 346,
              ),
              const SizedBox(height: 10),
              // 타이틀
              const Text(
                'Enjoy plogging together!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 30,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              // 친구 리스트 카드
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                    ),
                    child: _buildFriendListContent(),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              // Add Friends 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      final selected = _friends
                          .where((f) => f['selected'] == true)
                          .map(
                            (f) => {
                              'uid': f['friendUid'],
                              'displayName': f['name'],
                              'characterColor': f['characterColor'],
                            },
                          )
                          .toList();

                      // 선택한 친구 목록을 호출한 화면으로 돌려줌
                      // (그 화면이 이 목록을 들고 PloggingScreen까지 전달합니다)
                      Navigator.pop(context, selected);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFB923C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Add ${_friends.where((f) => f['selected'] == true).length} Friends',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Or go solo 링크
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Not now',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF6E7FFD),
                    decorationColor: Color(0xFF6E7FFD),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: Colors.red[700])),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadFriends, child: const Text('재시도')),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Text(
          '아직 친구가 없어요',
          style: TextStyle(fontFamily: 'Inter', color: Colors.grey[500]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _friends.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey[200],
        height: 1,
        indent: 20,
        endIndent: 20,
      ),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendTile(friend, index);
      },
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend, int index) {
    final color = _parseColor(friend['characterColor'] as String);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 실제 character.color를 캐릭터 실루엣에 입혀서 표시
          ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: Image.asset(
              'assets/images/icons/character_yellow.png',
              width: 44,
              height: 44,
            ),
          ),
          const SizedBox(width: 14),
          // 이름 + 서브텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name'],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _friendsSinceLabel(friend['updatedAt']),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // 체크박스
          GestureDetector(
            onTap: () {
              setState(() {
                _friends[index]['selected'] = !friend['selected'];
              });
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: friend['selected']
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFB923C), Color(0xFFF472B6)],
                      )
                    : null,
                color: friend['selected'] ? null : Colors.white,
                border: Border.all(
                  color: friend['selected']
                      ? Colors.transparent
                      : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              child: friend['selected']
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
