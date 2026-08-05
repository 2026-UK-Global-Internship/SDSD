import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User; // ★ User 제외
import '../../server/services/hotspots_service.dart';
import '../../server/services/flogging_service.dart';
import '../../server/services/character_service.dart';
import '../../server/services/friendship_service.dart';
import '../../server/services/auth_service.dart';

class FullIntegrationTestScreen extends StatefulWidget {
  const FullIntegrationTestScreen({Key? key}) : super(key: key);

  @override
  State<FullIntegrationTestScreen> createState() =>
      _FullIntegrationTestScreenState();
}

class _FullIntegrationTestScreenState extends State<FullIntegrationTestScreen> {
  // ★ Supabase 클라이언트 - 나중에 초기화
  late HotspotService _hotspotService;
  late FloggingService _floggingService;
  final CharacterService _characterService = CharacterService();
  final FriendshipService _friendshipService = FriendshipService();
  final AuthService _authService = AuthService();

  // 테스트 화면 안에서 바로 로그인하기 위한 입력 필드
  final _loginEmailController = TextEditingController(text: 'test@example.com');
  final _loginPasswordController = TextEditingController(text: 'password123');

  static const double _testLat = 37.5665;
  static const double _testLng = 126.9780;

  String? _hotspotId;
  String _hotspotStatus = '없음';
  String? _floggingId;
  String? _searchedTargetUid;

  Uint8List? _selectedPhotoBytes;
  String? _lastUploadedPhotoUrl;

  final _searchController = TextEditingController(text: 'test');
  final _crewSizeController = TextEditingController(text: 'duo');
  final _descriptionController = TextEditingController(
    text: '테스트 장소 - 공원 벤치 옆',
  );

  String _log = '테스트 대기 중...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ★ Supabase 초기화 후 service 생성
    _initializeServices();
  }

  /// ★ Supabase가 준비되면 service 생성
  void _initializeServices() {
    try {
      final supabase = Supabase.instance.client;
      _hotspotService = HotspotService(supabase);
      _floggingService = FloggingService(supabase);
      _print('✓ Service 초기화 완료');
    } catch (e) {
      _print('✗ Service 초기화 실패: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _crewSizeController.dispose();
    _descriptionController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  String get _uid {
    final u = FirebaseAuth.instance.currentUser?.uid;
    if (u == null) throw Exception('로그인이 필요합니다');
    return u;
  }

  void _print(String msg) => setState(() => _log = msg);

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      _snack('성공', Colors.green);
    } catch (e) {
      _print('✗ 오류\n$e');
      _snack('오류: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 사진 선택 (갤러리에서 실제 이미지 하나 고르기)
  // ==========================================
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedPhotoBytes = bytes;
    });
    _print(
      '✓ 사진 선택됨 (${(bytes.length / 1024).toStringAsFixed(1)} KB)\n'
      '아래 A1(신고) 또는 B2(청소연결)에서 이 사진이 함께 업로드됩니다',
    );
  }

  // ==========================================
  // 테스트 화면 안에서 바로 로그인/회원가입
  // ==========================================
  Future<void> _testLogin() async {
    await _run(() async {
      await _authService.signIn(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
      _print('✓ 로그인 성공: ${_loginEmailController.text}');
    });
  }

  Future<void> _testSignUp() async {
    await _run(() async {
      await _authService.signUp(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
        displayName: 'IntegrationTester',
      );
      _print('✓ 회원가입 성공: ${_loginEmailController.text}');
    });
  }

  Future<void> _testLogout() async {
    await _run(() async {
      await _authService.signOut();
      _print('로그아웃됨');
    });
  }

  // ==========================================
  // A. Hotspot
  // ==========================================
  Future<void> _a1_report() async {
    await _run(() async {
      final id = await _hotspotService.reportHotspot(
        latitude: _testLat,
        longitude: _testLng,
        trashType: 'plastic',
        locationDescription: _descriptionController.text,
        crewSize: _crewSizeController.text,
        photoBytes: _selectedPhotoBytes,
      );
      setState(() => _hotspotId = id);

      final saved = await _hotspotService.getHotspotById(id);
      setState(() {
        _hotspotStatus = 'open';
        _lastUploadedPhotoUrl = saved['photoUrl'] as String?;
      });

      _print(
        '✓ [A1] 신고 완료\nid: $id\n'
        'crewSize: ${_crewSizeController.text}\n'
        'description: ${_descriptionController.text}\n'
        'photoUrl: ${saved['photoUrl'] ?? "(사진 없음)"}',
      );
    });
  }

  Future<void> _a2_reserve() async {
    if (_hotspotId == null) return;
    await _run(() async {
      await _hotspotService.reserveHotspot(_hotspotId!);
      setState(() => _hotspotStatus = 'reserved');
      _print('✓ [A2] 예약 완료\nstatus: reserved');
    });
  }

  Future<void> _a3_complete() async {
    if (_hotspotId == null) return;
    await _run(() async {
      final result = await _hotspotService.completeCleaning(_hotspotId!);
      setState(() => _hotspotStatus = 'cleaned');
      _print(
        '✓ [A3] 청소 완료\n'
        '쓰다듬기 기회 +${result['petChanceGranted']}개 지급됨',
      );
    });
  }

  Future<void> _a4_deleteShouldFail() async {
    if (_hotspotId == null) return;
    await _run(() async {
      await _hotspotService.deleteHotspot(_hotspotId!);
      _print('⚠️ 예상과 다르게 삭제가 성공했습니다! (cleaned 상태인데 삭제됨 → 버그 의심)');
    });
  }

  Future<void> _a5_mapQuery() async {
    await _run(() async {
      final results = await _hotspotService.getHotspotsForMap(
        swLat: _testLat - 0.05,
        swLng: _testLng - 0.05,
        neLat: _testLat + 0.05,
        neLng: _testLng + 0.05,
        onlyOpen: false,
      );
      _print(
        '✓ [A5] 지도 영역 조회 결과: ${results.length}개\n'
        '(방금 만든 hotspot이 포함되어 있어야 정상)',
      );
    });
  }

  // ==========================================
  // B. Flogging
  // ==========================================
  Future<void> _b1_save() async {
    await _run(() async {
      final result = await _floggingService.saveFloggingRecord(
        startedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        startLatitude: _testLat,
        startLongitude: _testLng,
        calorie: 150,
        steps: 3000,
        routePolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      );
      setState(() => _floggingId = result['floggingId'] as String);
      _print(
        '✓ [B1] 조깅 기록 저장\nfloggingId: ${result['floggingId']}\n'
        'XP +${result['xpGained']} (Lv.${result['newLevel']})',
      );
    });
  }

  Future<void> _b2_recordCleanup() async {
    if (_floggingId == null || _hotspotId == null) return;
    await _run(() async {
      await _floggingService.recordCleanup(
        floggingId: _floggingId!,
        hotspotId: _hotspotId!,
        photoBytes: _selectedPhotoBytes,
      );

      final saved = await _floggingService.getFloggingById(_floggingId!);
      final cleanup = saved['cleanup'] as Map<String, dynamic>?;
      setState(() {
        _lastUploadedPhotoUrl = cleanup?['photoUrl'] as String?;
      });

      _print(
        '✓ [B2] 청소 정보 연결 완료 (flogging ↔ hotspot)\n'
        'cleanup.photoUrl: ${cleanup?['photoUrl'] ?? "(사진 없음)"}',
      );
    });
  }

  Future<void> _b3_history() async {
    await _run(() async {
      final list = await _floggingService.getUserFloggingHistory(limit: 5);
      _print('✓ [B3] 최근 조깅 기록 ${list.length}건 조회됨');
    });
  }

  // ==========================================
  // C. Character
  // ==========================================
  Future<void> _c1_status() async {
    await _run(() async {
      final s = await _characterService.getCharacterStatus(_uid);
      final minsLeft = (s['secondsUntilNextFeed'] as int) ~/ 60;
      _print(
        '📊 캐릭터 상태\n'
        'Lv.${s['level']} / XP ${s['xp']}\n'
        'pet 기회: ${s['petChances']} / feed 기회: ${s['feedChances']}\n'
        '다음 먹이 충전까지: 약 $minsLeft분',
      );
    });
  }

  Future<void> _c2_pet() async {
    await _run(() async {
      final r = await _characterService.petCharacter(_uid);
      _print(
        '✓ [C2] 쓰다듬기 성공\n'
        '남은 pet 기회: ${r['remainingPetChances']}, +${r['xpGained']} XP',
      );
    });
  }

  Future<void> _c3_feed() async {
    await _run(() async {
      final r = await _characterService.feedCharacter(_uid);
      _print(
        '✓ [C3] 먹이주기 성공\n'
        '남은 feed 기회: ${r['remainingFeedChances']}, +${r['xpGained']} XP',
      );
    });
  }

  Future<void> _c4_color() async {
    await _run(() async {
      await _characterService.updateCharacterColor(_uid, '#00CC66');
      _print('✓ [C4] 캐릭터 색상 변경 완료 (#00CC66)');
    });
  }

  // ==========================================
  // D. Friendship
  // ==========================================
  Future<void> _d1_search() async {
    await _run(() async {
      final results = await _friendshipService.searchUsersByName(
        _searchController.text,
      );
      if (results.isNotEmpty) {
        _searchedTargetUid = results.first['uid'] as String;
      }
      _print(
        '✓ [D1] 검색 결과 ${results.length}건\n'
        '${results.take(3).map((r) => r['displayName']).join(', ')}\n'
        '${_searchedTargetUid != null ? "첫 번째 결과를 대상으로 지정: $_searchedTargetUid" : "검색된 사용자 없음"}',
      );
    });
  }

  Future<void> _d2_sendRequest() async {
    if (_searchedTargetUid == null) {
      _snack('먼저 검색해서 대상 사용자를 찾아주세요', Colors.orange);
      return;
    }
    await _run(() async {
      await _friendshipService.sendFriendRequest(_searchedTargetUid!);
      _print(
        '✓ [D2] 친구 요청 전송 완료 → $_searchedTargetUid\n'
        '(수락 테스트는 다른 계정으로 로그인해서 확인해야 함)',
      );
    });
  }

  Future<void> _d3_myFriends() async {
    await _run(() async {
      final list = await _friendshipService.getMyFriends();
      final outgoing = await _friendshipService.getOutgoingRequests();
      _print('✓ [D3] 내 친구: ${list.length}명 / 보낸 요청: ${outgoing.length}건');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🧪 전체 기능 통합 테스트')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final loggedIn = snapshot.data != null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[200],
                  child: Text(
                    _log,
                    style: const TextStyle(fontFamily: 'Courier'),
                  ),
                ),
                const SizedBox(height: 16),

                // ==========================================
                // 로그인 상태 분기
                // ==========================================
                if (!loggedIn) ...[
                  const Text(
                    '🔐 로그인이 필요합니다 (테스트용 간단 로그인)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _loginEmailController,
                    decoration: const InputDecoration(labelText: '이메일'),
                  ),
                  TextField(
                    controller: _loginPasswordController,
                    decoration: const InputDecoration(labelText: '비밀번호'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _testLogin,
                    child: const Text('로그인'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _testSignUp,
                    child: const Text('회원가입 (계정 없으면)'),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '✅ 로그인됨: ${FirebaseAuth.instance.currentUser?.email}',
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _testLogout,
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._buildTestContent(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 로그인된 상태에서만 보여줄 실제 테스트 버튼들
  // ==========================================
  List<Widget> _buildTestContent() {
    return [
      TextField(
        controller: _descriptionController,
        decoration: const InputDecoration(labelText: '장소 설명 (Hotspot)'),
      ),
      TextField(
        controller: _crewSizeController,
        decoration: const InputDecoration(
          labelText: '인원 규모 (solo/duo/squad/more)',
        ),
      ),
      TextField(
        controller: _searchController,
        decoration: const InputDecoration(labelText: '친구 검색어 (닉네임)'),
      ),
      const SizedBox(height: 12),

      // ==========================================
      // 사진 선택 / 미리보기 / 업로드 결과 확인
      // ==========================================
      ElevatedButton.icon(
        onPressed: _isLoading ? null : _pickPhoto,
        icon: const Icon(Icons.photo_library),
        label: const Text('사진 선택 (Hotspot 신고 + 청소완료 사진에 재사용)'),
      ),
      if (_selectedPhotoBytes != null) ...[
        const SizedBox(height: 8),
        const Text('선택한 사진 미리보기:'),
        Image.memory(_selectedPhotoBytes!, height: 120),
      ],
      if (_lastUploadedPhotoUrl != null &&
          _lastUploadedPhotoUrl!.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('✅ Supabase에 실제 업로드된 사진 (URL로 직접 불러온 것):'),
        Image.network(
          _lastUploadedPhotoUrl!,
          height: 120,
          errorBuilder: (_, __, ___) =>
              const Text('⚠️ URL로 이미지를 불러오지 못했습니다 (버킷 Public 설정 확인 필요)'),
        ),
        Text(_lastUploadedPhotoUrl!, style: const TextStyle(fontSize: 10)),
      ],
      const SizedBox(height: 20),

      const Text('🅰️ Hotspot', style: TextStyle(fontWeight: FontWeight.bold)),
      ElevatedButton(
        onPressed: _isLoading ? null : _a1_report,
        child: const Text('1. 신고'),
      ),
      ElevatedButton(
        onPressed: (_isLoading || _hotspotId == null) ? null : _a2_reserve,
        child: const Text('2. 예약'),
      ),
      ElevatedButton(
        onPressed: (_isLoading || _hotspotStatus != 'reserved')
            ? null
            : _a3_complete,
        child: const Text('3. 청소완료'),
      ),
      ElevatedButton(
        onPressed: (_isLoading || _hotspotId == null)
            ? null
            : _a4_deleteShouldFail,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('4. (실패해야 정상) cleaned 상태 삭제 시도'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _a5_mapQuery,
        child: const Text('5. 지도 영역 조회'),
      ),

      const SizedBox(height: 20),
      const Text('🅱️ Flogging', style: TextStyle(fontWeight: FontWeight.bold)),
      ElevatedButton(
        onPressed: _isLoading ? null : _b1_save,
        child: const Text('1. 조깅 기록 저장'),
      ),
      ElevatedButton(
        onPressed: (_isLoading || _floggingId == null || _hotspotId == null)
            ? null
            : _b2_recordCleanup,
        child: const Text('2. 청소 정보 연결'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _b3_history,
        child: const Text('3. 기록 히스토리 조회'),
      ),

      const SizedBox(height: 20),
      const Text(
        '🅲️ Character',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _c1_status,
        child: const Text('1. 상태 조회'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _c2_pet,
        child: const Text('2. 쓰다듬기'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _c3_feed,
        child: const Text('3. 먹이주기'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _c4_color,
        child: const Text('4. 색상 변경'),
      ),

      const SizedBox(height: 20),
      const Text(
        '🅳️ Friendship',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _d1_search,
        child: const Text('1. 사용자 검색'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _d2_sendRequest,
        child: const Text('2. 친구 요청 보내기'),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _d3_myFriends,
        child: const Text('3. 내 친구/보낸요청 조회'),
      ),
      const SizedBox(height: 24),
    ];
  }
}
