import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 정보 모델
class UserModel {
  final String uid;
  final String displayName;
  final String weeklyGoal; // "beginner", "intermediate", "advanced"
  final CharacterModel character;
  final String? email;
  final String? reservedHotspotId;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.weeklyGoal,
    required this.character,
    this.email,
    this.reservedHotspotId,
    this.createdAt,
  });

  /// Firestore Map → UserModel 변환
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? '',
      weeklyGoal: data['weeklyGoal'] ?? 'beginner',
      character: CharacterModel.fromMap(
        Map<String, dynamic>.from(data['character'] ?? {}),
      ),
      email: data['email'],
      reservedHotspotId: data['reservedHotspotId'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// UserModel → Firestore Map 변환
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'weeklyGoal': weeklyGoal,
      'character': character.toMap(),
      'email': email,
      'reservedHotspotId': reservedHotspotId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// 사용자 정보 복사 (일부 필드만 업데이트)
  UserModel copyWith({
    String? uid,
    String? displayName,
    String? weeklyGoal,
    CharacterModel? character,
    String? email,
    String? reservedHotspotId,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      character: character ?? this.character,
      email: email ?? this.email,
      reservedHotspotId: reservedHotspotId ?? this.reservedHotspotId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel('
        'uid: $uid, '
        'displayName: $displayName, '
        'weeklyGoal: $weeklyGoal, '
        'level: ${character.level}, '
        'xp: ${character.xp}'
        ')';
  }
}

/// 게임 캐릭터 정보 모델
class CharacterModel {
  final int xp; // 경험치
  final int level; // 레벨
  final String color; // 캐릭터 색상 (hex: #FF5733)
  final RaiseModel raise; // 캐릭터 상태

  CharacterModel({
    required this.xp,
    required this.level,
    required this.color,
    required this.raise,
  });

  /// Firestore Map → CharacterModel 변환
  factory CharacterModel.fromMap(Map<String, dynamic> data) {
    return CharacterModel(
      xp: data['xp'] ?? 0,
      level: data['level'] ?? 1,
      color: data['color'] ?? '#FF5733',
      raise: RaiseModel.fromMap(Map<String, dynamic>.from(data['raise'] ?? {})),
    );
  }

  /// CharacterModel → Firestore Map 변환
  Map<String, dynamic> toMap() {
    return {'xp': xp, 'level': level, 'color': color, 'raise': raise.toMap()};
  }

  /// 캐릭터 정보 복사
  CharacterModel copyWith({
    int? xp,
    int? level,
    String? color,
    RaiseModel? raise,
  }) {
    return CharacterModel(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      color: color ?? this.color,
      raise: raise ?? this.raise,
    );
  }

  @override
  String toString() {
    return 'CharacterModel('
        'level: $level, '
        'xp: $xp, '
        'color: $color'
        ')';
  }
}

/// 캐릭터 상태 모델 (펫 먹이주기, 터치 등)
class RaiseModel {
  final int pet; // 보유한 펫 경험치 기회
  final int feed; // 보유한 먹이주기 기회

  RaiseModel({required this.pet, required this.feed});

  /// Firestore Map → RaiseModel 변환
  factory RaiseModel.fromMap(Map<String, dynamic> data) {
    return RaiseModel(pet: data['pet'] ?? 0, feed: data['feed'] ?? 0);
  }

  /// RaiseModel → Firestore Map 변환
  Map<String, dynamic> toMap() {
    return {'pet': pet, 'feed': feed};
  }

  /// 상태 정보 복사
  RaiseModel copyWith({int? pet, int? feed}) {
    return RaiseModel(pet: pet ?? this.pet, feed: feed ?? this.feed);
  }

  @override
  String toString() {
    return 'RaiseModel('
        'pet: $pet, '
        'feed: $feed'
        ')';
  }
}
