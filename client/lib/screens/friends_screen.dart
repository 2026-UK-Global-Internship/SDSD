//friends_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'add_friends_screen.dart';
import 'package:sdsd/server/services/friendship_service.dart';
import 'package:sdsd/server/services/auth_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendshipService _friendshipService = FriendshipService();
  final AuthService _authService = AuthService();

  // 실제 데이터로 채워짐 (더 이상 하드코딩 아님)
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 현재 페이지 (그리드 페이지네이션용)
  int _currentGridPage = 0;

  // ==========================================
  // 실시간 구독 관리용 상태
  // ==========================================
  // 3개 스트림을 각각 구독하다가, Firestore에서 뭐라도 바뀌면
  // 그때마다 최신 원본 데이터를 합쳐서 화면을 다시 그립니다.
  StreamSubscription<List<Map<String, dynamic>>>? _incomingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _friendsAsUser1Sub;
  StreamSubscription<List<Map<String, dynamic>>>? _friendsAsUser2Sub;

  List<Map<String, dynamic>> _rawIncoming = [];
  List<Map<String, dynamic>> _rawFriendsAsUser1 = [];
  List<Map<String, dynamic>> _rawFriendsAsUser2 = [];

  @override
  void initState() {
    super.initState();
    _subscribeToLiveUpdates();
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _friendsAsUser1Sub?.cancel();
    _friendsAsUser2Sub?.cancel();
    super.dispose();
  }

  // ==========================================
  // 실시간 구독 시작
  // ==========================================
  void _subscribeToLiveUpdates() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _incomingSub = _friendshipService.watchIncomingRequests().listen((data) {
      _rawIncoming = data;
      _onRawDataChanged();
    }, onError: (e) => _handleStreamError(e));

    _friendsAsUser1Sub = _friendshipService.watchFriendsAsUser1().listen((
      data,
    ) {
      _rawFriendsAsUser1 = data;
      _onRawDataChanged();
    }, onError: (e) => _handleStreamError(e));

    _friendsAsUser2Sub = _friendshipService.watchFriendsAsUser2().listen((
      data,
    ) {
      _rawFriendsAsUser2 = data;
      _onRawDataChanged();
    }, onError: (e) => _handleStreamError(e));
  }

  void _handleStreamError(Object e) {
    if (!mounted) return;
    setState(() {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
    });
  }

  // ==========================================
  // 세 스트림 중 하나라도 새 데이터가 오면 호출됨
  // ==========================================
  // 원본(uid만 있는) 데이터를 합치고, 각자의 프로필(이름/캐릭터색)을
  // 조회해서 화면에 뿌릴 최종 데이터를 만듭니다.
  Future<void> _onRawDataChanged() async {
    final friendships = [..._rawFriendsAsUser1, ..._rawFriendsAsUser2];
    final requests = _rawIncoming;

    try {
      final friendsWithProfile = await Future.wait(
        friendships.map((f) async {
          try {
            final profile = await _authService.getUserProfile(
              f['friendUid'] as String,
            );
            return {
              ...f,
              'displayName': profile['displayName'] ?? 'Unknown',
              'characterColor': profile['character']?['color'] ?? '#FF5733',
            };
          } catch (_) {
            return {
              ...f,
              'displayName': 'Unknown',
              'characterColor': '#FF5733',
            };
          }
        }),
      );

      final requestsWithProfile = await Future.wait(
        requests.map((r) async {
          try {
            final profile = await _authService.getUserProfile(
              r['fromUid'] as String,
            );
            return {
              ...r,
              'displayName': profile['displayName'] ?? 'Unknown',
              'characterColor': profile['character']?['color'] ?? '#FF5733',
            };
          } catch (_) {
            return {
              ...r,
              'displayName': 'Unknown',
              'characterColor': '#FF5733',
            };
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _friends = friendsWithProfile;
        _friendRequests = requestsWithProfile;
        _isLoading = false;
        _errorMessage = null;
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
      return const Color(0xFFFF5733); // 파싱 실패 시 기본색
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ============ 상단 바 (뒤로가기 + 타이틀) ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Friends',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // ============ 검색바 (탭하면 Add Friends로 이동) ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddFriendsScreen()),
                  );
                  // 친구 요청은 실시간 스트림으로 자동 반영되므로
                  // 여기서 수동으로 새로고침할 필요가 없습니다.
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        'Search for a name or @Handle',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ============ 메인 콘텐츠 ============
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
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
            TextButton(
              onPressed: () {
                _incomingSub?.cancel();
                _friendsAsUser1Sub?.cancel();
                _friendsAsUser2Sub?.cancel();
                _subscribeToLiveUpdates();
              },
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }

    // 친구가 0명이어도 "받은 요청"이 있으면 목록 화면을 보여줘야 함
    // (요청 섹션이 _buildFriendsList() 안에만 있어서, 이 조건이 없으면
    //  친구가 없을 때 요청이 와 있어도 안 보이는 문제가 있었음)
    final hasContent = _friends.isNotEmpty || _friendRequests.isNotEmpty;
    return hasContent ? _buildFriendsList() : _buildEmptyState();
  }

  // ==================== 친구 없음 상태 ====================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/friends_empty_character.png', width: 260),
          const SizedBox(height: 24),
          const Text(
            'No friends yet!',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search and add friends\nto plog together.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendsScreen()),
              );
              // 친구 요청은 실시간 스트림으로 자동 반영됨
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFF472B6), Color(0xFFFB923C)],
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'Add Friends',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 친구 있음 상태 ====================
  Widget _buildFriendsList() {
    return Column(
      children: [
        // 친구 그리드 (PageView)
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: (_friends.length / 8).ceil(),
            onPageChanged: (index) {
              setState(() => _currentGridPage = index);
            },
            itemBuilder: (context, pageIndex) {
              final start = pageIndex * 8;
              final end = (start + 8).clamp(0, _friends.length);
              final pageFriends = _friends.sublist(start, end);

              return GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const NeverScrollableScrollPhysics(),
                children: pageFriends.map(_buildFriendGridItem).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 페이지 인디케이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            (_friends.length / 8).ceil(),
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentGridPage
                    ? Colors.black
                    : const Color(0xFFD1D5DB),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 회색 구분선
        Container(height: 6, color: const Color(0xFFF3F4F6)),
        // 친구 요청 섹션
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Friend Requests (${_friendRequests.length})',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),
              ..._friendRequests.asMap().entries.map((entry) {
                final index = entry.key;
                final request = entry.value;
                return _buildFriendRequestItem(request, index);
              }),
            ],
          ),
        ),
      ],
    );
  }

  // 그리드 아이템 (캐릭터 + 이름)
  // 온라인/자고있음 배지는 추적하는 데이터가 없어서 제거했습니다.
  Widget _buildFriendGridItem(Map<String, dynamic> friend) {
    final color = _parseColor(friend['characterColor'] as String);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 실제 character.color를 캐릭터 실루엣에 입혀서 표시
        // (4개 고정 이미지 중 하나를 "틀"로만 사용하고, srcIn으로 색만 실제 값으로 교체)
        ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: Image.asset(
            'assets/images/icons/character_yellow.png',
            width: 60,
            height: 60,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          friend['displayName'] as String,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // 게시 시각을 "1d", "2d" 형태로 변환
  String _daysAgoLabel(dynamic createdAt) {
    if (createdAt == null) return '';
    final DateTime created = (createdAt as dynamic).toDate();
    final days = DateTime.now().difference(created).inDays;
    if (days < 1) return 'today';
    return '${days}d';
  }

  // 친구 요청 아이템 (프로필 + 이름 + Accept/Deny)
  Widget _buildFriendRequestItem(Map<String, dynamic> request, int index) {
    final color = _parseColor(request['characterColor'] as String);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                child: Image.asset(
                  'assets/images/icons/character_yellow.png',
                  width: 44,
                  height: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['displayName'] as String,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    // handle 필드가 스키마에 따로 없어서, displayName을 그대로
                    // @표시에 사용합니다 (username_screen도 같은 필드를 씁니다)
                    Text(
                      '@${request['displayName']}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _daysAgoLabel(request['createdAt']),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Accept
              Expanded(
                child: GestureDetector(
                  onTap: () => _acceptFriendRequest(index),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB923C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'Accept',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Deny
              Expanded(
                child: GestureDetector(
                  onTap: () => _denyFriendRequest(index),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFB923C),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Deny',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFFFB923C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Accept 처리
  // (화면에서 직접 리스트를 지우지 않습니다 — 스트림이 Firestore 변경을
  //  감지해서 자동으로 목록을 다시 그려줍니다. 여기선 서비스 호출과
  //  성공/실패 안내만 담당합니다)
  Future<void> _acceptFriendRequest(int index) async {
    final request = _friendRequests[index];
    final friendshipId = request['id'] as String;

    try {
      await _friendshipService.acceptFriendRequest(friendshipId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request['displayName']}님과 친구가 되었습니다!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  // Deny 처리
  Future<void> _denyFriendRequest(int index) async {
    final request = _friendRequests[index];
    final friendshipId = request['id'] as String;

    try {
      await _friendshipService.deleteFriendship(friendshipId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }
}
