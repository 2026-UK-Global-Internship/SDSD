import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _myUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('로그인이 필요합니다');
    }
    return uid;
  }

  // ==========================================
  // 1. 친구 요청 보내기
  // ==========================================
  // 설계 노트:
  //   Security Rules상 user1Id는 반드시 "요청을 보낸 사람(나)"이어야 합니다.
  //   그래서 문서 ID를 알파벳순으로 정렬하지 않고, 자동 생성 ID를 씁니다.
  //   대신 "이미 어느 방향으로든 관계가 있는지"를 코드에서 먼저 확인합니다.
  Future<void> sendFriendRequest(String targetUid) async {
    try {
      final myUid = _myUid;

      if (targetUid == myUid) {
        throw Exception('자기 자신에게는 친구 요청을 보낼 수 없습니다');
      }

      // 이미 관계(어느 방향이든, pending이든 accepted든)가 있는지 확인
      final existing = await _findFriendshipDoc(myUid, targetUid);
      if (existing != null) {
        final status = existing.data()!['status'];
        if (status == 'accepted') {
          throw Exception('이미 친구입니다');
        } else {
          throw Exception('이미 친구 요청이 진행 중입니다');
        }
      }

      await _firestore.collection('friendships').add({
        'user1Id': myUid, // 요청을 보낸 사람 (Security Rules 요구사항)
        'user2Id': targetUid, // 요청을 받은 사람
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 친구 요청 전송 성공: $myUid → $targetUid');
    } catch (e) {
      throw Exception('친구 요청 실패: $e');
    }
  }

  // ==========================================
  // 내부 헬퍼: 두 사용자 사이의 관계 문서를 양방향으로 검색
  // ==========================================
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findFriendshipDoc(
    String uidA,
    String uidB,
  ) async {
    // 방향 1: A가 B에게 보낸 경우
    final forward = await _firestore
        .collection('friendships')
        .where('user1Id', isEqualTo: uidA)
        .where('user2Id', isEqualTo: uidB)
        .limit(1)
        .get();
    if (forward.docs.isNotEmpty) return forward.docs.first;

    // 방향 2: B가 A에게 보낸 경우
    final backward = await _firestore
        .collection('friendships')
        .where('user1Id', isEqualTo: uidB)
        .where('user2Id', isEqualTo: uidA)
        .limit(1)
        .get();
    if (backward.docs.isNotEmpty) return backward.docs.first;

    return null;
  }

  // ==========================================
  // 2. 친구 요청 수락
  // ==========================================
  // Security Rules 요구사항: auth.uid == user2Id(받은 사람) && 기존 status == "pending"
  Future<void> acceptFriendRequest(String friendshipId) async {
    try {
      final myUid = _myUid;

      final doc = await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .get();
      if (!doc.exists) {
        throw Exception('존재하지 않는 요청입니다');
      }

      final data = doc.data()!;
      if (data['user2Id'] != myUid) {
        throw Exception('본인에게 온 요청만 수락할 수 있습니다');
      }
      if (data['status'] != 'pending') {
        throw Exception('이미 처리된 요청입니다');
      }

      await _firestore.collection('friendships').doc(friendshipId).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 친구 요청 수락: $friendshipId');
    } catch (e) {
      throw Exception('친구 요청 수락 실패: $e');
    }
  }

  // ==========================================
  // 3. 친구 관계 삭제 (거절 / 요청 취소 / 친구 끊기 — 모두 동일)
  // ==========================================
  // Security Rules상 user1Id, user2Id 둘 다 삭제 권한이 있어서
  // "거절"(받은 사람이 삭제) / "취소"(보낸 사람이 삭제) / "절교"(둘 다 가능)를
  // 하나의 함수로 처리할 수 있습니다.
  Future<void> deleteFriendship(String friendshipId) async {
    try {
      final myUid = _myUid;

      final doc = await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .get();
      if (!doc.exists) {
        throw Exception('존재하지 않는 관계입니다');
      }

      final data = doc.data()!;
      if (data['user1Id'] != myUid && data['user2Id'] != myUid) {
        throw Exception('본인과 관련된 관계만 삭제할 수 있습니다');
      }

      await _firestore.collection('friendships').doc(friendshipId).delete();
      print('✓ 친구 관계 삭제: $friendshipId');
    } catch (e) {
      throw Exception('친구 관계 삭제 실패: $e');
    }
  }

  // ==========================================
  // 4. 내 친구 목록 (accepted 상태만)
  // ==========================================
  // user1Id 기준, user2Id 기준 두 번 조회해서 합칩니다.
  // (Firestore는 서로 다른 필드에 대한 OR 조건을 한 번의 쿼리로 못 하기 때문)
  Future<List<Map<String, dynamic>>> getMyFriends() async {
    try {
      final myUid = _myUid;

      final asUser1 = await _firestore
          .collection('friendships')
          .where('user1Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final asUser2 = await _firestore
          .collection('friendships')
          .where('user2Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final results = <Map<String, dynamic>>[];

      for (final doc in asUser1.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        data['friendUid'] = data['user2Id']; // 상대방 uid를 바로 알 수 있게 추가
        results.add(data);
      }

      for (final doc in asUser2.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        data['friendUid'] = data['user1Id'];
        results.add(data);
      }

      return results;
    } catch (e) {
      throw Exception('친구 목록 조회 실패: $e');
    }
  }

  // ==========================================
  // 5. 나에게 온 대기중인 요청 목록
  // ==========================================
  // ⚠️ 이 쿼리를 쓰려면 Firestore에 (user2Id Asc, status Asc) Composite Index가
  //    새로 필요합니다. 지난번에 만든 인덱스는 (user1Id, status)라 이 쿼리에는 못 씁니다.
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    try {
      final myUid = _myUid;

      final snapshot = await _firestore
          .collection('friendships')
          .where('user2Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['fromUid'] = data['user1Id']; // 요청 보낸 사람
        return data;
      }).toList();
    } catch (e) {
      throw Exception('받은 요청 조회 실패: $e');
    }
  }

  // ==========================================
  // 6. 내가 보낸 대기중인 요청 목록
  // ==========================================
  // 기존에 만든 (user1Id Asc, status Asc) 인덱스를 그대로 사용 가능
  Future<List<Map<String, dynamic>>> getOutgoingRequests() async {
    try {
      final myUid = _myUid;

      final snapshot = await _firestore
          .collection('friendships')
          .where('user1Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['toUid'] = data['user2Id']; // 요청 받은 사람
        return data;
      }).toList();
    } catch (e) {
      throw Exception('보낸 요청 조회 실패: $e');
    }
  }

  // ==========================================
  // 7. 특정 사용자와 나의 관계 상태 확인 (버튼 UI용)
  // ==========================================
  // 반환값: 'none' | 'pending_outgoing' | 'pending_incoming' | 'accepted' | 'self'
  Future<Map<String, dynamic>> getFriendshipStatus(String targetUid) async {
    try {
      final myUid = _myUid;

      if (targetUid == myUid) {
        return {'status': 'self', 'friendshipId': null};
      }

      final doc = await _findFriendshipDoc(myUid, targetUid);
      if (doc == null) {
        return {'status': 'none', 'friendshipId': null};
      }

      final data = doc.data()!;
      if (data['status'] == 'accepted') {
        return {'status': 'accepted', 'friendshipId': doc.id};
      }

      // pending인데, 내가 보낸 건지 상대가 보낸 건지 구분
      if (data['user1Id'] == myUid) {
        return {'status': 'pending_outgoing', 'friendshipId': doc.id};
      } else {
        return {'status': 'pending_incoming', 'friendshipId': doc.id};
      }
    } catch (e) {
      throw Exception('관계 상태 조회 실패: $e');
    }
  }

  // ==========================================
  // 8. 닉네임으로 사용자 검색 (친구 추가용, 앞부분 일치·대소문자 무시)
  // ==========================================
  // 예: "test" 검색 → "TestUser", "test123" 등을 찾음 (대소문자 무시)
  //     "estUser"처럼 중간부터 검색은 안 됨 (Firestore의 근본적인 제약)
  //
  // ⚠️ 이 함수를 쓰려면 users 컬렉션 문서에 'displayNameLower' 필드가
  //    있어야 합니다. auth_service.dart의 회원가입/이름변경 시점에
  //    displayName.toLowerCase()를 함께 저장하도록 되어 있는지 확인해주세요.
  Future<List<Map<String, dynamic>>> searchUsersByName(
    String query, {
    int limit = 20,
  }) async {
    try {
      final trimmedQuery = query.trim();

      if (trimmedQuery.isEmpty) {
        throw Exception('검색어를 입력해주세요');
      }
      if (trimmedQuery.length < 2) {
        throw Exception('검색어는 2글자 이상 입력해주세요');
      }

      final lowerQuery = trimmedQuery.toLowerCase();
      final myUid = _auth.currentUser?.uid;

      // '\uf8ff'는 유니코드에서 거의 가장 마지막 순서의 특수 문자입니다.
      // [lowerQuery, lowerQuery + '\uf8ff'] 범위 검색은
      // "lowerQuery로 시작하는 모든 문자열"과 정확히 일치합니다.
      final snapshot = await _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: lowerQuery)
          .where('displayNameLower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(limit)
          .get();

      final results = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        if (doc.id == myUid) continue; // 검색 결과에 나 자신 제외

        final data = doc.data();
        results.add({
          'uid': doc.id,
          'displayName': data['displayName'],
          'level': data['character']?['level'] ?? 1,
        });
      }

      return results;
    } catch (e) {
      throw Exception('사용자 검색 실패: $e');
    }
  }
}
