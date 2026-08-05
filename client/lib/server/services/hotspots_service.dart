import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'character_service.dart';

class HotspotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CharacterService _characterService = CharacterService();

  static const String _photoBucket = 'photos';

  // 인원 규모로 선택 가능한 값 (밸런스/기획 조정 시 이 목록만 바꾸면 됨)
  static const List<String> _validCrewSizes = ['solo', 'duo', 'squad', 'more'];

  // ==========================================
  // 사진 업로드 (Supabase Storage) - 이 파일 안에서만 쓰는 내부 함수
  // ==========================================
  // 실패해도 예외를 던지지 않고 빈 문자열을 반환합니다.
  // → 사진 업로드 문제 때문에 신고 자체가 막히지 않도록 하기 위함입니다.
  Future<String> _uploadPhoto(String path, Uint8List bytes) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.storage
          .from(_photoBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      return supabase.storage.from(_photoBucket).getPublicUrl(path);
    } catch (e) {
      print('⚠️ 사진 업로드 실패, 사진 없이 계속 진행합니다: $e');
      return '';
    }
  }

  // ==========================================
  // 1. Hotspot 신고 (쓰레기 위치 등록)
  // ==========================================
  // Security Rules 요구사항:
  //   - reporterId == 현재 로그인한 사용자 uid
  //   - status는 반드시 "open"으로 시작
  //   - location은 GeoPoint 타입이어야 함
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

      // 문서 ID를 미리 확보 (사진 업로드 경로에 사용하기 위함)
      final docRef = _firestore.collection('hotspots').doc();

      String photoUrl = '';
      if (photoBytes != null) {
        photoUrl = await _uploadPhoto(
          'hotspots/${docRef.id}/photo.jpg',
          photoBytes,
        );
      }

      await docRef.set({
        'reporterId': currentUser.uid,
        'photoUrl': photoUrl,
        'trashType': trashType,
        'locationDescription': trimmedDescription,
        'crewSize': crewSize,
        'location': GeoPoint(latitude, longitude),
        'status': 'open', // Security Rules가 요구하는 초기값
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
  // 8. Hotspot 삭제 (신고자만, open 상태일 때만 가능)
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
