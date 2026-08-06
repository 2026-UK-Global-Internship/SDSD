import 'package:flutter/material.dart';
import 'add_friends_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // TODO(backend): Firestore에서 유저의 친구 목록 가져와서 판단
  // 지금은 UI 개발용으로 하드코딩 (true면 친구 있는 화면, false면 없는 화면)
  final bool _hasFriends = true;

  // TODO(backend): Firestore에서 실제 친구 목록 가져오기
  // 각 친구의 characterColor 필드로 캐릭터 이미지 결정
  final List<Map<String, String>> _friends = [
    {'name': 'Zach', 'character': 'character_yellow', 'status': 'online'},
    {'name': 'Oliver', 'character': 'character_pink', 'status': 'online'},
    {'name': 'Callum', 'character': 'character_black', 'status': 'online'},
    {'name': 'Poppy', 'character': 'character_pink', 'status': 'online'},
    {'name': 'Henry', 'character': 'character_pink', 'status': 'online'},
    {'name': 'Isla', 'character': 'character_yellow', 'status': 'sleeping'},
    {'name': 'Freya', 'character': 'character_black', 'status': 'sleeping'},
    {'name': 'Arthur', 'character': 'character_pink', 'status': 'sleeping'},
  ];

  // 현재 페이지 (그리드 페이지네이션용)
  int _currentGridPage = 0;

  // TODO(backend): Firestore에서 실제 친구 요청 목록 가져오기
  final List<Map<String, String>> _friendRequests = [
    {
      'name': 'Elton',
      'handle': 'eltoncash99',
      'character': 'character_pink',
      'daysAgo': '1d',
    },
    {
      'name': 'Kang',
      'handle': 'dhkang09',
      'character': 'character_green',
      'daysAgo': '2d',
    },
    {
      'name': 'Yeonjun',
      'handle': 'thisisyeonjun',
      'character': 'character_black',
      'daysAgo': '7d',
    },
  ];

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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddFriendsScreen()),
                  );
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
            Expanded(
              child: _hasFriends ? _buildFriendsList() : _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
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

  // 그리드 아이템 (캐릭터 + 이름 + 상태)
  Widget _buildFriendGridItem(Map<String, String> friend) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Image.asset(
              'assets/images/icons/${friend['character']}.png',
              width: 60,
              height: 60,
            ),
            // TODO(backend): Firestore에서 실제 온라인/오프라인 상태 가져오기
            if (friend['status'] == 'sleeping')
              Positioned(
                top: -4,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF60A5FA),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Zzz',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 2,
                right: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          friend['name']!,
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

  // 친구 요청 아이템 (프로필 + 이름 + 핸들 + Accept/Deny)
  Widget _buildFriendRequestItem(Map<String, String> request, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/icons/${request['character']}.png',
                width: 44,
                height: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name']!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '@${request['handle']}',
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
                request['daysAgo']!,
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
  void _acceptFriendRequest(int index) {
    final request = _friendRequests[index];
    // TODO(backend): Firestore에 친구 관계 추가 + 요청 삭제
    setState(() {
      _friendRequests.removeAt(index);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${request['name']}님과 친구가 되었습니다!')));
  }

  // Deny 처리
  void _denyFriendRequest(int index) {
    // TODO(backend): Firestore에서 요청 삭제
    setState(() {
      _friendRequests.removeAt(index);
    });
  }
}
