import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'party_invite_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.showSubmittedToast = false});

  final bool showSubmittedToast; // true면 진입 시 "Report submitted!" 표시

  // ⭐ static이라 앱 실행 중에는 상태 유지됨
  // TODO(backend): Firestore hotspots 컬렉션에서 실시간 스트림으로 받아오기
  static final List<LatLng> _dustSpots = [
    const LatLng(51.5420, -0.1460),
    const LatLng(51.5375, -0.1390),
    const LatLng(51.5410, -0.1385),
  ];

  // 외부에서 새 마커 추가할 때 호출
  static void addDustSpot(LatLng spot) {
    _dustSpots.add(spot);
  }

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _center = LatLng(51.5394, -0.1426);

  @override
  void initState() {
    super.initState();
    // 진입 시 "Report submitted!" 표시 요청이 있으면 알림
    if (widget.showSubmittedToast) {
      // 화면 그려진 후 실행 (안 그러면 Overlay 접근 에러)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showReportSubmittedToast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(initialCenter: _center, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sdsd',
              ),
              MarkerLayer(
                markers: [
                  // 내 위치 (파란 원)
                  Marker(
                    point: _center,
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
                  // 먼지 마커들
                  ...MapScreen._dustSpots.map(
                    (spot) => Marker(
                      point: spot,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => _showHotspotSheet(context),
                        child: Image.asset('assets/images/marker_dust.png'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                  onTap: () {
                    // TODO: 내 위치로 이동
                  },
                  child: Image.asset(
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

  // "Report submitted!" 알림 표시 (3초간)
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

  void _showHotspotSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
            // 나머지 콘텐츠
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
                        // 왼쪽: 쓰레기 사진
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
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
                                  _buildBadge('Duo', const Color(0xFFFB7185)),
                                  const SizedBox(width: 6),
                                  _buildBadge('500m', const Color(0xFFFB923C)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '56 Camden High Street, London',
                                style: TextStyle(
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
                                    'Posted 5 minutes ago by ',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const Text(
                                    '@naby128',
                                    style: TextStyle(
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
                            onTap: () {
                              Navigator.pop(context); // 시트 먼저 닫기
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PartyInviteScreen(),
                                ),
                              );
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
                    const Spacer(), // 남은 공간 밀어내기
                    // Start Plogging! 버튼
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: 플로깅 시작 → 카메라 or 지도 이동
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFB923C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
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
