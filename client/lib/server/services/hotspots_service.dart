//hotspots_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'character_service.dart';
import 'photo_upload_service.dart';

class HotspotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CharacterService _characterService = CharacterService();
  final PhotoUploadService _photoUploadService = PhotoUploadService();

  // ==========================================
  // 1. Hotspot 신고 (쓰레기 위치 등록)
  // ==========================================
  // Security Rules 요구사항:
  //   - reporterId == 현재 로그인한 사용자 uid
  //   - status는 반드시 "open"으로 시작
  //   - location은 GeoPoint 타입이어야 함
  //
  // 변경 안내: photoUrl(String?) → photoBytes(Uint8List?)로 변경됨
  //   이제 사진 원본 데이터를 넘기면, 이 함수 안에서 Supabase 업로드까지
  //   자동으로 처리하고 그 결과 URL을 Firestore에 저장합니다.
  Future<String> reportHotspot({
    required double latitude,
    required double longitude,
    required String trashType,
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

      // 위도/경도 범위 검증 (잘못된 좌표 방지)
      if (latitude < -90 || latitude > 90) {
        throw Exception('올바른 위도 값이 아닙니다 (-90 ~ 90)');
      }
      if (longitude < -180 || longitude > 180) {
        throw Exception('올바른 경도 값이 아닙니다 (-180 ~ 180)');
      }

      // 문서 ID를 미리 확보 (아직 Firestore에 쓰지는 않음)
      // → 이 ID를 사진 업로드 경로(hotspots/{id}/photo.jpg)에 사용하기 위함
      final docRef = _firestore.collection('hotspots').doc();

      String photoUrl = '';
      if (photoBytes != null) {
        try {
          photoUrl = await _photoUploadService.uploadHotspotPhoto(
            hotspotId: docRef.id,
            fileBytes: photoBytes,
          );
        } catch (e) {
          // 사진 업로드가 실패해도 신고 자체는 계속 진행합니다.
          // (네트워크 문제로 신고 자체가 막히는 게 더 나쁜 사용자 경험이라 판단)
          print('⚠️ 사진 업로드 실패, 사진 없이 신고를 계속합니다: $e');
        }
      }

      await docRef.set({
        'reporterId': currentUser.uid,
        'photoUrl': photoUrl,
        'trashType': trashType,
        'location': GeoPoint(latitude, longitude),
        // ★ 추가: latitude/longitude를 별도 숫자 필드로도 저장
        //   Firestore는 GeoPoint 필드에 "사각형 범위 검색"을 못 하기 때문에
        //   지도 화면 영역(bounds) 검색을 위해 평범한 number 필드로 중복 저장합니다.
        'latitude': latitude,
        'longitude': longitude,
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
        data['id'] = doc.id; // 문서 ID도 함께 반환 (수정/삭제 시 필요)
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Hotspot 목록 조회 실패: $e');
    }
  }

  // ==========================================
  // 3. "open" 상태인 Hotspot만 조회 (지도 표시용)
  // ==========================================
  // 미리 만들어둔 Composite Index (status Asc, createdAt Desc) 사용
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
  // ⚠️ 설계 노트:
  //   Firestore는 "이 사각형 영역 안의 좌표"를 서버에서 효율적으로
  //   걸러주는 기능이 기본적으로 없습니다. 그래서 일단 getOpenHotspots()로
  //   전체 open 목록을 가져온 뒤, 여기서 좌표 비교로 필터링합니다.
  //
  //   즉, "서버 쿼리 최적화"가 아니라 "클라이언트 필터링"입니다.
  //   Hotspot 수가 수천 개 이상으로 늘어나면 비효율적일 수 있어서,
  //   나중에 geohash 기반 라이브러리(geoflutterfire2)로 교체할 수도
  //   있는데, 그때도 이 함수의 파라미터/반환값 형태는 그대로 유지
  //   가능하도록 설계했습니다 (내부 구현만 바뀜).
  //
  // 파라미터: 지도 화면에 지금 보이는 영역의 남서쪽(SW)/북동쪽(NE) 좌표
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
      // 경도가 180/-180 경계를 넘어가는 경우(날짜 변경선)는
      // 지금 단계에서는 다루지 않습니다 (한국 서비스 기준 발생 안 함).
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
  // Security Rules의 validate_hotspot_update() 규칙:
  //   oldStatus == "open" && newStatus == "reserved"
  //   && reservedBy == 현재 로그인한 사용자 uid  일 때만 허용
  Future<void> reserveHotspot(String hotspotId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 먼저 현재 상태 확인 (open이 아니면 미리 막아서 불필요한 요청 방지)
      final hotspot = await getHotspotById(hotspotId);
      if (hotspot['status'] != 'open') {
        throw Exception('이미 예약되었거나 청소 완료된 위치입니다');
      }

      // ★ 추가: 이미 다른 hotspot을 예약 중인지 확인 (한 번에 하나만 예약 가능)
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final existingReservation = userDoc.data()?['reservedHotspotId'];
      if (existingReservation != null) {
        throw Exception('이미 예약 중인 위치가 있습니다. 먼저 청소를 완료하거나 취소해주세요');
      }

      // Firestore Transaction 사용: 동시에 여러 명이 예약 시도해도 안전하게 처리
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

        // 1. hotspots 문서 업데이트: open → reserved
        transaction.update(docRef, {
          'status': 'reserved',
          'reservedBy': currentUser.uid,
        });

        // 2. users 문서에 예약한 hotspotId 기록 (스키마의 reservedHotspotId 필드)
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
  // Security Rules에 아래 reservedToOpen 케이스를 추가해야 동작합니다:
  //   oldStatus == "reserved" && newStatus == "open"
  //   && 현재 uid == 기존 reservedBy && 새 reservedBy == null
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

        // 1. hotspots 문서 업데이트: reserved → open, reservedBy 초기화
        transaction.update(docRef, {'status': 'open', 'reservedBy': null});

        // 2. users 문서의 예약 상태 해제
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
  // Security Rules의 validate_hotspot_update() 규칙:
  //   oldStatus == "reserved" && newStatus == "cleaned"
  //   && 현재 uid == reservedBy  일 때만 허용
  // 반환값 변경 안내: void → Map<String, dynamic>
  //   화면에서 "레벨업 했는지(leveledUp)"를 바로 알 수 있게 하기 위함입니다.
  //   (예: 레벨업 시 축하 팝업을 띄우는 등의 UI 반응에 활용)
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

        // 1. hotspots 문서 업데이트: reserved → cleaned
        transaction.update(docRef, {'status': 'cleaned'});

        // 2. users 문서의 예약 상태 해제
        final userRef = _firestore.collection('users').doc(currentUser.uid);
        transaction.update(userRef, {'reservedHotspotId': null});
      });

      print('✓ 청소 완료 처리 성공: $hotspotId');

      // ★ 연결: 청소 완료 보상 = "쓰다듬기 기회" 1개 지급
      //   XP는 여기서 바로 주지 않고, 사용자가 나중에 실제로
      //   CharacterService.petCharacter()를 호출해 이 기회를 "사용"할 때 XP가 들어갑니다.
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

      await _firestore.collection('hotspots').doc(hotspotId).delete();
      print('✓ Hotspot 삭제 성공: $hotspotId');
    } catch (e) {
      throw Exception('Hotspot 삭제 실패: $e');
    }
  }
}
