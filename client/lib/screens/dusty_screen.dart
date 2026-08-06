//dusty_screen.dart
import 'package:flutter/material.dart';
import 'package:sdsd/server/services/character_service.dart';
import 'package:sdsd/server/services/auth_service.dart';

class DustyScreen extends StatefulWidget {
  const DustyScreen({super.key});

  @override
  State<DustyScreen> createState() => _DustyScreenState();
}

class _DustyScreenState extends State<DustyScreen> {
  final CharacterService _characterService = CharacterService();
  final AuthService _authService = AuthService();

  int _currentLevel = 1;
  int _currentXp = 0;
  int _petCount = 0;
  int _feedCount = 0;

  bool _isLoading = true;
  String? _errorMessage;

  bool _isPetting = false; // Pet 버튼 처리 중
  bool _isFeeding = false; // Feed 버튼 처리 중

  @override
  void initState() {
    super.initState();
    _loadCharacterStatus();
  }

  // ==========================================
  // 캐릭터 상태 불러오기
  // ==========================================
  Future<void> _loadCharacterStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = _authService.currentUserId;
      if (uid == null) {
        throw Exception('로그인이 필요합니다');
      }

      final status = await _characterService.getCharacterStatus(uid);

      if (!mounted) return;
      setState(() {
        _currentLevel = status['level'] as int;
        _currentXp = status['xp'] as int;
        _petCount = status['petChances'] as int;
        _feedCount = status['feedChances'] as int;
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

  // 레벨 N에서 다음 레벨까지 필요한 XP는 N * 100
  // (CharacterService 내부의 레벨업 공식과 동일하게 맞춘 값입니다)
  int get _xpRequiredForNextLevel => _currentLevel * 100;

  double get _levelProgress =>
      (_currentXp / _xpRequiredForNextLevel).clamp(0.0, 1.0);

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
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Image.asset(
                      'assets/images/dusty_lv2.png',
                      // 'assets/images/dusty_lv$_currentLevel.png',
                      width: 180,
                      height: 180,
                    ),
            ),
          ),
          // 오류 배너 + 재시도
          if (_errorMessage != null)
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadCharacterStatus,
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 하단 카드 (레벨 바 + Pet/Feed 버튼)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
                          isLoading: _isPetting,
                          onTap: _onPetTap,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          imagePath: 'assets/images/btn_feed.png',
                          count: _feedCount,
                          isPet: false,
                          isLoading: _isFeeding,
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
          'Lv.${_currentLevel + 1}',
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
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Opacity(
            opacity: isLoading ? 0.5 : 1.0,
            child: Image.asset(imagePath, width: double.infinity),
          ),
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
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
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
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFEF4444),
                            ),
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

  // ==========================================
  // Pet 눌렀을 때
  // ==========================================
  Future<void> _onPetTap() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    setState(() => _isPetting = true);

    try {
      final result = await _characterService.petCharacter(uid);

      if (!mounted) return;
      setState(() {
        _petCount = result['remainingPetChances'] as int;
        _currentLevel = result['newLevel'] as int;
        _currentXp = result['newXp'] as int;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dusty가 좋아해요! 🥰'),
          duration: Duration(seconds: 1),
        ),
      );

      if (result['leveledUp'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('레벨업! Lv.$_currentLevel')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) setState(() => _isPetting = false);
    }
  }

  // ==========================================
  // Feed 눌렀을 때
  // ==========================================
  Future<void> _onFeedTap() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    setState(() => _isFeeding = true);

    try {
      final result = await _characterService.feedCharacter(uid);

      if (!mounted) return;
      setState(() {
        _feedCount = result['remainingFeedChances'] as int;
        _currentLevel = result['newLevel'] as int;
        _currentXp = result['newXp'] as int;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('냠냠! 맛있게 먹었어요 🍖'),
          duration: Duration(seconds: 1),
        ),
      );

      if (result['leveledUp'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('레벨업! Lv.$_currentLevel')));
      }
    } catch (e) {
      // "먹이가 없어요. N분 후 충전됩니다" 같은 서버의 정확한 메시지를
      // 그대로 보여줍니다 (하드코딩된 안내문 대신).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) setState(() => _isFeeding = false);
    }
  }
}
