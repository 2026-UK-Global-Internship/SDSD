import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';

class PloggingScreen extends StatefulWidget {
  const PloggingScreen({super.key});

  @override
  State<PloggingScreen> createState() => _PloggingScreenState();
}

class _PloggingScreenState extends State<PloggingScreen> {
  // 현재 화면 상태 (timer / camera / result)
  // TODO: 다음 단계에서 상태 전환 로직 추가
  String _currentView = 'timer';
  // 경과 시간 (초)
  int _elapsedSeconds = 0;
  // 타이머 실행 중 여부
  bool _isRunning = false;

  // 초 카운트용 타이머
  Timer? _timer;

  // 3초 홀드 감지용 타이머
  Timer? _holdTimer;

  // TODO(sensor): 실제 걸음수/칼로리 측정 (지금은 하드코딩)
  final int _steps = 12;
  final int _kcal = 2;

  // 파티원 (하드코딩)
  // TODO(backend): Firebase에서 실제 파티원 정보 받아오기
  final List<Map<String, String>> _partyMembers = [
    {'name': 'James', 'character': 'character_yellow'},
    {'name': 'You', 'character': 'character_green'},
  ];
  // 카메라 컨트롤러
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;

  // 촬영한 사진 경로
  String? _capturedImagePath;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case 'camera':
        return _buildCameraView(); // TODO: 4단계
      case 'result':
        return _buildResultView(); // TODO: 6단계
      default:
        return _buildTimerView();
    }
  }

  Widget _buildTimerView() {
    return Stack(
      children: [
        // 축소 아이콘 (좌상단)
        Positioned(
          top: 12,
          left: 12,
          child: IconButton(
            icon: const Icon(Icons.close_fullscreen, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        // 메인 콘텐츠
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 100),
              // 시간 표시 (0:01 형태)
              Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic, // Italic
                  fontSize: 110,
                  color: Colors.black,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              // 서브 텍스트
              Text(
                // TODO: 실제 요일/시간대 표시
                'Monday Evening Plogging',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              // 원형 링 + 파티원 + 재생 버튼
              _buildPartyRing(),

              const Spacer(),
              // STEPS + KCAL
              Padding(
                padding: const EdgeInsets.only(bottom: 87),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      icon: Icons.directions_walk,
                      value: '$_steps',
                      label: 'STEPS',
                      color: const Color(0xFFFB923C),
                    ),
                    _buildStatItem(
                      icon: Icons.local_fire_department,
                      value: '$_kcal',
                      label: 'KCAL',
                      color: const Color(0xFFFB923C),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 시간 포맷 (0:01, 18:34)
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // 카메라 초기화
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  // 사진 촬영
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_cameraController!.value.isTakingPicture) return;
    try {
      final image = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImagePath = image.path;
      });
    } catch (e) {
      debugPrint('촬영 실패: $e');
    }
  }

  // 타이머 시작/정지 토글
  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
    });

    if (_isRunning) {
      // 1초마다 카운트 증가
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds++;
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  void _startHoldTimer() {
    debugPrint('🟢 홀드 시작!'); // ← 추가
    _holdTimer = Timer(const Duration(seconds: 3), () {
      debugPrint('🔴 3초 완료! 카메라로 이동'); // ← 추가

      // 3초 홀드 완료 → 카메라 화면으로
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _currentView = 'camera';
      });
      // 카메라 초기화
      _cameraInitFuture = _initCamera();
    });
  }

  // 홀드 취소 (3초 되기 전에 손 뗌)
  void _cancelHoldTimer() {
    debugPrint('❌ 홀드 취소'); // ← 추가
    _holdTimer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _holdTimer?.cancel();
    _cameraController?.dispose(); // ← 추가
    super.dispose();
  }

  // 원형 링 + 파티원 캐릭터 + 재생 버튼
  Widget _buildPartyRing() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 원형 그라디언트 링 (배경)
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFFBBF24),
                  Color(0xFFFB923C),
                  Color(0xFFF472B6),
                  Color(0xFFFBBF24),
                ],
              ),
            ),
          ),
          // 링 안쪽 흰 원 (링 두께 만들기 위한 트릭)
          Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          // 재생 버튼 (중앙)
          // TODO: 3단계에서 GestureDetector로 감싸서 탭/홀드 로직 추가
          // 재생 버튼 + Hold to end. (중앙)
          // 재생 버튼 + Hold to end. (중앙)
          GestureDetector(
            onTap: _toggleTimer, // 탭 = 시작/정지
            onLongPressStart: (_) => _startHoldTimer(), // 홀드 시작
            onLongPressEnd: (_) => _cancelHoldTimer(), // 홀드 취소
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 재생/일시정지 아이콘 (상태에 따라 다르게)
                // 재생/일시정지 이미지 (상태에 따라 다르게)
                Image.asset(
                  _isRunning
                      ? 'assets/images/btn_plogging_pause.png'
                      : 'assets/images/btn_plogging_play.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hold to end.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: Color(0xFF8E8E8E),
                  ),
                ),
              ],
            ),
          ),
          // 파티원 캐릭터들 (링 위에 배치)
          // TODO: 파티원 수에 따라 자동 배치
          Positioned(
            top: 8,
            left: 88,
            child: _buildPartyMember(_partyMembers[0]),
          ),
          Positioned(
            top: 24,
            right: 60,
            child: _buildPartyMember(_partyMembers[1]),
          ),
        ],
      ),
    );
  }

  // 파티원 캐릭터 하나
  Widget _buildPartyMember(Map<String, String> member) {
    return Column(
      children: [
        Image.asset(
          'assets/images/icons/${member['character']}.png',
          width: 28,
          height: 28,
        ),
        const SizedBox(height: 2),
        Text(
          member['name']!,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 10,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // STEPS / KCAL 아이템
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraView() {
    return FutureBuilder(
      future: _cameraInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _cameraController == null ||
            !_cameraController!.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }

        // 사진 촬영 후 → 확인 화면
        if (_capturedImagePath != null) {
          return _buildCameraConfirmView();
        }

        // 촬영 화면
        return Stack(
          children: [
            // 실시간 카메라 프리뷰
            Positioned.fill(child: CameraPreview(_cameraController!)),
            // 프레임 바깥 반투명 오버레이
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 180,
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Positioned(
              top: 120,
              bottom: 180,
              left: 0,
              width: 32,
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Positioned(
              top: 120,
              bottom: 180,
              right: 0,
              width: 32,
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            // 상단 바 (뒤로가기 + 타이틀)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        // 카메라 → 타이머 화면으로 돌아가기
                        setState(() {
                          _currentView = 'timer';
                        });
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Snap the clean street!',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            // 4개 모서리 프레임 (기존 camera_screen 스타일)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 120,
                  bottom: 180,
                  left: 32,
                  right: 32,
                ),
                child: _buildCornerFrame(),
              ),
            ),
            // 촬영 버튼
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _takePicture,
                  child: Image.asset(
                    'assets/images/btn_capture.png',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 4개 모서리 프레임 (camera_screen.dart와 동일)
  Widget _buildCornerFrame() {
    const cornerColor = Color(0xFF34D399);
    const cornerSize = 32.0;
    const cornerThickness = 6.0;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          child: _corner(
            cornerColor,
            cornerSize,
            cornerThickness,
            topLeft: true,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _corner(
            cornerColor,
            cornerSize,
            cornerThickness,
            topRight: true,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: _corner(
            cornerColor,
            cornerSize,
            cornerThickness,
            bottomLeft: true,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _corner(
            cornerColor,
            cornerSize,
            cornerThickness,
            bottomRight: true,
          ),
        ),
      ],
    );
  }

  Widget _corner(
    Color color,
    double size,
    double thickness, {
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: topLeft || topRight ? 0 : null,
            bottom: bottomLeft || bottomRight ? 0 : null,
            left: topLeft || bottomLeft ? 0 : null,
            right: topRight || bottomRight ? 0 : null,
            child: Container(width: size, height: thickness, color: color),
          ),
          Positioned(
            top: topLeft || topRight ? 0 : null,
            bottom: bottomLeft || bottomRight ? 0 : null,
            left: topLeft || bottomLeft ? 0 : null,
            right: topRight || bottomRight ? 0 : null,
            child: Container(width: thickness, height: size, color: color),
          ),
        ],
      ),
    );
  }

  // 촬영 후 확인 화면 (Use this photo / Or take again)
  Widget _buildCameraConfirmView() {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
        ),
        // 상단 바
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    setState(() => _capturedImagePath = null);
                  },
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Check your photo',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        // 하단 버튼
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Column(
            children: [
              // Use this photo
              GestureDetector(
                onTap: () {
                  // TODO(backend): Firebase Storage에 사진 업로드
                  // 결과 화면으로 전환
                  setState(() {
                    _currentView = 'result';
                  });
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Use this photo',
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
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() => _capturedImagePath = null);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Or take again',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // ============ 캐릭터 ============
            Positioned(
              top: 70,
              left: 10,
              child: Image.asset(
                'assets/images/plogging_completed_character.png',
                width: 207,
                height: 207,
              ),
            ),
            // ============ 하트 ============
            Positioned(
              top: 94,
              right: 70,
              child: Image.asset(
                'assets/images/plogging_completed_heart.png',
                width: 90,
                height: 90,
              ),
            ),
            // ============ 폴라로이드 카드 ============
            Positioned(
              top: 244,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 355,
                  height: 410,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 흰 배경 (기울어짐)
                      Transform.rotate(
                        angle: 0.2263,
                        child: Container(
                          width: 355,
                          height: 410,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 지도 이미지 (안 기울어짐)
                      Positioned(
                        top: 14,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/images/plogging_completed_map.png',
                            width: 310,
                            height: 223,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // 파티원 캐릭터 (지도 오른쪽 아래)
                      Positioned(
                        top: 210,
                        right: 20,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/icons/character_green.png',
                              width: 32,
                              height: 32,
                            ),
                            Transform.translate(
                              offset: const Offset(-8, 4),
                              child: Image.asset(
                                'assets/images/icons/character_yellow.png',
                                width: 32,
                                height: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 텍스트 영역 (카드와 같이 기울어짐)
                      Positioned(
                        left: 10,
                        right: 30,
                        bottom: 40,
                        child: Transform.rotate(
                          angle: 0.2263, // 카드와 같은 각도
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20), // ← 이 줄 추가 (숫자로 조절)
                              // 날짜
                              const Text(
                                'July 29, 2026 · 08:30 AM',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  height: 29.7 / 16,
                                  letterSpacing: -1.49,
                                  color: Color(0xFF848484),
                                ),
                              ),
                              const SizedBox(height: 2),
                              // 주소
                              const Text(
                                'Camden High St, London NW1 8NJ, UK',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  height: 29.7 / 16,
                                  letterSpacing: -1.49,
                                  color: Color(0xFF848484),
                                ),
                              ),
                              const SizedBox(height: 40), // 2cm 여백
                              // with @친구들
                              const Text(
                                'with @sally1039, @thejames',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18,
                                  height: 29.7 / 18,
                                  color: Color(0xFFFF9604),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ============ "Plogging Completed!" (카드 위에 오도록 여기 배치) ============
            Positioned(
              top: 180,
              left: 130,
              child: Transform.rotate(
                angle: -0.08,
                child: const Text(
                  'Plogging\nCompleted!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    fontSize: 40,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            // ============ Finish 버튼 ============
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
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
                    'Finish',
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
    );
  }
}
