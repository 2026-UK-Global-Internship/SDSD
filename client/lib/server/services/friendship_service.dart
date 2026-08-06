//friendship_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendshipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _log(String msg) => print('[FriendshipService] $msg');

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
    final sw = Stopwatch()..start();
    _log('🔵 sendFriendRequest 시작 (targetUid=$targetUid)');
    try {
      final myUid = _myUid;

      if (targetUid == myUid) {
        throw Exception('자기 자신에게는 친구 요청을 보낼 수 없습니다');
      }

      final existing = await _findFriendshipDoc(myUid, targetUid);
      _log(
        '  → 기존 관계 확인 완료: ${existing?.data()['status'] ?? '없음'} (${sw.elapsedMilliseconds}ms)',
      );
      if (existing != null) {
        final status = existing.data()!['status'];
        if (status == 'accepted') {
          throw Exception('이미 친구입니다');
        } else {
          throw Exception('이미 친구 요청이 진행 중입니다');
        }
      }

      final docRef = await _firestore.collection('friendships').add({
        'user1Id': myUid,
        'user2Id': targetUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log(
        '✅ sendFriendRequest 성공: ${docRef.id} ($myUid → $targetUid) (총 ${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      _log('❌ sendFriendRequest 실패: $e (${sw.elapsedMilliseconds}ms)');
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
    final sw = Stopwatch()..start();
    _log('🔵 acceptFriendRequest 시작 (id=$friendshipId)');
    try {
      final myUid = _myUid;

      final doc = await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .get();
      _log('  → 문서 조회 완료: exists=${doc.exists} (${sw.elapsedMilliseconds}ms)');
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

      _log(
        '✅ acceptFriendRequest 성공: $friendshipId (총 ${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      _log('❌ acceptFriendRequest 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('친구 요청 수락 실패: $e');
    }
  }

  // ==========================================
  // 3. 친구 관계 삭제
  // ==========================================
  Future<void> deleteFriendship(String friendshipId) async {
    final sw = Stopwatch()..start();
    _log('🔵 deleteFriendship 시작 (id=$friendshipId)');
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
      _log(
        '✅ deleteFriendship 성공: $friendshipId (총 ${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      _log('❌ deleteFriendship 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('친구 관계 삭제 실패: $e');
    }
  }

  // ==========================================
  // 4-1. 실시간 감지용 스트림 (화면이 자동으로 새로고침되도록)
  // ==========================================
  // .get()은 "그 순간 한 번만" 조회하지만, .snapshots()는 Firestore가
  // 변경될 때마다 계속 새 데이터를 흘려보내줍니다. 화면에서 이 스트림을
  // 구독해두면, 다른 기기에서 요청을 보내거나 내가 수락/거절해도
  // 화면을 나갔다 올 필요 없이 즉시 반영됩니다.
  //
  // 3개로 나눈 이유: Firestore는 "user1Id==나 OR user2Id==나" 같은
  // OR 조건을 한 쿼리로 못 만들어서, 방향별로 따로 감시해야 합니다.
  Stream<List<Map<String, dynamic>>> watchIncomingRequests() {
    final myUid = _myUid;
    return _firestore
        .collection('friendships')
        .where('user2Id', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['fromUid'] = data['user1Id'];
            return data;
          }).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> watchFriendsAsUser1() {
    final myUid = _myUid;
    return _firestore
        .collection('friendships')
        .where('user1Id', isEqualTo: myUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['friendUid'] = data['user2Id'];
            return data;
          }).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> watchFriendsAsUser2() {
    final myUid = _myUid;
    return _firestore
        .collection('friendships')
        .where('user2Id', isEqualTo: myUid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['friendUid'] = data['user1Id'];
            return data;
          }).toList(),
        );
  }

  // ==========================================
  // 4. 내 친구 목록 (accepted 상태만)
  // ==========================================
  Future<List<Map<String, dynamic>>> getMyFriends() async {
    final sw = Stopwatch()..start();
    _log('🔵 getMyFriends 시작');
    try {
      final myUid = _myUid;
      _log('  → myUid=$myUid');

      final asUser1 = await _firestore
          .collection('friendships')
          .where('user1Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .get();
      _log(
        '  → user1Id 기준 조회: ${asUser1.docs.length}건 (${sw.elapsedMilliseconds}ms)',
      );

      final asUser2 = await _firestore
          .collection('friendships')
          .where('user2Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .get();
      _log(
        '  → user2Id 기준 조회: ${asUser2.docs.length}건 (${sw.elapsedMilliseconds}ms)',
      );

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

      _log(
        '✅ getMyFriends 성공: 총 ${results.length}명 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return results;
    } catch (e) {
      _log('❌ getMyFriends 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('친구 목록 조회 실패: $e');
    }
  }

  // ==========================================
  // 5. 나에게 온 대기중인 요청 목록
  // ==========================================
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final sw = Stopwatch()..start();
    _log('🔵 getIncomingRequests 시작');
    try {
      final myUid = _myUid;
      _log('  → myUid=$myUid');

      final snapshot = await _firestore
          .collection('friendships')
          .where('user2Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .get();
      _log('  → 쿼리 완료: ${snapshot.docs.length}건 (${sw.elapsedMilliseconds}ms)');
      for (final doc in snapshot.docs) {
        _log('    - id=${doc.id}, data=${doc.data()}');
      }

      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['fromUid'] = data['user1Id'];
        return data;
      }).toList();

      _log(
        '✅ getIncomingRequests 성공: ${result.length}건 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _log('❌ getIncomingRequests 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('받은 요청 조회 실패: $e');
    }
  }

  // ==========================================
  // 6. 내가 보낸 대기중인 요청 목록
  // ==========================================
  Future<List<Map<String, dynamic>>> getOutgoingRequests() async {
    final sw = Stopwatch()..start();
    _log('🔵 getOutgoingRequests 시작');
    try {
      final myUid = _myUid;

      final snapshot = await _firestore
          .collection('friendships')
          .where('user1Id', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .get();
      _log('  → 쿼리 완료: ${snapshot.docs.length}건 (${sw.elapsedMilliseconds}ms)');

      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['toUid'] = data['user2Id'];
        return data;
      }).toList();

      _log(
        '✅ getOutgoingRequests 성공: ${result.length}건 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _log('❌ getOutgoingRequests 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('보낸 요청 조회 실패: $e');
    }
  }

  // ==========================================
  // 7. 특정 사용자와 나의 관계 상태 확인
  // ==========================================
  Future<Map<String, dynamic>> getFriendshipStatus(String targetUid) async {
    final sw = Stopwatch()..start();
    _log('🔵 getFriendshipStatus 시작 (targetUid=$targetUid)');
    try {
      final myUid = _myUid;

      if (targetUid == myUid) {
        return {'status': 'self', 'friendshipId': null};
      }

      final doc = await _findFriendshipDoc(myUid, targetUid);
      if (doc == null) {
        _log('✅ getFriendshipStatus 성공: none (${sw.elapsedMilliseconds}ms)');
        return {'status': 'none', 'friendshipId': null};
      }

      final data = doc.data()!;
      if (data['status'] == 'accepted') {
        _log(
          '✅ getFriendshipStatus 성공: accepted (${sw.elapsedMilliseconds}ms)',
        );
        return {'status': 'accepted', 'friendshipId': doc.id};
      }

      if (data['user1Id'] == myUid) {
        _log(
          '✅ getFriendshipStatus 성공: pending_outgoing (${sw.elapsedMilliseconds}ms)',
        );
        return {'status': 'pending_outgoing', 'friendshipId': doc.id};
      } else {
        _log(
          '✅ getFriendshipStatus 성공: pending_incoming (${sw.elapsedMilliseconds}ms)',
        );
        return {'status': 'pending_incoming', 'friendshipId': doc.id};
      }
    } catch (e) {
      _log('❌ getFriendshipStatus 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('관계 상태 조회 실패: $e');
    }
  }

  // ==========================================
  // 8. 닉네임으로 사용자 검색
  // ==========================================
  Future<List<Map<String, dynamic>>> searchUsersByName(
    String query, {
    int limit = 20,
  }) async {
    final sw = Stopwatch()..start();
    _log('🔵 searchUsersByName 시작 (query=$query)');
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
      _log('  → 쿼리 완료: ${snapshot.docs.length}건 (${sw.elapsedMilliseconds}ms)');

      final results = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        if (doc.id == myUid) continue;

        final data = doc.data();
        results.add({
          'uid': doc.id,
          'displayName': data['displayName'],
          'level': data['character']?['level'] ?? 1,
          'characterColor': data['character']?['color'] ?? '#FF5733',
        });
      }

      _log(
        '✅ searchUsersByName 성공: ${results.length}건 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return results;
    } catch (e) {
      _log('❌ searchUsersByName 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('사용자 검색 실패: $e');
    }
  }

  // ==========================================
  // 9. 최근 검색 기록
  // ==========================================
  Future<void> saveRecentSearch({
    required String targetUid,
    required String displayName,
    required String characterColor,
  }) async {
    final sw = Stopwatch()..start();
    _log('🔵 saveRecentSearch 시작 (targetUid=$targetUid)');
    try {
      final myUid = _myUid;

      await _firestore
          .collection('users')
          .doc(myUid)
          .collection('recentSearches')
          .doc(targetUid)
          .set({
            'targetUid': targetUid,
            'displayName': displayName,
            'characterColor': characterColor,
            'searchedAt': FieldValue.serverTimestamp(),
          });

      _log('✅ saveRecentSearch 성공: $targetUid (총 ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      // 최근 검색 저장 실패는 비치명적이지만, 진단을 위해 로그는 명확히 남김
      _log('❌ saveRecentSearch 실패 (비치명적): $e (${sw.elapsedMilliseconds}ms)');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentSearches({int limit = 10}) async {
    final sw = Stopwatch()..start();
    _log('🔵 getRecentSearches 시작');
    try {
      final myUid = _myUid;

      final snapshot = await _firestore
          .collection('users')
          .doc(myUid)
          .collection('recentSearches')
          .orderBy('searchedAt', descending: true)
          .limit(limit)
          .get();
      _log('  → 쿼리 완료: ${snapshot.docs.length}건 (${sw.elapsedMilliseconds}ms)');

      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _log(
        '✅ getRecentSearches 성공: ${result.length}건 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _log('❌ getRecentSearches 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('최근 검색 조회 실패: $e');
    }
  }

  Future<void> removeRecentSearch(String targetUid) async {
    final sw = Stopwatch()..start();
    _log('🔵 removeRecentSearch 시작 (targetUid=$targetUid)');
    try {
      final myUid = _myUid;

      await _firestore
          .collection('users')
          .doc(myUid)
          .collection('recentSearches')
          .doc(targetUid)
          .delete();

      _log(
        '✅ removeRecentSearch 성공: $targetUid (총 ${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      _log('❌ removeRecentSearch 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('최근 검색 삭제 실패: $e');
    }
  }
}
