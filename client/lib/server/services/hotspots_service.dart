//hospots_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'character_service.dart';

class HotspotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CharacterService _characterService = CharacterService();

  // Cloudinary 설정 (Unsigned upload preset 방식 — API Secret 없이 클라이언트에서 바로 업로드)
  static const String _cloudinaryCloudName = 'yqwcycty';
  static const String _cloudinaryUploadPreset = 'sdsd_photos';
  static const String _cloudinaryFolder = 'hotspots';

  static const List<String> _validCrewSizes = ['solo', 'duo', 'squad', 'more'];

  void _log(String msg) => print('[HotspotService] $msg');

  // ==========================================
  // 사진 업로드 (Cloudinary, Unsigned upload preset)
  // ==========================================
  // 실패해도 예외를 던지지 않고 빈 문자열을 반환합니다.
  // → 사진 업로드 문제 때문에 신고 자체가 막히지 않도록 하기 위함입니다.
  Future<String> _uploadPhoto(String fileName, Uint8List bytes) async {
    final sw = Stopwatch()..start();
    _log(
      '  🔵 _uploadPhoto 시작 (fileName=$fileName, size=${bytes.length}bytes)',
    );
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..fields['folder'] = _cloudinaryFolder
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );

      _log('    → Cloudinary 요청 전송 중... (${sw.elapsedMilliseconds}ms)');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _log(
        '    → Cloudinary 응답 수신 완료: HTTP ${response.statusCode} (${sw.elapsedMilliseconds}ms)',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Cloudinary 업로드 실패 (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['secure_url'] as String;

      _log('  ✅ _uploadPhoto 성공: $url (${sw.elapsedMilliseconds}ms)');
      return url;
    } catch (e) {
      _log(
        '  ❌ _uploadPhoto 실패 (사진 없이 계속 진행): $e (${sw.elapsedMilliseconds}ms)',
      );
      return '';
    }
  }

  // ==========================================
  // 1. Hotspot 신고
  // ==========================================
  Future<String> reportHotspot({
    required double latitude,
    required double longitude,
    required String trashType,
    required String locationDescription,
    required String crewSize,
    Uint8List? photoBytes,
  }) async {
    final sw = Stopwatch()..start();
    _log(
      '🔵 reportHotspot 시작 (lat=$latitude, lng=$longitude, crewSize=$crewSize)',
    );
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
      _log('  → 입력값 검증 완료 (${sw.elapsedMilliseconds}ms)');

      final docRef = _firestore.collection('hotspots').doc();
      _log('  → 문서 ID 확보 완료: ${docRef.id} (${sw.elapsedMilliseconds}ms)');

      String photoUrl = '';
      if (photoBytes != null) {
        _log('  → 사진 업로드 시작... (${sw.elapsedMilliseconds}ms)');
        photoUrl = await _uploadPhoto('${docRef.id}.jpg', photoBytes);
        _log('  → 사진 업로드 종료 (${sw.elapsedMilliseconds}ms)');
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

      _log('✅ reportHotspot 성공: ${docRef.id} (총 ${sw.elapsedMilliseconds}ms)');
      return docRef.id;
    } catch (e) {
      _log('❌ reportHotspot 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('Hotspot 신고 실패: $e');
    }
  }

  // ==========================================
  // 2. 전체 Hotspot 목록 조회
  // ==========================================
  Future<List<Map<String, dynamic>>> getAllHotspots() async {
    final sw = Stopwatch()..start();
    _log('🔵 getAllHotspots 시작');
    try {
      final snapshot = await _firestore
          .collection('hotspots')
          .orderBy('createdAt', descending: true)
          .get();
      _log(
        '  → Firestore 쿼리 완료: ${snapshot.docs.length}건 (${sw.elapsedMilliseconds}ms)',
      );

      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _log(
        '✅ getAllHotspots 성공: ${result.length}건 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _log('❌ getAllHotspots 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('Hotspot 목록 조회 실패: $e');
    }
  }

  // ==========================================
  // 2-1. 전체 청결도 조회
  // ==========================================
  Future<double> getCleanlinessPercentage() async {
    final sw = Stopwatch()..start();
    _log('🔵 getCleanlinessPercentage 시작');
    try {
      final all = await getAllHotspots();
      _log(
        '  → 전체 hotspot 조회 완료: ${all.length}건 (${sw.elapsedMilliseconds}ms)',
      );

      if (all.isEmpty) {
        _log(
          '✅ getCleanlinessPercentage 성공: hotspot 없음 → 0% (${sw.elapsedMilliseconds}ms)',
        );
        return 0;
      }

      final cleanedCount = all
          .where((hotspot) => hotspot['status'] == 'cleaned')
          .length;

      final percentage = (cleanedCount / all.length) * 100;
      _log(
        '✅ getCleanlinessPercentage 성공: $cleanedCount/${all.length} = $percentage% (총 ${sw.elapsedMilliseconds}ms)',
      );
      return percentage;
    } catch (e) {
      _log('❌ getCleanlinessPercentage 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('청결도 조회 실패: $e');
    }
  }

  // ==========================================
  // 3. "open" 상태인 Hotspot만 조회
  // ==========================================
  Future<List<Map<String, dynamic>>> getOpenHotspots() async {
    final sw = Stopwatch()..start();
    _log('🔵 getOpenHotspots 시작');
    try {
      final snapshot = await _firestore
          .collection('hotspots')
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .get();
      _log(
        '  → Firestore 쿼리 완료: ${snapshot.docs.length}건 (${sw.elapsedMilliseconds}ms)',
      );

      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      _log(
        '✅ getOpenHotspots 성공: ${result.length}건 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _log('❌ getOpenHotspots 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('Open Hotspot 조회 실패: $e');
    }
  }

  // ==========================================
  // 3-1. 지도 화면에 표시할 Hotspot 조회
  // ==========================================
  Future<List<Map<String, dynamic>>> getHotspotsForMap({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
    bool onlyOpen = true,
  }) async {
    final sw = Stopwatch()..start();
    _log('🔵 getHotspotsForMap 시작 (onlyOpen=$onlyOpen)');
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
      _log(
        '  → 기초 목록 조회 완료: ${allHotspots.length}건 (${sw.elapsedMilliseconds}ms)',
      );

      final result = allHotspots.where((hotspot) {
        final GeoPoint location = hotspot['location'] as GeoPoint;
        return location.latitude >= swLat &&
            location.latitude <= neLat &&
            location.longitude >= swLng &&
            location.longitude <= neLng;
      }).toList();

      _log(
        '✅ getHotspotsForMap 성공: ${result.length}건 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _log('❌ getHotspotsForMap 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('지도 영역 Hotspot 조회 실패: $e');
    }
  }

  // ==========================================
  // 4. 특정 Hotspot 상세 조회
  // ==========================================
  Future<Map<String, dynamic>> getHotspotById(String hotspotId) async {
    final sw = Stopwatch()..start();
    _log('🔵 getHotspotById 시작 (id=$hotspotId)');
    try {
      final doc = await _firestore.collection('hotspots').doc(hotspotId).get();
      _log('  → Firestore 문서 조회 완료 (${sw.elapsedMilliseconds}ms)');

      if (!doc.exists) {
        throw Exception('존재하지 않는 Hotspot입니다');
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      _log('✅ getHotspotById 성공 (총 ${sw.elapsedMilliseconds}ms)');
      return data;
    } catch (e) {
      _log('❌ getHotspotById 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('Hotspot 조회 실패: $e');
    }
  }

  // ==========================================
  // 4-1. 내가 이미 예약 중인 hotspot 조회 (있으면 반환, 없으면 null)
  // ==========================================
  // "이미 진행 중인 플로깅이 있는데 새로 시작하려는" 상황을 화면에서
  // 미리 걸러내기 위한 함수입니다. users.reservedHotspotId를 먼저 확인합니다.
  Future<Map<String, dynamic>?> getMyReservedHotspot() async {
    final sw = Stopwatch()..start();
    _log('🔵 getMyReservedHotspot 시작');
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final reservedId = userDoc.data()?['reservedHotspotId'] as String?;
      _log(
        '  → reservedHotspotId 확인: $reservedId (${sw.elapsedMilliseconds}ms)',
      );

      if (reservedId == null) {
        _log('✅ getMyReservedHotspot 성공: 예약 없음 (${sw.elapsedMilliseconds}ms)');
        return null;
      }

      final hotspot = await getHotspotById(reservedId);
      _log(
        '✅ getMyReservedHotspot 성공: 기존 예약 발견 (총 ${sw.elapsedMilliseconds}ms)',
      );
      return hotspot;
    } catch (e) {
      _log('❌ getMyReservedHotspot 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('예약 상태 확인 실패: $e');
    }
  }

  // ==========================================
  // 5. Hotspot 예약
  // ==========================================
  Future<void> reserveHotspot(String hotspotId) async {
    final sw = Stopwatch()..start();
    _log('🔵 reserveHotspot 시작 (id=$hotspotId)');
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final hotspot = await getHotspotById(hotspotId);
      _log('  → 현재 상태 확인: ${hotspot['status']} (${sw.elapsedMilliseconds}ms)');
      if (hotspot['status'] != 'open') {
        throw Exception('이미 예약되었거나 청소 완료된 위치입니다');
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      _log('  → 내 예약 상태 확인 완료 (${sw.elapsedMilliseconds}ms)');
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
          'reservedAt': FieldValue.serverTimestamp(), // ← 추가: 진행 중 화면 복원용
        });

        final userRef = _firestore.collection('users').doc(currentUser.uid);
        transaction.update(userRef, {'reservedHotspotId': hotspotId});
      });
      _log('  → Transaction 완료 (${sw.elapsedMilliseconds}ms)');

      _log('✅ reserveHotspot 성공 (총 ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ reserveHotspot 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('Hotspot 예약 실패: $e');
    }
  }

  // ==========================================
  // 6. 예약 취소
  // ==========================================
  Future<void> cancelReservation(String hotspotId) async {
    final sw = Stopwatch()..start();
    _log('🔵 cancelReservation 시작 (id=$hotspotId)');
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
      _log('  → Transaction 완료 (${sw.elapsedMilliseconds}ms)');

      _log('✅ cancelReservation 성공 (총 ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ cancelReservation 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('예약 취소 실패: $e');
    }
  }

  // ==========================================
  // 7. 청소 완료 처리
  // ==========================================
  Future<Map<String, dynamic>> completeCleaning(String hotspotId) async {
    final sw = Stopwatch()..start();
    _log('🔵 completeCleaning 시작 (id=$hotspotId)');
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      final hotspot = await getHotspotById(hotspotId);
      _log('  → 현재 상태 확인: ${hotspot['status']} (${sw.elapsedMilliseconds}ms)');

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
      _log('  → Transaction 완료 (${sw.elapsedMilliseconds}ms)');

      await _characterService.grantOpportunity(
        currentUser.uid,
        type: 'pet',
        amount: 1,
      );
      _log('  → pet 기회 지급 완료 (${sw.elapsedMilliseconds}ms)');

      _log('✅ completeCleaning 성공 (총 ${sw.elapsedMilliseconds}ms)');
      return {'hotspotId': hotspotId, 'petChanceGranted': 1};
    } catch (e) {
      _log('❌ completeCleaning 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('청소 완료 처리 실패: $e');
    }
  }

  // ==========================================
  // 8. Hotspot 삭제
  // ==========================================
  Future<void> deleteHotspot(String hotspotId) async {
    final sw = Stopwatch()..start();
    _log('🔵 deleteHotspot 시작 (id=$hotspotId)');
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
      _log('✅ deleteHotspot 성공 (총 ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ deleteHotspot 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('Hotspot 삭제 실패: $e');
    }
  }
}
