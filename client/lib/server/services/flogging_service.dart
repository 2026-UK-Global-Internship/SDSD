import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'character_service.dart';

class FloggingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CharacterService _characterService = CharacterService();

  // 조깅 XP 계산 기준 (가정값): 100걸음당 1 XP
  int _calculateXpFromSteps(int steps) => steps ~/ 100;

  // ==========================================
  // 1. 조깅 기록 저장 (조깅이 끝난 시점에 한 번에 호출)
  // ==========================================
  // 설계 이유:
  //   startedAt(시작 시각)과 createdAt(저장 시각)이 스키마에 따로 있다는 것은
  //   실시간으로 문서를 계속 update하는 게 아니라,
  //   조깅 종료 후 최종 데이터를 한 번에 저장하는 구조라는 의미입니다.
  //   (앱에서는 조깅 중 steps/calorie/경로를 로컬 변수에 쌓아뒀다가,
  //    "종료" 버튼을 누르면 이 함수를 1번 호출합니다)
  // 반환값 변경 안내: String(floggingId만) → Map<String, dynamic>
  //   floggingId뿐 아니라 XP 지급 결과(레벨업 여부 등)도 함께 반환하기 위함입니다.
  Future<Map<String, dynamic>> saveFloggingRecord({
    required DateTime startedAt,
    required double startLatitude,
    required double startLongitude,
    required int calorie,
    required int steps,
    required String routePolyline,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 입력값 검증
      if (calorie < 0) {
        throw Exception('칼로리는 0 이상이어야 합니다');
      }
      if (steps < 0) {
        throw Exception('걸음수는 0 이상이어야 합니다');
      }
      if (routePolyline.isEmpty) {
        throw Exception('이동 경로 데이터가 없습니다');
      }
      if (startLatitude < -90 || startLatitude > 90) {
        throw Exception('올바른 위도 값이 아닙니다 (-90 ~ 90)');
      }
      if (startLongitude < -180 || startLongitude > 180) {
        throw Exception('올바른 경도 값이 아닙니다 (-180 ~ 180)');
      }

      final docRef = await _firestore.collection('flogging').add({
        'userId': currentUser.uid,
        'startingPoint': GeoPoint(startLatitude, startLongitude),
        'calorie': calorie,
        'steps': steps,
        'routePolyline': routePolyline,
        'startedAt': Timestamp.fromDate(startedAt),
        'cleanup': null, // 청소 안 했으면 null, 나중에 recordCleanup()으로 채움
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✓ 조깅 기록 저장 성공: ${docRef.id}');

      // ★ 연결: 걸음수 기반으로 XP 지급
      final xpToGain = _calculateXpFromSteps(steps);
      Map<String, dynamic>? xpResult;
      if (xpToGain > 0) {
        xpResult = await _characterService.addXp(currentUser.uid, xpToGain);
      }

      return {
        'floggingId': docRef.id,
        'xpGained': xpToGain,
        'newLevel': xpResult?['newLevel'],
        'newXp': xpResult?['newXp'],
        'leveledUp': xpResult?['leveledUp'] ?? false,
      };
    } catch (e) {
      throw Exception('조깅 기록 저장 실패: $e');
    }
  }

  // ==========================================
  // 2. 본인의 조깅 기록 목록 조회 (최신순)
  // ==========================================
  // 미리 만들어둔 Composite Index (userId Asc, startedAt Desc) 사용
  Future<List<Map<String, dynamic>>> getUserFloggingHistory({
    int limit = 20,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final snapshot = await _firestore
          .collection('flogging')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('조깅 기록 조회 실패: $e');
    }
  }

  // ==========================================
  // 3. 특정 조깅 기록 상세 조회
  // ==========================================
  Future<Map<String, dynamic>> getFloggingById(String floggingId) async {
    try {
      final doc = await _firestore.collection('flogging').doc(floggingId).get();

      if (!doc.exists) {
        throw Exception('존재하지 않는 기록입니다');
      }

      final data = doc.data()!;

      // Security Rules상 본인 것만 read 가능하지만,
      // 클라이언트에서도 먼저 확인해 불필요한 오류 노출을 막음
      final currentUser = _auth.currentUser;
      if (currentUser == null || data['userId'] != currentUser.uid) {
        throw Exception('본인의 기록만 조회할 수 있습니다');
      }

      data['id'] = doc.id;
      return data;
    } catch (e) {
      throw Exception('조깅 기록 상세 조회 실패: $e');
    }
  }

  // ==========================================
  // 4. 청소 정보 연결 (조깅 중 hotspot을 청소했을 때)
  // ==========================================
  // 참고: hotspots 컬렉션의 status를 "cleaned"로 바꾸는 것은
  //      HotspotService.completeCleaning()이 담당합니다.
  //      이 함수는 "그 청소가 이 조깅 세션에서 일어났다"는 연결 정보만
  //      flogging 문서에 남기는 역할입니다.
  Future<void> recordCleanup({
    required String floggingId,
    required String hotspotId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 본인 기록인지 먼저 확인
      final flogging = await getFloggingById(floggingId);
      if (flogging['userId'] != currentUser.uid) {
        throw Exception('본인의 조깅 기록에만 청소 정보를 연결할 수 있습니다');
      }

      await _firestore.collection('flogging').doc(floggingId).update({
        'cleanup': {
          'hotspotId': hotspotId,
          'photoUrl': '', // 사진 업로드 기능은 아직 없음 (추후 추가 예정)
          'cleanedAt': FieldValue.serverTimestamp(),
        },
      });

      print('✓ 청소 정보 연결 성공: $floggingId → $hotspotId');
    } catch (e) {
      throw Exception('청소 정보 연결 실패: $e');
    }
  }

  // ==========================================
  // 5. 조깅 기록 삭제
  // ==========================================
  Future<void> deleteFloggingRecord(String floggingId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final flogging = await getFloggingById(floggingId);
      if (flogging['userId'] != currentUser.uid) {
        throw Exception('본인의 조깅 기록만 삭제할 수 있습니다');
      }

      await _firestore.collection('flogging').doc(floggingId).delete();
      print('✓ 조깅 기록 삭제 성공: $floggingId');
    } catch (e) {
      throw Exception('조깅 기록 삭제 실패: $e');
    }
  }
}
