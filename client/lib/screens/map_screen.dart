import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  // Camden 중심 좌표
  static const LatLng _center = LatLng(51.5394, -0.1426);

  // 임시 먼지 마커 위치들 (간격 넓힘, 나중에 서버 데이터로 교체)
  static final List<LatLng> _dustSpots = [
    const LatLng(51.5420, -0.1460),
    const LatLng(51.5375, -0.1390),
    const LatLng(51.5410, -0.1385),
  ];

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
                  ..._dustSpots.map(
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

  void _showHotspotSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent, // 배경 안 어두워짐
      isScrollControlled: true, // 시트 높이 자유롭게
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6, // 화면의 60%
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(child: Text('여기에 상세 카드 들어갈 예정')),
      ),
    );
  }
}
