//auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  void _log(String msg) => print('[AuthService] $msg');

  // ==========================================
  // 회원가입 (이메일/비밀번호)
  // ==========================================
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final sw = Stopwatch()..start();
    _log('🔵 signUp 시작 (email=$email)');
    try {
      if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
        throw Exception('모든 필드를 입력해주세요');
      }
      if (password.length < 8) {
        throw Exception('비밀번호는 8자 이상이어야 합니다');
      }
      if (!email.contains('@')) {
        throw Exception('올바른 이메일 주소를 입력해주세요');
      }
      if (displayName.length > 50) {
        throw Exception('이름은 50자 이하여야 합니다');
      }
      _log('  → 입력값 검증 완료 (${sw.elapsedMilliseconds}ms)');

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      _log('  → Firebase Auth 계정 생성 완료 (${sw.elapsedMilliseconds}ms)');

      await _createUserDocument(userCredential.user!.uid, displayName, email);
      _log('  → Firestore 사용자 문서 생성 완료 (${sw.elapsedMilliseconds}ms)');

      _log(
        '✅ signUp 성공: ${userCredential.user!.uid} (총 ${sw.elapsedMilliseconds}ms)',
      );
    } on FirebaseAuthException catch (e) {
      _log(
        '❌ signUp 실패 (FirebaseAuthException: ${e.code}, ${sw.elapsedMilliseconds}ms)',
      );
      if (e.code == 'email-already-in-use') {
        throw Exception('이미 사용 중인 이메일입니다');
      } else if (e.code == 'weak-password') {
        throw Exception('비밀번호가 너무 약합니다');
      } else if (e.code == 'invalid-email') {
        throw Exception('올바른 이메일 형식이 아닙니다');
      } else {
        throw Exception('회원가입 실패: ${e.message}');
      }
    } catch (e) {
      _log('❌ signUp 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('오류 발생: $e');
    }
  }

  // ==========================================
  // 로그인 (이메일/비밀번호)
  // ==========================================
  Future<void> signIn({required String email, required String password}) async {
    final sw = Stopwatch()..start();
    _log('🔵 signIn 시작 (email=$email)');
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('이메일과 비밀번호를 입력해주세요');
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _log(
        '✅ signIn 성공: ${_auth.currentUser!.uid} (${sw.elapsedMilliseconds}ms)',
      );
    } on FirebaseAuthException catch (e) {
      _log(
        '❌ signIn 실패 (FirebaseAuthException: ${e.code}, ${sw.elapsedMilliseconds}ms)',
      );
      if (e.code == 'user-not-found') {
        throw Exception('가입되지 않은 이메일입니다');
      } else if (e.code == 'wrong-password') {
        throw Exception('비밀번호가 틀렸습니다');
      } else if (e.code == 'invalid-email') {
        throw Exception('올바른 이메일 형식이 아닙니다');
      } else {
        throw Exception('로그인 실패: ${e.message}');
      }
    } catch (e) {
      _log('❌ signIn 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('오류 발생: $e');
    }
  }

  // ==========================================
  // Google 로그인 (신규 가입 + 로그인)
  // ==========================================
  Future<bool> signInWithGoogle() async {
    final sw = Stopwatch()..start();
    _log('🔵 signInWithGoogle 시작');
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      _log('  → Google 계정 선택 완료 (${sw.elapsedMilliseconds}ms)');

      if (googleUser == null) {
        throw Exception('Google 로그인이 취소되었습니다');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      _log('  → Google 인증 토큰 획득 완료 (${sw.elapsedMilliseconds}ms)');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      _log('  → Firebase Auth 인증 완료 (${sw.elapsedMilliseconds}ms)');

      bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      _log('  → 신규 사용자 여부: $isNewUser (${sw.elapsedMilliseconds}ms)');

      if (isNewUser) {
        String displayName = googleUser.displayName ?? '사용자';
        String email = googleUser.email;

        await _createUserDocument(userCredential.user!.uid, displayName, email);
        _log('  → Firestore 사용자 문서 생성 완료 (${sw.elapsedMilliseconds}ms)');
      }

      _log(
        '✅ signInWithGoogle 성공: ${userCredential.user!.uid} (총 ${sw.elapsedMilliseconds}ms)',
      );
      return isNewUser;
    } on FirebaseAuthException catch (e) {
      _log(
        '❌ signInWithGoogle 실패 (FirebaseAuthException: ${e.code}, ${sw.elapsedMilliseconds}ms)',
      );
      throw Exception('Google 인증 실패: ${e.message}');
    } catch (e) {
      _log('❌ signInWithGoogle 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('Google 로그인 오류: $e');
    }
  }

  // ==========================================
  // 로그아웃
  // ==========================================
  Future<void> signOut() async {
    final sw = Stopwatch()..start();
    _log('🔵 signOut 시작');
    try {
      await _auth.signOut();
      _log('  → Firebase 로그아웃 완료 (${sw.elapsedMilliseconds}ms)');

      await _googleSignIn.signOut();
      _log('✅ signOut 성공 (총 ${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ signOut 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('로그아웃 실패: $e');
    }
  }

  // ==========================================
  // 현재 사용자 정보
  // ==========================================
  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  bool get isLoggedIn => _auth.currentUser != null;

  // ==========================================
  // 사용자 정보 조회
  // ==========================================
  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    final sw = Stopwatch()..start();
    _log('🔵 getUserProfile 시작 (uid=$uid)');
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      _log('  → Firestore 문서 조회 완료 (${sw.elapsedMilliseconds}ms)');

      if (!doc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      _log('✅ getUserProfile 성공 (총 ${sw.elapsedMilliseconds}ms)');
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      _log('❌ getUserProfile 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('사용자 정보 조회 실패: $e');
    }
  }

  // ==========================================
  // displayName 업데이트
  // ==========================================
  Future<void> updateDisplayName(String uid, String newName) async {
    final sw = Stopwatch()..start();
    _log('🔵 updateDisplayName 시작 (uid=$uid, newName=$newName)');
    try {
      if (newName.isEmpty) {
        throw Exception('이름을 입력해주세요');
      }
      if (newName.length > 50) {
        throw Exception('이름은 50자 이하여야 합니다');
      }

      await _firestore.collection('users').doc(uid).update({
        'displayName': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('✅ updateDisplayName 성공 (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ updateDisplayName 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('이름 업데이트 실패: $e');
    }
  }

  // ==========================================
  // 온보딩 완료 처리
  // ==========================================
  Future<void> completeOnboarding(String uid) async {
    final sw = Stopwatch()..start();
    _log('🔵 completeOnboarding 시작 (uid=$uid)');
    try {
      await _firestore.collection('users').doc(uid).update({
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('✅ completeOnboarding 성공 (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ completeOnboarding 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('온보딩 완료 처리 실패: $e');
    }
  }

  // ==========================================
  // 온보딩 완료 여부 확인
  // ==========================================
  Future<bool> checkOnboardingComplete(String uid) async {
    final sw = Stopwatch()..start();
    _log('🔵 checkOnboardingComplete 시작 (uid=$uid)');
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      _log('  → Firestore 문서 조회 완료 (${sw.elapsedMilliseconds}ms)');

      if (!doc.exists) {
        _log('  → 문서 없음, false 반환 (${sw.elapsedMilliseconds}ms)');
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final result = data['onboardingComplete'] ?? false;
      _log(
        '✅ checkOnboardingComplete 성공: $result (총 ${sw.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _log('❌ checkOnboardingComplete 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('온보딩 상태 확인 실패: $e');
    }
  }

  // ==========================================
  // weeklyGoal 업데이트
  // ==========================================
  Future<void> updateWeeklyGoal(String uid, String goal) async {
    final sw = Stopwatch()..start();
    _log('🔵 updateWeeklyGoal 시작 (uid=$uid, goal=$goal)');
    try {
      if (!['beginner', 'regular', 'ecoHero'].contains(goal)) {
        throw Exception('올바른 목표 수준을 선택해주세요');
      }

      await _firestore.collection('users').doc(uid).update({
        'weeklyGoal': goal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('✅ updateWeeklyGoal 성공 (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ updateWeeklyGoal 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('주간 목표 업데이트 실패: $e');
    }
  }

  // ==========================================
  // 캐릭터 색상 변경
  // ==========================================
  Future<void> updateCharacterColor(String uid, String color) async {
    final sw = Stopwatch()..start();
    _log('🔵 updateCharacterColor 시작 (uid=$uid, color=$color)');
    try {
      if (!color.startsWith('#') || color.length != 7) {
        throw Exception('올바른 HEX 색상을 입력해주세요 (예: #FF5733)');
      }

      await _firestore.collection('users').doc(uid).update({
        'character.color': color,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('✅ updateCharacterColor 성공 (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log('❌ updateCharacterColor 실패: $e (${sw.elapsedMilliseconds}ms)');
      throw Exception('색상 변경 실패: $e');
    }
  }

  // ==========================================
  // 비공개 헬퍼 함수: Users 문서 생성
  // ==========================================
  Future<void> _createUserDocument(
    String uid,
    String displayName,
    String email,
  ) async {
    final sw = Stopwatch()..start();
    _log('  🔵 _createUserDocument 시작 (uid=$uid)');
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      _log('    → 기존 문서 확인 완료 (${sw.elapsedMilliseconds}ms)');

      if (docSnapshot.exists) {
        _log('    → 이미 존재, 생성 건너뜀 (${sw.elapsedMilliseconds}ms)');
        return;
      }

      await _firestore.collection('users').doc(uid).set({
        'displayName': displayName,
        'email': email,
        'weeklyGoal': 'beginner',
        'character': {
          'level': 1,
          'xp': 0,
          'color': '#FF5733',
          'raise': {'pet': 0, 'feed': 0},
        },
        'reservedHotspotId': null,
        'onboardingComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('  ✅ _createUserDocument 성공 (${sw.elapsedMilliseconds}ms)');
    } catch (e) {
      _log(
        '  ❌ _createUserDocument 실패 (비치명적, 계속 진행): $e (${sw.elapsedMilliseconds}ms)',
      );
    }
  }
}
