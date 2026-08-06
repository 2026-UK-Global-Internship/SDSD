//add_friends_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sdsd/server/services/friendship_service.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FriendshipService _friendshipService = FriendshipService();

  String _searchText = '';
  Timer? _debounce; // 타이핑마다 검색 안 날리게 살짝 지연

  List<Map<String, dynamic>> _recentSearches = [];
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _requestedUids = {}; // 이번 화면 세션에서 요청 보낸 사람들

  bool _isLoadingRecent = true;
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ==========================================
  // 최근 검색 불러오기
  // ==========================================
  Future<void> _loadRecentSearches() async {
    setState(() => _isLoadingRecent = true);
    try {
      final results = await _friendshipService.getRecentSearches();
      if (!mounted) return;
      setState(() {
        _recentSearches = results;
        _isLoadingRecent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingRecent = false); // 실패해도 화면은 정상 진행
    }
  }

  // 최근 검색에서 한 명 제거
  Future<void> _removeRecentSearch(int index) async {
    final removed = _recentSearches[index];
    setState(() => _recentSearches.removeAt(index));

    try {
      await _friendshipService.removeRecentSearch(
        removed['targetUid'] as String,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _recentSearches.insert(index, removed)); // 실패 시 복원
    }
  }

  // ==========================================
  // 검색어 입력 처리 (디바운스 적용)
  // ==========================================
  void _onSearchChanged(String value) {
    setState(() => _searchText = value);

    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(value.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _friendshipService.searchUsersByName(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString().replaceFirst('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  // ==========================================
  // 친구 추가 요청 보내기
  // ==========================================
  Future<void> _sendFriendRequest(Map<String, dynamic> user) async {
    final uid = user['uid'] as String;

    if (_requestedUids.contains(uid)) return; // 이미 요청 보낸 사람이면 무시

    setState(() => _requestedUids.add(uid)); // 낙관적 업데이트

    try {
      await _friendshipService.sendFriendRequest(uid);

      // 요청을 보냈다는 건 이 사람을 검색해서 골랐다는 뜻이므로
      // 최근 검색에도 함께 저장
      await _friendshipService.saveRecentSearch(
        targetUid: uid,
        displayName: user['displayName'] as String,
        characterColor: user['characterColor'] as String? ?? '#FF5733',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['displayName']}에게 친구 요청 보냄')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestedUids.remove(uid)); // 실패 시 되돌림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[600],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final bool isSearching = _searchText.trim().length >= 2;

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
                              onChanged: _onSearchChanged,
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
                          if (isSearching)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchText = '';
                                  _searchResults = [];
                                  _searchError = null;
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
    if (_isLoadingRecent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentSearches.isEmpty) {
      return Center(
        child: Text(
          '최근 검색 기록이 없습니다',
          style: TextStyle(fontFamily: 'Inter', color: Colors.grey[500]),
        ),
      );
    }

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
                displayName: user['displayName'] as String,
                characterColor: user['characterColor'] as String? ?? '#FF5733',
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
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchError != null) {
      return Center(
        child: Text(_searchError!, style: TextStyle(color: Colors.red[700])),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          '검색 결과가 없습니다',
          style: TextStyle(fontFamily: 'Inter', color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final uid = user['uid'] as String;
        final bool isRequested = _requestedUids.contains(uid);

        return _buildUserRow(
          displayName: user['displayName'] as String,
          characterColor: user['characterColor'] as String? ?? '#FF5733',
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

  // ============ 유저 한 명 표시 (프로필 + 이름 + trailing) ============
  Widget _buildUserRow({
    required String displayName,
    required String characterColor,
    required Widget trailing,
  }) {
    final color = _parseColor(characterColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          // 이름 + @표시 (handle 필드가 스키마에 없어서 displayName을 그대로 사용)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '@$displayName',
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
