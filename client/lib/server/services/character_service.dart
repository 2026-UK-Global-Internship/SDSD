//character_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CharacterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _log(String msg) => print('[CharacterService] $msg');

  static const int _xpPerFeed = 5;
  static const int _xpPerPet = 8;
  static const Duration _feedRegenInterval = Duration(hours: 2);

  int _xpRequiredForNextLevel(int currentLevel) {
    return currentLevel * 100;
  }

  Map<String, int> _calculateXpAndLevel({
    required int currentLevel,
    required int currentXp,
    required int xpToAdd,
  }) {
    int newLevel = currentLevel;
    int newXp = currentXp + xpToAdd;
    int levelUpCount = 0;

    while (newXp >= _xpRequiredForNextLevel(newLevel)) {
      newXp -= _xpRequiredForNextLevel(newLevel);
      newLevel += 1;
      levelUpCount += 1;
    }

    return {'level': newLevel, 'xp': newXp, 'levelUpCount': levelUpCount};
  }

  Map<String, dynamic> _applyFeedRegen({
    required int currentFeed,
    required DateTime? lastRegenAt,
  }) {
    final now = DateTime.now();

    if (lastRegenAt == null) {
      return {'feed': currentFeed, 'lastRegenAt': now, 'changed': true};
    }

    final elapsedMinutes = now.difference(lastRegenAt).inMinutes;
    final intervalMinutes = _feedRegenInterval.inMinutes;
    final intervalsPassed = elapsedMinutes ~/ intervalMinutes;

    if (intervalsPassed <= 0) {
      return {
        'feed': currentFeed,
        'lastRegenAt': lastRegenAt,
        'changed': false,
      };
    }

    final newLastRegenAt = lastRegenAt.add(
      Duration(minutes: intervalsPassed * intervalMinutes),
    );

    return {
      'feed': currentFeed + intervalsPassed,
      'lastRegenAt': newLastRegenAt,
      'changed': true,
    };
  }

  // ==========================================
  // 1. 캐릭터 상태 조회
  // ==========================================
  Future<Map<String, dynamic>> getCharacterStatus(String uid) async {
    final sw = Stopwatch()..start();
    _log('🔵 getCharacterStatus 시작 (uid=$uid)');
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      _log('  → Firestore 문서 조회 완료 (${sw.elapsedMilliseconds}ms)');

      if (!doc.exists) {
        throw Exception('사용자를 찾을 수 없습니다');
      }

      final character = doc.data()!['character'] as Map<String, dynamic>?;
      if (character == null) {
        throw Exception('캐릭터 정보가 없습니다');
      }

      final raise = character['raise'] as Map<String, dynamic>;
      final lastRegenTimestamp = raise['lastFeedRegenAt'] as Timestamp?;

      final regen = _applyFeedRegen(
        currentFeed: raise['feed'] as int,
        lastRegenAt: lastRegenTimestamp?.toDate(),
      );
      _log('  → feed 자동충전 계산 완료 (${sw.elapsedMilliseconds}ms)');

      final nextRegenAt = (regen['lastRegenAt'] as DateTime).add(
        _feedRegenInterval,
      );
      final secondsUntilNextFeed = nextRegenAt
          .difference(DateTime.now())
          .inSeconds;

      _log('✅ getCharacterStatus 성공 (총 ${sw.elapsedMilliseconds}ms)');
      return {
        'level': character['level'],
        'xp': character['xp'],
        'color': character['color'],
        'petChances': raise['pet'],
        'feedChances': regen['feed'],
        'secondsUntilNextFeed': secondsUntilNextFeed > 0
            ? secondsUntilNextFeed
            : 0,
      };
    } catch (e) {
      _log('❌ getCharacterStatus 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('캐릭터 상태 조회 실패: $e');
    }
  }

  // ==========================================
  // 2. XP 직접 추가
  // ==========================================
  Future<Map<String, dynamic>> addXp(String uid, int amount) async {
    final sw = Stopwatch()..start();
    _log('🔵 addXp 시작 (uid=$uid, amount=$amount)');
    if (amount <= 0) {
      throw Exception('추가할 XP는 0보다 커야 합니다');
    }

    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final userRef = _firestore.collection('users').doc(uid);
        final snapshot = await transaction.get(userRef);
        _log('  → Transaction: 사용자 문서 조회 완료 (${sw.elapsedMilliseconds}ms)');

        if (!snapshot.exists) {
          throw Exception('사용자를 찾을 수 없습니다');
        }

        final character = snapshot.data()!['character'] as Map<String, dynamic>;

        final calc = _calculateXpAndLevel(
          currentLevel: character['level'] as int,
          currentXp: character['xp'] as int,
          xpToAdd: amount,
        );

        transaction.update(userRef, {
          'character.level': calc['level'],
          'character.xp': calc['xp'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _log('  → Transaction: 업데이트 큐잉 완료 (${sw.elapsedMilliseconds}ms)');

        return {
          'newLevel': calc['level'],
          'newXp': calc['xp'],
          'leveledUp': calc['levelUpCount']! > 0,
          'levelUpCount': calc['levelUpCount'],
        };
      });

      _log(
        '✅ addXp 성공: +$amount (레벨업 ${result['levelUpCount']}회, Lv.${result['newLevel']}) '
        '(총 ${sw.elapsedMilliseconds}ms)',
      );

      return result;
    } catch (e) {
      _log('❌ addXp 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('XP 추가 실패: $e');
    }
  }

  // ==========================================
  // 3. 상호작용 기회 지급
  // ==========================================
  Future<int> grantOpportunity(
    String uid, {
    required String type,
    int amount = 1,
  }) async {
    final sw = Stopwatch()..start();
    _log('🔵 grantOpportunity 시작 (uid=$uid, type=$type, amount=$amount)');
    if (type != 'feed' && type != 'pet') {
      throw Exception('type은 feed 또는 pet이어야 합니다');
    }
    if (amount <= 0) {
      throw Exception('지급할 기회는 0보다 커야 합니다');
    }

    try {
      final userRef = _firestore.collection('users').doc(uid);

      await userRef.update({
        'character.raise.$type': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log(
        '✅ grantOpportunity 성공: $type +$amount (${sw.elapsedMilliseconds}ms)',
      );
      return amount;
    } catch (e) {
      _log('❌ grantOpportunity 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('기회 지급 실패: $e');
    }
  }

  // ==========================================
  // 4. 캐릭터 색상 변경
  // ==========================================
  Future<void> updateCharacterColor(String uid, String color) async {
    final sw = Stopwatch()..start();
    _log('🔵 updateCharacterColor 시작 (uid=$uid, color=$color)');
    try {
      if (!color.startsWith('#') || color.length != 7) {
        throw Exception('올바른 HEX 색상을 입력해주세요 (예: #FF5733)');
      }

      await _firestore.collection('users').doc(uid).update({
        'character.color': color,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('✅ updateCharacterColor 성공 (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ updateCharacterColor 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('색상 변경 실패: $e');
    }
  }

  // ==========================================
  // 5. 먹이주기
  // ==========================================
  Future<Map<String, dynamic>> feedCharacter(String uid) async {
    final sw = Stopwatch()..start();
    _log('🔵 feedCharacter 시작 (uid=$uid)');
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final userRef = _firestore.collection('users').doc(uid);
        final snapshot = await transaction.get(userRef);
        _log('  → Transaction: 사용자 문서 조회 완료 (${sw.elapsedMilliseconds}ms)');

        if (!snapshot.exists) {
          throw Exception('사용자를 찾을 수 없습니다');
        }

        final character = snapshot.data()!['character'] as Map<String, dynamic>;
        final raise = character['raise'] as Map<String, dynamic>;

        final lastRegenTimestamp = raise['lastFeedRegenAt'] as Timestamp?;
        final regen = _applyFeedRegen(
          currentFeed: raise['feed'] as int,
          lastRegenAt: lastRegenTimestamp?.toDate(),
        );
        _log('  → feed 자동충전 계산 완료 (${sw.elapsedMilliseconds}ms)');

        final availableFeed = regen['feed'] as int;

        if (availableFeed <= 0) {
          final nextRegenAt = (regen['lastRegenAt'] as DateTime).add(
            _feedRegenInterval,
          );
          final remaining = nextRegenAt.difference(DateTime.now());
          throw Exception('먹이 기회가 없습니다. ${remaining.inMinutes}분 후 다시 충전됩니다');
        }

        final calc = _calculateXpAndLevel(
          currentLevel: character['level'] as int,
          currentXp: character['xp'] as int,
          xpToAdd: _xpPerFeed,
        );

        transaction.update(userRef, {
          'character.raise.feed': availableFeed - 1,
          'character.raise.lastFeedRegenAt': Timestamp.fromDate(
            regen['lastRegenAt'] as DateTime,
          ),
          'character.level': calc['level'],
          'character.xp': calc['xp'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _log('  → Transaction: 업데이트 큐잉 완료 (${sw.elapsedMilliseconds}ms)');

        return {
          'remainingFeedChances': availableFeed - 1,
          'xpGained': _xpPerFeed,
          'newLevel': calc['level'],
          'newXp': calc['xp'],
          'leveledUp': calc['levelUpCount']! > 0,
        };
      });

      _log(
        '✅ feedCharacter 성공: 남은기회=${result['remainingFeedChances']}, '
        '+$_xpPerFeed XP (총 ${sw.elapsedMilliseconds}ms)',
      );

      return result;
    } catch (e) {
      _log('❌ feedCharacter 실패: $e (${sw.elapsedMilliseconds}ms)');
      if (e.toString().contains('다시 충전됩니다')) {
        rethrow;
      }
      throw Exception('먹이주기 실패: $e');
    }
  }

  // ==========================================
  // 6. 쓰다듬기
  // ==========================================
  Future<Map<String, dynamic>> petCharacter(String uid) async {
    final sw = Stopwatch()..start();
    _log('🔵 petCharacter 시작 (uid=$uid)');
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final userRef = _firestore.collection('users').doc(uid);
        final snapshot = await transaction.get(userRef);
        _log('  → Transaction: 사용자 문서 조회 완료 (${sw.elapsedMilliseconds}ms)');

        if (!snapshot.exists) {
          throw Exception('사용자를 찾을 수 없습니다');
        }

        final character = snapshot.data()!['character'] as Map<String, dynamic>;
        final raise = character['raise'] as Map<String, dynamic>;

        final availablePet = raise['pet'] as int;

        if (availablePet <= 0) {
          throw Exception('쓰다듬기 기회가 없습니다. Hotspot을 청소해서 기회를 모아보세요!');
        }

        final calc = _calculateXpAndLevel(
          currentLevel: character['level'] as int,
          currentXp: character['xp'] as int,
          xpToAdd: _xpPerPet,
        );

        transaction.update(userRef, {
          'character.raise.pet': availablePet - 1,
          'character.level': calc['level'],
          'character.xp': calc['xp'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _log('  → Transaction: 업데이트 큐잉 완료 (${sw.elapsedMilliseconds}ms)');

        return {
          'remainingPetChances': availablePet - 1,
          'xpGained': _xpPerPet,
          'newLevel': calc['level'],
          'newXp': calc['xp'],
          'leveledUp': calc['levelUpCount']! > 0,
        };
      });

      _log(
        '✅ petCharacter 성공: 남은기회=${result['remainingPetChances']}, '
        '+$_xpPerPet XP (총 ${sw.elapsedMilliseconds}ms)',
      );

      return result;
    } catch (e) {
      _log('❌ petCharacter 실패: $e (${sw.elapsedMilliseconds}ms)');
      if (e.toString().contains('기회가 없습니다')) {
        rethrow;
      }
      throw Exception('쓰다듬기 실패: $e');
    }
  }
}
