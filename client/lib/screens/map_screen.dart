//map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'party_invite_screen.dart';
import 'plogging_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sdsd/server/services/hotspots_service.dart';
import 'package:sdsd/server/services/auth_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.showSubmittedToast = false,
    this.onToastShown,
  });

  final bool showSubmittedToast; // true면 진입 시 "Report submitted!" 표시
  final VoidCallback? onToastShown; // 토스트를 보여준 직후 호출 (부모가 상태를 "소비"할 수 있게)

  // ⭐ static이라 앱 실행 중에는 상태 유지됨
  // 신고 직후, 서버에 다시 물어보지 않고도 즉시 지도에 마커를 하나 더
  // 찍어주기 위한 "낙관적 업데이트"용 좌표 목록입니다.
  // (실제 상세 데이터는 없고 좌표만 있어서, 다음 _loadHotspots() 호출 때
  //  서버의 진짜 hotspot 데이터로 자연스럽게 대체됩니다)
  static final List<LatLng> _dustSpots = [];

  // 외부(신고 화면 등)에서 새 마커를 즉시 추가할 때 호출
  static void addDustSpot(LatLng spot) {
    _dustSpots.add(spot);
  }

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Camden 중심 좌표 (GPS 응답 전 / 권한 거부 시 대체값)
  static const LatLng _center = LatLng(51.5394, -0.1426);

  final HotspotService _hotspotService = HotspotService();
  final MapController _mapController = MapController();

  // Firestore에서 불러온 hotspot 목록 (각 항목은 Map<String, dynamic>)
  List<Map<String, dynamic>> _hotspots = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 실제 GPS로 가져온 내 위치. 못 가져왔으면 null → 이땐 하드코딩된 _center로 대체 표시
  LatLng? _myLocation;
  bool _isLocating = false; // "내 위치로 이동" 버튼 처리 중 여부

  @override
  void initState() {
    super.initState();
    _loadHotspots();
    _getMyLocation(
      moveCamera: true,
      silent: true,
    ); // 시작 시 내 위치로 이동, 실패해도 조용히 넘어감

    // 진입 시 "Report submitted!" 표시 요청이 있으면 알림
    if (widget.showSubmittedToast) {
      // 화면 그려진 후 실행 (안 그러면 Overlay 접근 에러)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showReportSubmittedToast();
        widget.onToastShown?.call(); // 부모(HomeScreen)에게 "다 보여줬다" 알림
      });
    }
  }

  // ==========================================
  // 서버에서 "open" 상태인 hotspot 목록 불러오기
  // ==========================================
  Future<void> _loadHotspots() async {
    print('[MapScreen] 🔵 _loadHotspots 시작');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hotspots = await _hotspotService.getOpenHotspots();
      print('[MapScreen] → getOpenHotspots 결과: ${hotspots.length}건');
      for (final h in hotspots) {
        print(
          '[MapScreen]    - id=${h['id']}, status=${h['status']}, location=${h['location']}',
        );
      }

      if (!mounted) return;
      setState(() {
        _hotspots = hotspots;
        _isLoading = false;
      });

      // 실제 서버 데이터를 방금 새로 받아왔으니, 그 전까지 "동기화 중"으로
      // 표시되던 낙관적 업데이트 마커(_dustSpots)는 이제 역할이 끝났습니다.
      // 지우지 않으면 실제 데이터가 이미 있어도 계속 "동기화 중"만 뜹니다.
      MapScreen._dustSpots.clear();
      print('[MapScreen] ✅ _loadHotspots 완료 (마커 ${hotspots.length}개)');
    } catch (e) {
      print('[MapScreen] ❌ _loadHotspots 실패: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ==========================================
  // 내 위치 가져오기 + (필요 시) 지도 카메라 이동
  // ==========================================
  Future<void> _getMyLocation({
    required bool moveCamera,
    bool silent = false,
  }) async {
    print(
      '[MapScreen] 🔵 _getMyLocation 시작 (moveCamera=$moveCamera, silent=$silent)',
    );
    if (moveCamera && !silent) {
      setState(() => _isLocating = true);
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('[MapScreen] → 위치 서비스 활성화 여부: $serviceEnabled');
      if (!serviceEnabled) {
        throw Exception('위치 서비스가 꺼져 있습니다. 기기 설정에서 켜주세요');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('[MapScreen] → 현재 권한 상태: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('[MapScreen] → 권한 재요청 결과: $permission');
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 직접 허용해주세요');
      }

      // 캐시된 마지막 위치로 우선 빠르게 표시
      // (getLastKnownPosition은 보통 즉시 반환되지만, 만약을 대비해 짧은 타임아웃)
      final lastKnown = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      print('[MapScreen] → getLastKnownPosition 결과: $lastKnown');
      if (lastKnown != null) {
        if (!mounted) return;
        final quickLatLng = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() => _myLocation = quickLatLng);
        if (moveCamera) {
          _mapController.move(quickLatLng, 15);
        }
      }

      // 실제 최신 위치로 정확히 갱신
      // 타임아웃 없으면 GPS 신호가 안 잡힐 때 스피너가 무한정 돌 수 있음
      print('[MapScreen] → getCurrentPosition 요청 중... (최대 10초 대기)');
      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('위치 확인 시간이 초과되었습니다. GPS 신호를 확인해주세요'),
          );
      print(
        '[MapScreen] → getCurrentPosition 결과: lat=${position.latitude}, lng=${position.longitude}',
      );
      final myLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() => _myLocation = myLatLng);

      if (moveCamera) {
        _mapController.move(myLatLng, 15);
      }
      print('[MapScreen] ✅ _getMyLocation 성공');
    } catch (e) {
      print('[MapScreen] ❌ _getMyLocation 실패: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (moveCamera && !silent && mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, // 없으면 _getMyLocation의 카메라 이동이 반영 안 됨
            options: const MapOptions(initialCenter: _center, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sdsd',
              ),
              MarkerLayer(
                markers: [
                  // 내 위치 (파란 원) - 실제 GPS 위치, 못 가져왔으면 대체 좌표
                  Marker(
                    point: _myLocation ?? _center,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 먼지 마커들 - 실제 서버 데이터 기반
                  // (잘못된 데이터가 섞여 있어도 전체 마커가 다 사라지지 않도록
                  //  안전하게 하나씩 걸러서 만듭니다 — _buildHotspotMarkers 참고)
                  ..._buildHotspotMarkers(),
                  // 방금 신고해서 아직 서버 재조회 전인 "낙관적 업데이트" 마커
                  // (실데이터가 없어 상세 시트 대신 안내만 표시)
                  ...MapScreen._dustSpots.map(
                    (spot) => Marker(
                      point: spot,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('정보를 동기화하는 중입니다. 잠시 후 다시 시도해주세요'),
                            ),
                          );
                        },
                        child: Image.asset('assets/images/marker_dust.png'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 로딩 인디케이터
          if (_isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          // 오류 표시 + 재시도
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadHotspots,
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 오른쪽 상단 버튼들 (filter / location)
          Positioned(
            top: 150,
            right: 16,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    // TODO: 필터 기능
                  },
                  child: Image.asset(
                    'assets/images/icons/ic_filter.png',
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: _isLocating
                      ? null
                      : () => _getMyLocation(moveCamera: true),
                  child: _isLocating
                      ? const SizedBox(
                          width: 56,
                          height: 56,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Image.asset(
                          'assets/images/icons/ic_my_location.png',
                          width: 56,
                          height: 56,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // hotspot 목록 → 마커 리스트 변환 (안전하게, 하나씩)
  // ==========================================
  // 리스트 리터럴 안에서 .map()으로 한 번에 만들면, location 데이터가
  // 잘못된 문서 단 하나 때문에 "마커 전체(파란 내 위치 점 포함)"가
  // 통째로 안 그려지는 문제가 있었습니다 (Dart는 리스트 리터럴을
  // 한 번에 계산하기 때문에, 하나가 실패하면 전부 실패).
  // 그래서 for문 + try/catch로 하나씩 만들고, 문제 있는 것만 건너뜁니다.
  List<Marker> _buildHotspotMarkers() {
    final markers = <Marker>[];

    for (final hotspot in _hotspots) {
      try {
        final location = hotspot['location'];
        if (location is! GeoPoint) {
          print(
            '[MapScreen] ⚠️ 잘못된 location 데이터, 마커 건너뜀: id=${hotspot['id']}, location=$location',
          );
          continue;
        }

        markers.add(
          Marker(
            point: LatLng(location.latitude, location.longitude),
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => _showHotspotSheet(context, hotspot),
              child: Image.asset('assets/images/marker_dust.png'),
            ),
          ),
        );
      } catch (e) {
        print('[MapScreen] ⚠️ 마커 생성 실패, 건너뜀: id=${hotspot['id']}, error=$e');
      }
    }

    return markers;
  }

  // ==========================================
  // "Report submitted!" 알림 표시 (3초간)
  // ==========================================
  void _showReportSubmittedToast() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 110, // 내비바 위쪽
        left: 0,
        right: 0,
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 초록 체크 아이콘
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 텍스트
                    const Text(
                      'Report submitted!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // 3초 후 자동으로 사라짐
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });
  }

  // ==========================================
  // hotspot 하나를 눌렀을 때: Party 디자인 바텀시트 표시
  // ==========================================
  void _showHotspotSheet(BuildContext context, Map<String, dynamic> hotspot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _HotspotPartySheet(
        hotspot: hotspot,
        hotspotService: _hotspotService,
        myLocation: _myLocation,
        onReservationSuccess: _loadHotspots, // 예약 성공 시 지도 마커 새로고침
      ),
    );
  }
}

// ==========================================
// Hotspot 상세 정보 + Party 바텀시트
// ==========================================
class _HotspotPartySheet extends StatefulWidget {
  const _HotspotPartySheet({
    required this.hotspot,
    required this.hotspotService,
    required this.myLocation,
    required this.onReservationSuccess,
  });

  final Map<String, dynamic> hotspot;
  final HotspotService hotspotService;
  final LatLng? myLocation;
  final VoidCallback onReservationSuccess;

  @override
  State<_HotspotPartySheet> createState() => _HotspotPartySheetState();
}

class _HotspotPartySheetState extends State<_HotspotPartySheet> {
  bool _isReserving = false;

  // "Add friends"에서 선택한 친구 목록 (플로깅 시작 시 함께 저장됨)
  List<Map<String, dynamic>> _selectedPartyMembers = [];

  // 신고자 이름은 uid만 있고 문서엔 없어서 별도 조회가 필요함
  String _reporterName = '...';

  @override
  void initState() {
    super.initState();
    _loadReporterName();
  }

  // ==========================================
  // 신고자의 displayName 조회
  // ==========================================
  Future<void> _loadReporterName() async {
    final reporterId = widget.hotspot['reporterId'] as String?;
    if (reporterId == null) return;

    try {
      final profile = await AuthService().getUserProfile(reporterId);
      if (!mounted) return;
      setState(() {
        _reporterName = profile['displayName'] as String? ?? 'Someone';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reporterName = 'Someone'); // 조회 실패해도 화면은 정상 표시
    }
  }

  // ==========================================
  // "Start Plogging!" 버튼 로직
  // ==========================================
  Future<void> _handleStartPlogging() async {
    setState(() => _isReserving = true);

    try {
      // 이미 진행 중인(예약된) hotspot이 있는지 먼저 확인
      // → 있으면 새로 예약 시도하지 않고, 그 화면으로 바로 이동시킴
      final existingReservation = await widget.hotspotService
          .getMyReservedHotspot();

      if (existingReservation != null) {
        if (!mounted) return;
        Navigator.of(context).pop(); // 시트 닫기
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PloggingScreen(
              reservedHotspot: existingReservation,
              partyMembers: _selectedPartyMembers,
            ),
          ),
        );
        return;
      }

      final hotspotId = widget.hotspot['id'] as String;

      // 이 hotspot을 내 이름으로 예약 (Transaction으로 동시 예약 방지)
      await widget.hotspotService.reserveHotspot(hotspotId);

      widget.onReservationSuccess(); // 지도 마커 목록 새로고침

      if (!mounted) return;

      // 예약 성공 → PloggingScreen으로 이동 (hotspot 정보 + 파티원 정보 함께 전달)
      Navigator.of(context).pop(); // 시트 닫기
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PloggingScreen(
            reservedHotspot: widget.hotspot,
            partyMembers: _selectedPartyMembers,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red[600],
        ),
      );
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  // crewSize 값을 뱃지에 보여줄 문구로 변환
  String _crewSizeLabel(String crewSize) {
    switch (crewSize) {
      case 'solo':
        return 'Solo';
      case 'duo':
        return 'Duo';
      case 'squad':
        return 'Squad';
      case 'more':
        return 'More';
      default:
        return crewSize;
    }
  }

  // 두 좌표 사이 거리를 "500m" / "1.2km" 형태로 변환
  String? _distanceLabel() {
    final myLocation = widget.myLocation;
    final location = widget.hotspot['location'] as GeoPoint?;
    if (myLocation == null || location == null) return null;

    final meters = Geolocator.distanceBetween(
      myLocation.latitude,
      myLocation.longitude,
      location.latitude,
      location.longitude,
    );

    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  // createdAt(Timestamp)을 "5 minutes ago" 형태로 변환
  String _timeAgoLabel() {
    final createdAt = widget.hotspot['createdAt'] as Timestamp?;
    if (createdAt == null) return 'just now'; // 서버 타임스탬프가 아직 반영 전인 경우

    final diff = DateTime.now().difference(createdAt.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final hotspot = widget.hotspot;
    final String locationDescription =
        hotspot['locationDescription'] as String? ?? '';
    final String crewSize = hotspot['crewSize'] as String? ?? '';
    final String photoUrl = hotspot['photoUrl'] as String? ?? '';
    final String? distanceLabel = _distanceLabel();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들 바
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 사진 + 정보
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽: 쓰레기 사진 (실제 업로드된 사진, 없으면 샘플 이미지로 대체)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                      'assets/images/hotspot_sample.png',
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                              )
                            : Image.asset(
                                'assets/images/hotspot_sample.png',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 14),
                      // 오른쪽: 뱃지 + 주소 + 게시 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildBadge(
                                  _crewSizeLabel(crewSize),
                                  const Color(0xFFFB7185),
                                ),
                                if (distanceLabel != null) ...[
                                  const SizedBox(width: 6),
                                  _buildBadge(
                                    distanceLabel,
                                    const Color(0xFFFB923C),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              locationDescription,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.3,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Posted ${_timeAgoLabel()} by ',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '@$_reporterName',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFB923C),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Party 섹션 제목
                  const Text(
                    'Party',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Party 카드들
                  Row(
                    children: [
                      // 왼쪽: Add friends 카드
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            // 시트를 닫지 않고 그 위에 PartyInviteScreen을 띄웁니다.
                            // (닫아버리면 이 State 자체가 사라져서, 돌아왔을 때
                            //  선택한 친구 목록을 저장할 곳이 없어집니다)
                            final result =
                                await Navigator.push<
                                  List<Map<String, dynamic>>
                                >(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PartyInviteScreen(),
                                  ),
                                );

                            if (result != null && mounted) {
                              setState(() => _selectedPartyMembers = result);
                            }
                          },
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFB923C),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Color(0xFFFB923C),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_add,
                                      size: 14,
                                      color: Colors.black87,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add friends',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 오른쪽: 파티원 카드
                      // TODO: 실제 파티 참여자 목록 기능이 생기면 하드코딩된
                      //       James/You 부분을 실제 데이터로 교체하세요.
                      Expanded(
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 20,
                                left: 20,
                                child: Column(
                                  children: [
                                    Image.asset(
                                      'assets/images/icons/character_black.png',
                                      width: 32,
                                      height: 32,
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'James',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 15,
                                right: 15,
                                child: Column(
                                  children: [
                                    Image.asset(
                                      'assets/images/icons/character_green.png',
                                      width: 32,
                                      height: 32,
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'You',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Start Plogging! 버튼
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isReserving ? null : _handleStartPlogging,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFB923C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isReserving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Start Plogging!',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 뱃지 위젯 (Duo, 500m 등)
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}
