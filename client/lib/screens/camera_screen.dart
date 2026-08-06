//camera_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'set_location_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;

  // 촬영한 사진 경로 (촬영 후 확인 화면에서 사용)
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  // 카메라 초기화
  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    // 후면 카메라 우선, 없으면 첫 번째 카메라 사용
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // 사진 촬영
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final image = await _controller!.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImagePath = image.path;
      });
      // TODO(ai): 여기서 AI API로 쓰레기 여부 판단 필요
      // 지금은 시간관계상 모든 사진 통과
    } catch (e) {
      // TODO: 촬영 실패 처리
      debugPrint('촬영 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedImagePath == null
            ? _buildCameraView() // 촬영 화면
            : _buildConfirmView(), // 확인 화면
      ),
    );
  }

  // ==================== 촬영 화면 ====================
  Widget _buildCameraView() {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _controller == null ||
            !_controller!.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return Stack(
          children: [
            // 실시간 카메라 프리뷰
            Positioned.fill(child: CameraPreview(_controller!)),
            // 위쪽
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120, // 프레임 위쪽 여백
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            // 아래쪽
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 180, // 프레임 아래쪽 여백 (촬영 버튼 자리 포함)
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            // 왼쪽
            Positioned(
              top: 120,
              bottom: 180,
              left: 0,
              width: 32, // 프레임 왼쪽 여백
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            // 오른쪽
            Positioned(
              top: 120,
              bottom: 180,
              right: 0,
              width: 32, // 프레임 오른쪽 여백
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),

            // 4개 모서리 프레임
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 120, // 위 오버레이 높이랑 맞춤
                  bottom: 180, // 아래 오버레이 높이랑 맞춤
                  left: 32, // 왼쪽 오버레이 너비랑 맞춤
                  right: 32, // 오른쪽 오버레이 너비랑 맞춤
                ),
                child: _buildCornerFrame(),
              ),
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Spot and capture litter',
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
            // 촬영 버튼 (하단 중앙)
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
        ;
      },
    );
  }

  // 4개 모서리 프레임
  Widget _buildCornerFrame() {
    const cornerColor = Color(0xFF34D399); // 초록색
    const cornerSize = 32.0;
    const cornerThickness = 6.0;

    return Stack(
      children: [
        // 왼쪽 위
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
        // 오른쪽 위
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
        // 왼쪽 아래
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
        // 오른쪽 아래
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

  // 모서리 한 개 (L자 모양)
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
          // 가로 선
          Positioned(
            top: topLeft || topRight ? 0 : null,
            bottom: bottomLeft || bottomRight ? 0 : null,
            left: topLeft || bottomLeft ? 0 : null,
            right: topRight || bottomRight ? 0 : null,
            child: Container(width: size, height: thickness, color: color),
          ),
          // 세로 선
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

  // ==================== 확인 화면 ====================
  Widget _buildConfirmView() {
    return Stack(
      children: [
        // 촬영한 사진 (전체 화면)
        Positioned.fill(
          child: Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
        ),
        // 상단 바 (뒤로가기 + 타이틀)
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
                    // 뒤로가기 = 다시 촬영 화면으로
                    setState(() {
                      _capturedImagePath = null;
                    });
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
        // 하단 버튼 영역
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Column(
            children: [
              // Use this photo 버튼 (그라디언트)
              GestureDetector(
                onTap: () {
                  // TODO(backend): Firebase Storage에 사진 업로드
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SetLocationScreen(photoPath: _capturedImagePath!),
                    ),
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
              // Or take again 링크
              GestureDetector(
                onTap: () {
                  // 다시 촬영 화면으로
                  setState(() {
                    _capturedImagePath = null;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
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
}
