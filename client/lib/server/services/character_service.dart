import 'package:cloud_firestore/cloud_firestore.dart';

class CharacterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // 밸런스 조정용 상수
  // ==========================================
  static const int _xpPerFeed = 5; // 먹이주기 1회 소모당 XP
  static const int _xpPerPet = 8; // 쓰다듬기 1회 소모당 XP (서로 다른 양으로 설정)
  static const Duration _feedRegenInterval = Duration(
    hours: 2,
  ); // feed 기회 자동 충전 주기

  // 레벨 N → N+1 에 필요한 XP = N * 100
  int _xpRequiredForNextLevel(int currentLevel) {
    return currentLevel * 100;
  }

  // ==========================================
  // 공통 헬퍼: XP를 더하고 레벨업 여부를 계산 (순수 계산 함수)
  // ==========================================
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

  // ==========================================
  // 공통 헬퍼: feed 기회의 "지연 계산식 자동 충전"
  // ==========================================
  // 서버가 실시간으로 2시간마다 값을 채워주는 게 아니라,
  // "값을 확인/사용하는 시점"에 마지막 계산 이후 몇 번의 2시간이
  // 지났는지 역산해서 그만큼 한꺼번에 채워주는 방식입니다.
  // (Cloud Functions 스케줄러 없이도 정확하게 동작합니다)
  Map<String, dynamic> _applyFeedRegen({
    required int currentFeed,
    required DateTime? lastRegenAt,
  }) {
    final now = DateTime.now();

    // 최초 1회(기록이 아예 없는 경우): 지금을 기준 시각으로 삼고 보너스 없이 시작
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

    // 지난 시간만큼 정확히 앞으로 당겨서 기준 시각을 갱신
    // (예: "지금 시각"으로 덮어쓰면 다음 충전까지 남은 시간이 매번 손해봄)
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
  // 1. 캐릭터 상태 조회 (feed 기회는 계산해서 최신값으로 보여줌, 쓰기는 안 함)
  // ==========================================
  // 화면에 표시용으로만 쓰는 "읽기 전용" 조회입니다.
  // 실제 충전량이 Firestore에 반영(저장)되는 시점은 feedCharacter()를
  // 실제로 호출할 때입니다. (불필요한 쓰기 횟수를 줄이기 위한 설계)
  Future<Map<String, dynamic>> getCharacterStatus(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

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

      final nextRegenAt = (regen['lastRegenAt'] as DateTime).add(
        _feedRegenInterval,
      );
      final secondsUntilNextFeed = nextRegenAt
          .difference(DateTime.now())
          .inSeconds;

      return {
        'level': character['level'],
        'xp': character['xp'],
        'color': character['color'],
        'petChances': raise['pet'], // pet은 자동 충전 없음 (청소로만 획득)
        'feedChances': regen['feed'], // 계산된 최신 feed 기회 수
        'secondsUntilNextFeed': secondsUntilNextFeed > 0
            ? secondsUntilNextFeed
            : 0,
      };
    } catch (e) {
      throw Exception('캐릭터 상태 조회 실패: $e');
    }
  }

  // ==========================================
  // 2. XP 직접 추가 (기회 시스템을 거치지 않는 즉시 보상용)
  // ==========================================
  // Flogging의 걸음수 기반 보상처럼, "기회를 모았다가 나중에 쓰는" 방식이 아니라
  // 즉시 XP를 지급해야 하는 경우에 사용합니다.
  //
  // Transaction을 쓰는 이유:
  //   Hotspot 청소완료(기회 지급)와 거의 동시에 Flogging 종료(즉시 XP)처럼
  //   여러 요청이 겹칠 수 있습니다. Transaction 없이 단순히 읽고-계산하고-쓰면,
  //   나중에 쓴 요청이 먼저 쓴 XP를 덮어써서 사라지는 버그가 생깁니다.
  Future<Map<String, dynamic>> addXp(String uid, int amount) async {
    if (amount <= 0) {
      throw Exception('추가할 XP는 0보다 커야 합니다');
    }

    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final userRef = _firestore.collection('users').doc(uid);
        final snapshot = await transaction.get(userRef);

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

        return {
          'newLevel': calc['level'],
          'newXp': calc['xp'],
          'leveledUp': calc['levelUpCount']! > 0,
          'levelUpCount': calc['levelUpCount'],
        };
      });

      print(
        '✓ XP 추가 완료: +$amount '
        '(레벨업: ${result['levelUpCount']}회, 현재 Lv.${result['newLevel']})',
      );

      return result;
    } catch (e) {
      throw Exception('XP 추가 실패: $e');
    }
  }

  // ==========================================
  // 3. Hotspot 청소 완료 등 "보상"으로 기회를 지급
  // ==========================================
  // XP를 직접 주지 않고, 나중에 사용자가 실제로 상호작용(먹이주기/쓰다듬기)을
  // "소모"할 때 비로소 XP가 들어가는 구조입니다.
  Future<int> grantOpportunity(
    String uid, {
    required String type, // 'feed' 또는 'pet'
    int amount = 1,
  }) async {
    if (type != 'feed' && type != 'pet') {
      throw Exception('type은 feed 또는 pet이어야 합니다');
    }
    if (amount <= 0) {
      throw Exception('지급할 기회는 0보다 커야 합니다');
    }

    try {
      final userRef = _firestore.collection('users').doc(uid);

      // 단순 증가이므로 FieldValue.increment로 원자적(atomic) 처리
      // (동시에 여러 hotspot을 청소해도 값이 씹히지 않음)
      await userRef.update({
        'character.raise.$type': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 상호작용 기회 지급: $type +$amount');
      return amount;
    } catch (e) {
      throw Exception('기회 지급 실패: $e');
    }
  }

  // ==========================================
  // 4. 캐릭터 색상 변경
  // ==========================================
  Future<void> updateCharacterColor(String uid, String color) async {
    try {
      if (!color.startsWith('#') || color.length != 7) {
        throw Exception('올바른 HEX 색상을 입력해주세요 (예: #FF5733)');
      }

      await _firestore.collection('users').doc(uid).update({
        'character.color': color,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 캐릭터 색상 변경: $color');
    } catch (e) {
      throw Exception('색상 변경 실패: $e');
    }
  }

  // ==========================================
  // 5. 먹이주기 (feed 기회 1개 소모 → XP 획득)
  // ==========================================
  Future<Map<String, dynamic>> feedCharacter(String uid) async {
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final userRef = _firestore.collection('users').doc(uid);
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) {
          throw Exception('사용자를 찾을 수 없습니다');
        }

        final character = snapshot.data()!['character'] as Map<String, dynamic>;
        final raise = character['raise'] as Map<String, dynamic>;

        // 먼저 자동 충전분을 반영해서 "실제로 지금 몇 개 있는지" 계산
        final lastRegenTimestamp = raise['lastFeedRegenAt'] as Timestamp?;
        final regen = _applyFeedRegen(
          currentFeed: raise['feed'] as int,
          lastRegenAt: lastRegenTimestamp?.toDate(),
        );

        final availableFeed = regen['feed'] as int;

        if (availableFeed <= 0) {
          final nextRegenAt = (regen['lastRegenAt'] as DateTime).add(
            _feedRegenInterval,
          );
          final remaining = nextRegenAt.difference(DateTime.now());
          throw Exception('먹이 기회가 없습니다. ${remaining.inMinutes}분 후 다시 충전됩니다');
        }

        // 기회 1개 소모 + XP 계산
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

        return {
          'remainingFeedChances': availableFeed - 1,
          'xpGained': _xpPerFeed,
          'newLevel': calc['level'],
          'newXp': calc['xp'],
          'leveledUp': calc['levelUpCount']! > 0,
        };
      });

      print(
        '✓ 먹이주기 완료: 남은 기회=${result['remainingFeedChances']}, '
        '+$_xpPerFeed XP (Lv.${result['newLevel']})',
      );

      return result;
    } catch (e) {
      // 기회 부족 메시지는 그대로 전달 (이중으로 감싸지 않음)
      if (e.toString().contains('다시 충전됩니다')) {
        rethrow;
      }
      throw Exception('먹이주기 실패: $e');
    }
  }

  // ==========================================
  // 6. 쓰다듬기 (pet 기회 1개 소모 → XP 획득)
  // ==========================================
  // pet은 자동 충전이 없고, Hotspot 청소 등 "보상"으로만 얻습니다.
  Future<Map<String, dynamic>> petCharacter(String uid) async {
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final userRef = _firestore.collection('users').doc(uid);
        final snapshot = await transaction.get(userRef);

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

        return {
          'remainingPetChances': availablePet - 1,
          'xpGained': _xpPerPet,
          'newLevel': calc['level'],
          'newXp': calc['xp'],
          'leveledUp': calc['levelUpCount']! > 0,
        };
      });

      print(
        '✓ 쓰다듬기 완료: 남은 기회=${result['remainingPetChances']}, '
        '+$_xpPerPet XP (Lv.${result['newLevel']})',
      );

      return result;
    } catch (e) {
      if (e.toString().contains('기회가 없습니다')) {
        rethrow;
      }
      throw Exception('쓰다듬기 실패: $e');
    }
  }
}
