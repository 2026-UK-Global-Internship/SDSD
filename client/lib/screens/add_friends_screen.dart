import 'package:flutter/material.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // TODO(backend): Firestore에서 최근 검색 기록 불러오기
  // users/{uid}/recentSearches 서브컬렉션 등
  final List<Map<String, String>> _recentSearches = [
    {'name': 'Elton', 'handle': 'eltoncash99', 'character': 'character_pink'},
    {
      'name': 'Lemon',
      'handle': 'yummylemonade4',
      'character': 'character_yellow',
    },
    {'name': 'Jasmin', 'handle': 'minjasmin0', 'character': 'character_pink'},
    {'name': 'Ben', 'handle': 'jjjjjjb', 'character': 'character_black'},
    {'name': 'Sand', 'handle': 's4ndm4n', 'character': 'character_yellow'},
    {'name': 'Hyun', 'handle': 'hyun00', 'character': 'character_green'},
  ];

  // TODO(backend): Firestore users 컬렉션에서 검색어로 검색
  // handle 또는 displayName으로 startsWith 쿼리
  final List<Map<String, String>> _searchResults = [
    {'name': 'Fred', 'handle': 'fred2009', 'character': 'character_pink'},
    {'name': 'Fred', 'handle': 'ithereal44', 'character': 'character_yellow'},
    {'name': 'Fred', 'handle': 'jk99mm99', 'character': 'character_pink'},
    {'name': 'Free', 'handle': 'unreal324', 'character': 'character_yellow'},
    {'name': 'Free', 'handle': '0099lucy', 'character': 'character_pink'},
    {'name': 'Free', 'handle': 'freeman12', 'character': 'character_black'},
  ];
  final Set<String> _requestedHandles = {};
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 최근 검색에서 한 명 제거
  void _removeRecentSearch(int index) {
    setState(() {
      _recentSearches.removeAt(index);
    });
    // TODO(backend): Firestore에서도 삭제
  }

  // 친구 추가 요청 보내기
  void _sendFriendRequest(Map<String, String> user) {
    final handle = user['handle']!;

    // 이미 요청 보낸 사람이면 무시
    if (_requestedHandles.contains(handle)) return;

    // TODO(backend): Firestore에 친구 요청 저장
    setState(() {
      _requestedHandles.add(handle);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${user['name']}에게 친구 요청 보냄')));
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearching = _searchText.isNotEmpty;

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
                        'Add Friends',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // 뒤로가기 대칭용
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ============ 검색 바 + Close 버튼 ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
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
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchText = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search for a name or @Handle',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // 검색어 있을 때만 X 버튼
                          if (isSearching)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchText = '';
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ============ 리스트 (Recent Searches or Search Results) ============
            Expanded(
              child: isSearching
                  ? _buildSearchResults()
                  : _buildRecentSearches(),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 최근 검색 리스트 ============
  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Recent Searches',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final user = _recentSearches[index];
              return _buildUserRow(
                user: user,
                trailing: GestureDetector(
                  onTap: () => _removeRecentSearch(index),
                  child: Icon(Icons.close, color: Colors.grey[400], size: 22),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final bool isRequested = _requestedHandles.contains(user['handle']);

        return _buildUserRow(
          user: user,
          trailing: GestureDetector(
            onTap: () => _sendFriendRequest(user),
            child: Image.asset(
              isRequested
                  ? 'assets/images/icons/ic_friend_requested.png'
                  : 'assets/images/icons/ic_add_friend.png',
              width: 36,
              height: 36,
            ),
          ),
        );
      },
    );
  }

  // ============ 유저 한 명 표시 (프로필 + 이름 + 핸들 + trailing) ============
  Widget _buildUserRow({
    required Map<String, String> user,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // 캐릭터
          // TODO(backend): 유저의 characterColor 필드에서 캐릭터 이미지 결정
          Image.asset(
            'assets/images/icons/${user['character']}.png',
            width: 44,
            height: 44,
          ),
          const SizedBox(width: 14),
          // 이름 + 핸들
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name']!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '@${user['handle']}',
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
          trailing,
        ],
      ),
    );
  }
}
