//set_location_screen.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'package:sdsd/server/services/hotspots_service.dart';
import 'package:sdsd/server/services/auth_service.dart';

class SetLocationScreen extends StatefulWidget {
  const SetLocationScreen({super.key, required this.photoPath});

  final String photoPath;

  @override
  State<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends State<SetLocationScreen> {
  final MapController _mapController = MapController();

  // 초기 중심 좌표 (Camden)
  // TODO(backend): 사용자 현재 GPS 위치로 초기화
  static const LatLng _initialCenter = LatLng(51.5394, -0.1426);
  // 선택된 Cleanup size ('Solo', 'Duo', 'Squad', 'More')
  String? _selectedSize;
  // More 선택 시 인원 수 (기본 5명)
  // TODO(backend): 스키마에 memberCount 필드가 추가되면 함께 저장
  int _moreCount = 5;
  // 현재 지도 중심의 주소
  String _currentAddress = 'Loading address...';

  // ==========================================
  // 백엔드 연결용 상태
  // ==========================================
  final HotspotService _hotspotService = HotspotService();
  final AuthService _authService = AuthService();
  final TextEditingController _descriptionController =
      TextEditingController(); // 위치 설명 입력값을 읽기 위해 추가
  bool _isSubmitting = false;

  // ==========================================
  // 지도 "준비 완료" 타이밍 문제 방지용
  // ==========================================
  // FlutterMap이 화면에 완전히 자리잡기 전에 _mapController.move()를
  // 호출하면 조용히 실패할 수 있습니다. GPS 응답이 지도보다 먼저 도착하는
  // 경우를 대비해서, "지도 준비됨" 상태와 "아직 이동 못한 목표 좌표"를
  // 따로 기억해뒀다가, 둘 다 준비되는 시점에 실제로 이동시킵니다.
  bool _mapReady = false;
  LatLng? _pendingMoveTarget;

  @override
  void initState() {
    super.initState();
    _moveToMyLocation();
  }

  // ==========================================
  // 진입 시 실제 GPS 위치로 지도 초기화 (실패하면 하드코딩된 Camden 좌표 유지)
  // ==========================================
  Future<void> _moveToMyLocation() async {
    print('[SetLocationScreen] 🔵 _moveToMyLocation 시작');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('[SetLocationScreen] → 위치 서비스 활성화 여부: $serviceEnabled');
      if (!serviceEnabled) {
        _showLocationFallbackNotice('위치 서비스가 꺼져 있어 기본 위치로 표시합니다');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('[SetLocationScreen] → 현재 권한 상태: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('[SetLocationScreen] → 권한 재요청 결과: $permission');
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationFallbackNotice('위치 권한이 없어 기본 위치로 표시합니다');
        return; // 권한 없으면 Camden 대체값 유지 (단, 이제는 사용자에게 이유를 알려줌)
      }

      print('[SetLocationScreen] → getCurrentPosition 요청 중... (최대 5초 대기)');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 5));
      print(
        '[SetLocationScreen] → 위치 확인 성공: lat=${position.latitude}, lng=${position.longitude}',
      );

      if (!mounted) return;
      final target = LatLng(position.latitude, position.longitude);

      if (_mapReady) {
        // 지도가 이미 준비돼있으면 바로 이동
        _mapController.move(target, 16);
        print('[SetLocationScreen] ✅ _moveToMyLocation 성공 (즉시 이동)');
      } else {
        // 아직 지도가 준비 안 됐으면, "onMapReady"가 불릴 때 이동하도록 예약만 해둠
        _pendingMoveTarget = target;
        print('[SetLocationScreen] ⏳ 지도 아직 미준비, 목표 좌표 대기 등록 (onMapReady 대기)');
      }
    } catch (e) {
      print('[SetLocationScreen] ❌ _moveToMyLocation 실패, 기본 좌표(Camden) 유지: $e');
      _showLocationFallbackNotice('위치를 가져오지 못해 기본 위치로 표시합니다');
    }
  }

  // 실제 GPS 대신 하드코딩된 Camden 좌표로 대체될 때, 사용자에게 그 사실을 알림
  // (예전엔 조용히 넘어가서 "왜 항상 같은 위치지?"가 원인불명이었음)
  void _showLocationFallbackNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange[700]),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // crewSize 값을 HotspotService가 요구하는 형식으로 변환
  // ('Solo' → 'solo' 등)
  String _toCrewSizeValue(String label) => label.toLowerCase();

  // ==========================================
  // 화면에 보이는 핀이 실제로 가리키는 위경도 계산
  // ==========================================
  // 핀은 Alignment(0, -0.3) 위치(화면 중앙보다 살짝 위)에 고정 표시되지만,
  // _mapController.camera.center는 "화면 정중앙"의 좌표입니다.
  // 이 둘이 다르기 때문에, 화면 픽셀 차이를 실제 위도 차이로 환산해서
  // "핀이 진짜로 가리키는 좌표"를 계산합니다. (Web Mercator 투영 공식 사용)
  LatLng _getPinLatLng() {
    final camera = _mapController.camera;
    final center = camera.center;
    final zoom = camera.zoom;

    final screenHeight = MediaQuery.of(context).size.height;
    // Alignment(0, -0.3): 화면 중앙에서 위쪽으로 (screenHeight/2)의 30%만큼 떨어진 위치
    final pixelOffsetUp = 0.3 * (screenHeight / 2);

    // Web Mercator 기준, 위도/줌 레벨에 따른 "픽셀당 실제 거리(m)"
    final metersPerPixel =
        156543.03392 * cos(center.latitude * pi / 180) / pow(2, zoom);
    final metersOffset = pixelOffsetUp * metersPerPixel;

    // 화면에서 위쪽으로 갈수록 위도(latitude)는 커집니다 (북쪽)
    final latOffsetDegrees = metersOffset / 111320.0;

    return LatLng(center.latitude + latOffsetDegrees, center.longitude);
  }

  // ==========================================
  // Submit 버튼 로직: 사진 + 위치 + 정보를 Firestore/Storage에 저장
  // ==========================================
  Future<void> _handleSubmit() async {
    if (_selectedSize == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cleanup size를 선택해주세요')));
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 설명을 입력해주세요')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 촬영된 사진 파일을 bytes로 읽기 (reportHotspot이 요구하는 형식)
      final photoBytes = await File(widget.photoPath).readAsBytes();

      final pinLocation = _getPinLatLng(); // ← 변경: 화면 정중앙이 아니라 실제 핀 위치

      await _hotspotService.reportHotspot(
        latitude: pinLocation.latitude,
        longitude: pinLocation.longitude,
        // TODO(ai): 실제 쓰레기 종류 자동판별/선택 UI가 생기면 교체하세요.
        //           지금은 이 화면에 종류 선택 UI가 없어서 기본값으로 신고됩니다.
        trashType: 'general',
        locationDescription: description,
        crewSize: _toCrewSizeValue(_selectedSize!),
        photoBytes: photoBytes,
      );

      if (!mounted) return;

      // 신고 직후 서버 재조회 없이 즉시 지도에 마커 표시 (낙관적 업데이트)
      MapScreen.addDustSpot(pinLocation);

      // 다른 화면들과 일관되게, 하드코딩 대신 실제 사용자 이름을 가져와서 전달
      String displayName = 'User';
      final uid = _authService.currentUserId;
      if (uid != null) {
        try {
          final profile = await _authService.getUserProfile(uid);
          displayName = profile['displayName'] as String? ?? 'User';
        } catch (_) {
          // 이름 조회 실패해도 신고 자체는 이미 성공했으니 기본값으로 계속 진행
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            name: displayName,
            initialTab: 1, // 지도 탭
            showMapToast: true, // ← 추가: "Report submitted!" 토스트 표시
          ),
        ),
        (route) => false, // 이전 화면 모두 제거
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ============ 지도 ============
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 16,
              onMapReady: () {
                // 지도가 완전히 준비된 시점. 그 사이 GPS 위치를 먼저
                // 받아놓고 못 옮겼던(대기 중이던) 좌표가 있으면 지금 이동시킵니다.
                _mapReady = true;
                print('[SetLocationScreen] → onMapReady 호출됨');
                if (_pendingMoveTarget != null) {
                  _mapController.move(_pendingMoveTarget!, 16);
                  print('[SetLocationScreen] ✅ 대기 중이던 좌표로 이동 완료 (지도 준비 후)');
                  _pendingMoveTarget = null;
                }
              },
              onPositionChanged: (position, hasGesture) {
                // TODO(backend): 지도 중심 좌표(position.center)를 실제 주소로 변환
                // reverse geocoding은 백엔드에서 처리 후 응답받아 표시
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sdsd',
              ),
            ],
          ),
          // ============ 중앙 고정 핀 (시트에 안 가려지게 위쪽에) ============
          const IgnorePointer(
            child: Align(
              alignment: Alignment(0, -0.3), // x=0(가로 중앙), y=-0.3(위쪽으로)
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LitterSpotLabel(),
                  SizedBox(height: 4),
                  _LitterPin(),
                ],
              ),
            ),
          ),
          // ============ 뒤로가기 버튼 ============
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          // ============ 드래그 시트 ============
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    // 드래그 핸들
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 타이틀 (중앙 정렬)
                    const Text(
                      'Set Location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 서브텍스트 (중앙 정렬)
                    Text(
                      'Drag the map to move the pin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 주소 (지도 움직이면 자동 갱신)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFFFB923C),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            // TODO(backend): 지도 중심 좌표를 백엔드에 보내서 주소 받아오기
                            '56 Camden High Street, London NW1 7JB, UK',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 위치 설명 입력창
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller:
                                  _descriptionController, // ← 추가: 입력값을 읽기 위해 연결
                              enabled: !_isSubmitting,
                              decoration: InputDecoration(
                                hintText: 'Describe the location ...',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Cleanup size 섹션
                    Row(
                      children: [
                        Icon(Icons.people, size: 18, color: Colors.grey[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Cleanup size',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Solo / Duo 첫 줄
                    Row(
                      children: [
                        Expanded(child: _buildSizeButton('Solo')),
                        const SizedBox(width: 10),
                        Expanded(child: _buildSizeButton('Duo')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Squad / More 둘째 줄
                    Row(
                      children: [
                        Expanded(child: _buildSizeButton('Squad')),
                        const SizedBox(width: 10),
                        Expanded(child: _buildSizeButton('More')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Submit 버튼
                    GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : _handleSubmit, // ← 변경: 저장 로직 연결
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFF472B6), Color(0xFFFBBF24)],
                          ),
                        ),
                        child: Center(
                          child: _isSubmitting
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
                                  'Submit',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Cleanup size 버튼 (Solo / Duo / Squad / More)
  Widget _buildSizeButton(String label) {
    final bool isSelected = _selectedSize == label;
    return GestureDetector(
      onTap: _isSubmitting
          ? null
          : () {
              setState(() {
                _selectedSize = label;
              });
              // More 선택 시 인원 조정 팝업 열기
              if (label == 'More') {
                _showMoreCountDialog();
              }
            },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFFBBF24), Color(0xFFFB923C)],
                )
              : null,
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFFB923C),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            // More 선택되고 인원 수 있으면 숫자 표시 (예: "More 6")
            isSelected && label == 'More' ? '··· $_moreCount' : label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isSelected ? Colors.white : const Color(0xFFFB923C),
            ),
          ),
        ),
      ),
    );
  }

  // More 인원 조정 팝업 (- / 인원수 / +)
  // 최소 5명, 바깥 탭하면 저장하고 닫힘
  void _showMoreCountDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        return StatefulBuilder(
          // 팝업 내부에서만 setState 쓰려고 StatefulBuilder 사용
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // - 버튼
                    GestureDetector(
                      onTap: () {
                        // 최소 5명 제한
                        if (_moreCount > 5) {
                          setDialogState(() => _moreCount--);
                          setState(() {}); // 부모 화면도 갱신
                        }
                      },
                      child: const Text(
                        '−',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // 현재 인원 수
                    Text(
                      '$_moreCount',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        color: Color(0xFFF472B6), // 핑크
                      ),
                    ),
                    const SizedBox(width: 24),
                    // + 버튼
                    GestureDetector(
                      onTap: () {
                        setDialogState(() => _moreCount++);
                        setState(() {}); // 부모 화면도 갱신
                      },
                      child: const Text(
                        '+',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LitterSpotLabel extends StatelessWidget {
  const _LitterSpotLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Litter Spot',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LitterPin extends StatelessWidget {
  const _LitterPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
        Container(width: 2, height: 20, color: Colors.black),
      ],
    );
  }
}
