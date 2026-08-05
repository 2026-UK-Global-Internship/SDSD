import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'home_screen.dart';
import 'map_screen.dart';

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
  // TODO(backend): Firestore hotspot 문서의 size 필드로 저장
  String? _selectedSize;
  // More 선택 시 인원 수 (기본 5명)
  // TODO(backend): Firestore hotspot 문서의 memberCount 필드로 저장
  int _moreCount = 5;
  // 현재 지도 중심의 주소
  String _currentAddress = 'Loading address...';

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
                              // TODO(backend): 사용자 입력값을 Firestore에 저장
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
                      onTap: () {
                        // 유효성 검사
                        if (_selectedSize == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cleanup size를 선택해주세요'),
                            ),
                          );
                          return;
                        }

                        // TODO(backend): Firestore hotspots 컬렉션에 저장
                        // - photoPath: widget.photoPath (사진 경로, 실제로는 Firebase Storage에 업로드 후 URL 저장)
                        // - location: 지도 중심 좌표 (_mapController.camera.center)
                        // - address: 백엔드에서 역지오코딩 후 저장
                        // - description: 위치 설명 입력값
                        // - size: _selectedSize (Solo/Duo/Squad/More)
                        // - memberCount: _selectedSize == 'More' ? _moreCount : null
                        // - createdBy: 현재 로그인한 사용자 uid
                        // - createdAt: 서버 타임스탬프

                        // TODO: Submit 이후 화면으로 이동 (스크린샷 대기 중)
                        // 임시로 홈으로 돌아가기 (카메라 → 확인 → Set Location 모두 pop)
                        // 모든 화면 닫고 HomeScreen 지도 탭으로 이동
                        // 새 핫스팟 마커 추가 (임시 - 앱 실행 중에만 유지)
                        // TODO(backend): 실제로는 Firestore에 저장 후 스트림으로 자동 반영
                        MapScreen.addDustSpot(_mapController.camera.center);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const HomeScreen(
                              name: 'User', // TODO(backend): 실제 사용자 이름으로 교체
                              initialTab: 1, // 지도 탭
                            ),
                          ),
                          (route) => false, // 이전 화면 모두 제거
                        );
                      },
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
                        child: const Center(
                          child: Text(
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
      onTap: () {
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
