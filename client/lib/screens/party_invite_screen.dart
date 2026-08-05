import 'package:flutter/material.dart';

class PartyInviteScreen extends StatefulWidget {
  const PartyInviteScreen({super.key});

  @override
  State<PartyInviteScreen> createState() => _PartyInviteScreenState();
}

class _PartyInviteScreenState extends State<PartyInviteScreen> {
  // TODO(backend): Firebase에서 친구 목록 가져오기
  // 각 친구는 firestore users 컬렉션에서 characterColor 필드로 색 지정됨
  final List<Map<String, dynamic>> _friends = [
    {
      'name': 'Chris',
      'subtitle': 'Plogged together 7 times.',
      'character': 'character_pink', // TODO(backend): Firebase에서 받아온 색으로 교체
      'selected': false,
    },
    {
      'name': 'James',
      'subtitle': 'Plogged together 3 times.',
      'character': 'character_yellow', // TODO(backend): Firebase에서 받아온 색으로 교체
      'selected': true,
    },
    {
      'name': 'Ben',
      'subtitle': 'Plogged together once.',
      'character': 'character_green', // TODO(backend): Firebase에서 받아온 색으로 교체
      'selected': true,
    },
    {
      'name': 'Dog',
      'subtitle': 'No plogging history yet.',
      'character': 'character_black', // TODO(backend): Firebase에서 받아온 색으로 교체
      'selected': false,
    },
  ];

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
                    child: ListView.separated(
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
                    ),
                  ),
                ),
              ),

              // 친구 리스트 카드
              const SizedBox(height: 30),
              // Add Friends 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      // 선택된 친구 수 계산
                      final selectedCount = _friends
                          .where((f) => f['selected'] == true)
                          .length;
                      // TODO(backend): 선택된 친구들에게 파티 초대 전송
                      // TODO: 파티 시작 화면으로 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$selectedCount명 초대!')),
                      );
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
                  // TODO: 혼자 플로깅 시작 화면으로 이동
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

              // TODO: 타이틀
              // TODO: 친구 리스트 카드
              // TODO: Add Friends 버튼 + Or go solo
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 캐릭터 이미지
          Image.asset(
            'assets/images/icons/${friend['character']}.png',
            width: 44,
            height: 44,
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
                  friend['subtitle'],
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
