//hotspots_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'character_service.dart';
import 'photo_upload_service.dart';

class HotspotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase; // ★ 추가
  late CharacterService _characterService;
  late PhotoUploadService _photoUploadService; // ★ 변경: late 사용

  static const List<String> _validCrewSizes = ['solo', 'duo', 'squad', 'more'];

  // ★ 생성자 추가
  HotspotService(this._supabase) {
    _characterService = CharacterService();
    _photoUploadService = PhotoUploadService(_supabase); // ★ Supabase 전달
  }

  // ==========================================
  // 1. Hotspot 신고 (쓰레기 위치 등록)
  // ==========================================
  Future<String> reportHotspot({
    required double latitude,
    required double longitude,
    required String trashType,
    required String locationDescription,
    required String crewSize,
    Uint8List? photoBytes,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      if (trashType.isEmpty) {
        throw Exception('쓰레기 종류를 입력해주세요');
      }

      final trimmedDescription = locationDescription.trim();
      if (trimmedDescription.isEmpty) {
        throw Exception('장소 설명을 입력해주세요');
      }
      if (trimmedDescription.length > 200) {
        throw Exception('장소 설명은 200자 이하여야 합니다');
      }

      if (!_validCrewSizes.contains(crewSize)) {
        throw Exception('인원 규모는 solo, duo, squad, more 중 하나여야 합니다');
      }

      if (latitude < -90 || latitude > 90) {
        throw Exception('올바른 위도 값이 아닙니다 (-90 ~ 90)');
      }
      if (longitude < -180 || longitude > 180) {
        throw Exception('올바른 경도 값이 아닙니다 (-180 ~ 180)');
      }

      final docRef = _firestore.collection('hotspots').doc();

      String photoUrl = '';
      if (photoBytes != null) {
        try {
          photoUrl = await _photoUploadService.uploadHotspotPhoto(
            hotspotId: docRef.id,
            fileBytes: photoBytes,
          );
        } catch (e) {
          print('⚠️ 사진 업로드 실패, 사진 없이 신고를 계속합니다: $e');
        }
      }

      await docRef.set({
        'reporterId': currentUser.uid,
        'photoUrl': photoUrl,
        'trashType': trashType,
        'locationDescription': trimmedDescription,
        'crewSize': crewSize,
        'location': GeoPoint(latitude, longitude),
        'status': 'open',
        'reservedBy': null,
        'ttl': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✓ Hotspot 신고 성공: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      throw Exception('Hotspot 신고 실패: $e');
    }
  }

  // ==========================================
  // 2. 전체 Hotspot 목록 조회 (최신순)
  // ==========================================
  Future<List<Map<String, dynamic>>> getAllHotspots() async {
    try {
      final snapshot = await _firestore
          .collection('hotspots')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Hotspot 목록 조회 실패: $e');
    }
  }

  // ==========================================
  // 3. "open" 상태인 Hotspot만 조회 (지도 표시용)
  // ==========================================
  Future<List<Map<String, dynamic>>> getOpenHotspots() async {
    try {
      final snapshot = await _firestore
          .collection('hotspots')
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Open Hotspot 조회 실패: $e');
    }
  }

  // ==========================================
  // 3-1. 지도 화면에 표시할 Hotspot 조회 (현재 보이는 영역 기준)
  // ==========================================
  Future<List<Map<String, dynamic>>> getHotspotsForMap({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
    bool onlyOpen = true,
  }) async {
    try {
      if (swLat > neLat) {
        throw Exception('남서쪽 위도가 북동쪽 위도보다 클 수 없습니다');
      }
      if (swLng > neLng) {
        throw Exception('경도 범위가 올바르지 않습니다 (날짜 변경선 근처는 미지원)');
      }

      final allHotspots = onlyOpen
          ? await getOpenHotspots()
          : await getAllHotspots();

      return allHotspots.where((hotspot) {
        final GeoPoint location = hotspot['location'] as GeoPoint;
        return location.latitude >= swLat &&
            location.latitude <= neLat &&
            location.longitude >= swLng &&
            location.longitude <= neLng;
      }).toList();
    } catch (e) {
      throw Exception('지도 영역 Hotspot 조회 실패: $e');
    }
  }

  // ==========================================
  // 4. 특정 Hotspot 상세 조회
  // ==========================================
  Future<Map<String, dynamic>> getHotspotById(String hotspotId) async {
    try {
      final doc = await _firestore.collection('hotspots').doc(hotspotId).get();

      if (!doc.exists) {
        throw Exception('존재하지 않는 Hotspot입니다');
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      throw Exception('Hotspot 조회 실패: $e');
    }
  }

  // ==========================================
  // 5. Hotspot 예약 (open → reserved)
  // ==========================================
  Future<void> reserveHotspot(String hotspotId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final hotspot = await getHotspotById(hotspotId);
      if (hotspot['status'] != 'open') {
        throw Exception('이미 예약되었거나 청소 완료된 위치입니다');
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final existingReservation = userDoc.data()?['reservedHotspotId'];
      if (existingReservation != null) {
        throw Exception('이미 예약 중인 위치가 있습니다. 먼저 청소를 완료하거나 취소해주세요');
      }

      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('hotspots').doc(hotspotId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception('존재하지 않는 Hotspot입니다');
        }

        final currentStatus = snapshot.data()!['status'];
        if (currentStatus != 'open') {
          throw Exception('이미 다른 사람이 예약했습니다');
        }

        transaction.update(docRef, {
          'status': 'reserved',
          'reservedBy': currentUser.uid,
        });

        final userRef = _firestore.collection('users').doc(currentUser.uid);
        transaction.update(userRef, {'reservedHotspotId': hotspotId});
      });

      print('✓ Hotspot 예약 성공: $hotspotId');
    } catch (e) {
      throw Exception('Hotspot 예약 실패: $e');
    }
  }

  // ==========================================
  // 6. 예약 취소 (reserved → open)
  // ==========================================
  Future<void> cancelReservation(String hotspotId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final hotspot = await getHotspotById(hotspotId);

      if (hotspot['status'] != 'reserved') {
        throw Exception('예약된 상태가 아닙니다');
      }

      if (hotspot['reservedBy'] != currentUser.uid) {
        throw Exception('본인이 예약한 Hotspot만 취소할 수 있습니다');
      }

      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('hotspots').doc(hotspotId);

        transaction.update(docRef, {'status': 'open', 'reservedBy': null});

        final userRef = _firestore.collection('users').doc(currentUser.uid);
        transaction.update(userRef, {'reservedHotspotId': null});
      });

      print('✓ 예약 취소 성공: $hotspotId');
    } catch (e) {
      throw Exception('예약 취소 실패: $e');
    }
  }

  // ==========================================
  // 7. 청소 완료 처리 (reserved → cleaned)
  // ==========================================
  Future<Map<String, dynamic>> completeCleaning(String hotspotId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final hotspot = await getHotspotById(hotspotId);

      if (hotspot['status'] != 'reserved') {
        throw Exception('예약된 상태가 아닙니다');
      }

      if (hotspot['reservedBy'] != currentUser.uid) {
        throw Exception('본인이 예약한 Hotspot만 청소 완료 처리할 수 있습니다');
      }

      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('hotspots').doc(hotspotId);

        transaction.update(docRef, {'status': 'cleaned'});

        final userRef = _firestore.collection('users').doc(currentUser.uid);
        transaction.update(userRef, {'reservedHotspotId': null});
      });

      print('✓ 청소 완료 처리 성공: $hotspotId');

      await _characterService.grantOpportunity(
        currentUser.uid,
        type: 'pet',
        amount: 1,
      );

      return {'hotspotId': hotspotId, 'petChanceGranted': 1};
    } catch (e) {
      throw Exception('청소 완료 처리 실패: $e');
    }
  }

  // ==========================================
  // 8. Hotspot 삭제 (신고자만 가능)
  // ==========================================
  Future<void> deleteHotspot(String hotspotId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final hotspot = await getHotspotById(hotspotId);
      if (hotspot['reporterId'] != currentUser.uid) {
        throw Exception('본인이 신고한 Hotspot만 삭제할 수 있습니다');
      }

      if (hotspot['status'] != 'open') {
        throw Exception('이미 예약되었거나 청소 완료된 위치는 삭제할 수 없습니다');
      }

      await _firestore.collection('hotspots').doc(hotspotId).delete();
      print('✓ Hotspot 삭제 성공: $hotspotId');
    } catch (e) {
      throw Exception('Hotspot 삭제 실패: $e');
    }
  }
}
