//username_screen.dart
import 'package:flutter/material.dart';
import 'goal_screen.dart';
import 'package:sdsd/server/services/auth_service.dart'; // ← 변경: 실제 위치(lib/server/services)에 맞춘 패키지 경로

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key, required this.name});

  final String name; // 이전 화면(NameScreen)에서 전달받는 이름

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _hasText = false;
  bool _isLoading = false; // ← 추가: 로딩 상태

  // Firebase 서비스 인스턴스
  final AuthService _authService = AuthService();

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      setState(() {
        _hasText = _usernameController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // ==========================================
  // Continue 버튼을 눌렀을 때 실행되는 함수
  // ==========================================
  Future<void> _handleContinue() async {
    // 입력값 가져오기
    final username = _usernameController.text.trim();

    // 입력값 검증
    if (username.isEmpty) {
      _showErrorSnackBar('사용자명을 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true; // 로딩 시작
    });

    try {
      // 현재 로그인한 사용자의 UID 가져오기
      final uid = _authService.currentUserId;

      if (uid == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      // Firebase에 displayName 업데이트
      await _authService.updateDisplayName(uid, username);

      // 업데이트 성공 → GoalScreen으로 이동
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalScreen(name: widget.name)),
        );
      }
    } catch (e) {
      // 업데이트 실패 → 오류 메시지 표시
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // 로딩 종료
        });
      }
    }
  }

  // ==========================================
  // SnackBar 표시 함수
  // ==========================================
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 93),
                GestureDetector(
                  onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_ios, size: 24),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Choose a\nusername',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is how other users will find you.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                // @ 붙은 username 입력창 + 체크 표시
                Row(
                  children: [
                    const Text(
                      '@',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _usernameController,
                        enabled: !_isLoading, // ← 추가: 로딩 중이면 비활성화
                        decoration: InputDecoration(
                          hintText: 'username',
                          hintStyle: const TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.black54,
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black38),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          disabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black12),
                          ),
                        ),
                      ),
                    ),
                    // 입력하면 나타나는 체크 아이콘
                    if (_hasText && !_isLoading)
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_hasText && !_isLoading)
                        ? _handleContinue // ← 변경: 버튼 클릭 시 _handleContinue 실행
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.black.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: _isLoading
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
                        : Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: _hasText
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
