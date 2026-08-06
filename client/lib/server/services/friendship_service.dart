//friendship_service.dart
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
  Future<void> sendFriendRequest(String targetUid) async {
    try {
      final myUid = _myUid;

      if (targetUid == myUid) {
        throw Exception('자기 자신에게는 친구 요청을 보낼 수 없습니다');
      }

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
        'user1Id': myUid,
        'user2Id': targetUid,
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
    final forward = await _firestore
        .collection('friendships')
        .where('user1Id', isEqualTo: uidA)
        .where('user2Id', isEqualTo: uidB)
        .limit(1)
        .get();
    if (forward.docs.isNotEmpty) return forward.docs.first;

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
  // 3. 친구 관계 삭제 (거절 / 요청 취소 / 친구 끊기)
  // ==========================================
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
        data['friendUid'] = data['user2Id'];
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
        data['fromUid'] = data['user1Id'];
        return data;
      }).toList();
    } catch (e) {
      throw Exception('받은 요청 조회 실패: $e');
    }
  }

  // ==========================================
  // 6. 내가 보낸 대기중인 요청 목록
  // ==========================================
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
        data['toUid'] = data['user2Id'];
        return data;
      }).toList();
    } catch (e) {
      throw Exception('보낸 요청 조회 실패: $e');
    }
  }

  // ==========================================
  // 7. 특정 사용자와 나의 관계 상태 확인 (버튼 UI용)
  // ==========================================
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
  // 8. 닉네임으로 사용자 검색
  // ==========================================
  // 반환 필드에 characterColor 추가: 검색 결과 화면에서 실제 캐릭터
  // 색상을 아바타에 입히기 위함입니다 (프론트 요청사항).
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

      final snapshot = await _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: lowerQuery)
          .where('displayNameLower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(limit)
          .get();

      final results = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        if (doc.id == myUid) continue;

        final data = doc.data();
        results.add({
          'uid': doc.id,
          'displayName': data['displayName'],
          'level': data['character']?['level'] ?? 1,
          'characterColor': data['character']?['color'] ?? '#FF5733', // ← 추가
        });
      }

      return results;
    } catch (e) {
      throw Exception('사용자 검색 실패: $e');
    }
  }

  // ==========================================
  // 9. 최근 검색 기록 (users/{myUid}/recentSearches 서브컬렉션)
  // ==========================================
  // 검색 시점의 이름/색상을 함께 저장해둬서(비정규화), 최근 검색 목록을
  // 보여줄 때 매번 상대방 프로필을 다시 조회할 필요가 없게 했습니다.
  // (그 사이 상대가 이름/색을 바꿨다면 최근 검색 목록엔 약간 오래된
  //  정보가 보일 수 있지만, "최근 검색"의 용도상 문제되지 않습니다)

  Future<void> saveRecentSearch({
    required String targetUid,
    required String displayName,
    required String characterColor,
  }) async {
    try {
      final myUid = _myUid;

      await _firestore
          .collection('users')
          .doc(myUid)
          .collection('recentSearches')
          .doc(targetUid) // 같은 사람 재검색 시 덮어쓰기 (중복 방지 + 최신순 갱신)
          .set({
            'targetUid': targetUid,
            'displayName': displayName,
            'characterColor': characterColor,
            'searchedAt': FieldValue.serverTimestamp(),
          });

      print('✓ 최근 검색 저장: $targetUid');
    } catch (e) {
      // 최근 검색 저장 실패는 비치명적 (검색/요청 자체는 이미 성공했으므로)
      print('⚠️ 최근 검색 저장 실패: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 10}) async {
    try {
      final myUid = _myUid;

      final snapshot = await _firestore
          .collection('users')
          .doc(myUid)
          .collection('recentSearches')
          .orderBy('searchedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('최근 검색 조회 실패: $e');
    }
  }

  Future<void> removeRecentSearch(String targetUid) async {
    try {
      final myUid = _myUid;

      await _firestore
          .collection('users')
          .doc(myUid)
          .collection('recentSearches')
          .doc(targetUid)
          .delete();

      print('✓ 최근 검색 삭제: $targetUid');
    } catch (e) {
      throw Exception('최근 검색 삭제 실패: $e');
    }
  }
}
