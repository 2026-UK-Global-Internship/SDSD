//flogging_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/character_service.dart';
import 'photo_upload_service.dart';

class FloggingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase; // ★ 추가
  late CharacterService _characterService;
  late PhotoUploadService _photoUploadService; // ★ 변경: late 사용

  // ★ 생성자 추가
  FloggingService(this._supabase) {
    _characterService = CharacterService();
    _photoUploadService = PhotoUploadService(_supabase); // ★ Supabase 전달
  }

  // 조깅 XP 계산 기준 (가정값): 100걸음당 1 XP
  int _calculateXpFromSteps(int steps) => steps ~/ 100;

  // ==========================================
  // 1. 조깅 기록 저장 (조깅이 끝난 시점에 한 번에 호출)
  // ==========================================
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
        'cleanup': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✓ 조깅 기록 저장 성공: ${docRef.id}');

      // 걸음수 기반으로 XP 지급
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
  Future<void> recordCleanup({
    required String floggingId,
    required String hotspotId,
    Uint8List? photoBytes,
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

      String photoUrl = '';
      if (photoBytes != null) {
        try {
          photoUrl = await _photoUploadService.uploadCleanupPhoto(
            floggingId: floggingId,
            fileBytes: photoBytes,
          );
        } catch (e) {
          print('⚠️ 사진 업로드 실패, 사진 없이 연결을 계속합니다: $e');
        }
      }

      await _firestore.collection('flogging').doc(floggingId).update({
        'cleanup': {
          'hotspotId': hotspotId,
          'photoUrl': photoUrl,
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
