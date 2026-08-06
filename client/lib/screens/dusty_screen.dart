import 'package:flutter/material.dart';

class DustyScreen extends StatefulWidget {
  const DustyScreen({super.key});

  @override
  State<DustyScreen> createState() => _DustyScreenState();
}

class _DustyScreenState extends State<DustyScreen> {
  // TODO(backend): Firestore에서 실제 유저 데이터 가져오기
  final int _currentLevel = 2;
  final int _nextLevel = 3;
  final double _levelProgress = 0.6; // 0.0 ~ 1.0
  final int _petCount = 3;
  final int _feedCount = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFBBF24), // 노랑
            Color(0xFFF472B6), // 핑크
          ],
          stops: [0.0, 0.29],
        ),
      ),
      child: Stack(
        children: [
          // 배경 이미지 (하늘/바다/언덕/해바라기)
          Positioned.fill(
            child: Image.asset(
              'assets/images/dusty_background.png',
              fit: BoxFit.cover,
            ),
          ),
          // 캐릭터 (Dusty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 50, // 하단 카드 영역 피해서 위쪽에 배치
            child: Center(
              child: Image.asset(
                'assets/images/dusty_lv$_currentLevel.png',
                width: 180,
                height: 180,
              ),
            ),
          ),
          // 하단 카드 (레벨 바 + Pet/Feed 버튼)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
              // 아래쪽 100은 바텀 네비 공간
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 레벨 진행 바
                  _buildLevelBar(),
                  const SizedBox(height: 16),
                  // Pet / Feed 버튼
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          imagePath: 'assets/images/btn_pet.png',
                          count: _petCount,
                          isPet: true, // 하트 표시할지 여부
                          onTap: _onPetTap,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          imagePath: 'assets/images/btn_feed.png',
                          count: _feedCount,
                          isPet: false,
                          onTap: _onFeedTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 레벨 진행 바 (Lv.2 [====---] Lv.3)
  Widget _buildLevelBar() {
    return Row(
      children: [
        Text(
          'Lv.$_currentLevel',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFFFB923C),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _levelProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFFFFEDD5),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFB923C)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Lv.$_nextLevel',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFFFB923C),
          ),
        ),
      ],
    );
  }

  // Pet / Feed 버튼 (이미지 + 하단 카운트 배지)
  Widget _buildActionButton({
    required String imagePath,
    required int count,
    required bool isPet,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset(imagePath, width: double.infinity),
          // 하단 카운트 배지 (+3 ♥  또는  0)
          Positioned(
            bottom: -12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isPet ? '+$count' : '$count',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                  if (isPet) ...[
                    const SizedBox(width: 4),
                    const Text(
                      '♥',
                      style: TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pet 눌렀을 때
  void _onPetTap() {
    // TODO(backend): Firestore에 pet 카운트 증가 + 캐릭터 애정도 반영
    setState(() {
      // 임시: 로컬로 카운트 증가 (백엔드 연동 시 삭제)
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dusty가 좋아해요! 🥰'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Feed 눌렀을 때
  void _onFeedTap() {
    // TODO(backend): Firestore에서 아이템 있는지 확인 후 소비
    if (_feedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먹이가 없어요! 청소하고 아이템을 받으세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    // TODO(backend): 먹이 소비 + 캐릭터 경험치 증가
  }
}
