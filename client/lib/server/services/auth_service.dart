//auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ==========================================
  // 회원가입 (이메일/비밀번호)
  // ==========================================
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // 1. 입력값 검증
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

      // 2. Firebase Auth 회원가입
      print('🟡 A: Firebase Auth 시작');
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      print('🟡 B: Firebase Auth 완료');

      // 3. Firestore에 users 문서 생성
      await _createUserDocument(userCredential.user!.uid, displayName, email);
      print('🟡 C: Firestore 문서 생성 완료');

      print('✓ 회원가입 성공: ${userCredential.user!.uid}');
    } on FirebaseAuthException catch (e) {
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
      throw Exception('오류 발생: $e');
    }
  }

  // ==========================================
  // 로그인 (이메일/비밀번호)
  // ==========================================
  Future<void> signIn({required String email, required String password}) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('이메일과 비밀번호를 입력해주세요');
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      print('✓ 로그인 성공: ${_auth.currentUser!.uid}');
    } on FirebaseAuthException catch (e) {
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
      throw Exception('오류 발생: $e');
    }
  }

  // ==========================================
  // Google 로그인 (신규 가입 + 로그인)
  // ==========================================
  // 반환값: true면 "이번에 처음 가입한 신규 사용자", false면 "기존 사용자 로그인"
  // ← 변경: void에서 bool로 변경. 화면(UI)에서 신규/기존에 따라
  //         다른 화면으로 이동시켜야 하므로 이 정보가 필요합니다.
  Future<bool> signInWithGoogle() async {
    try {
      // 1. Google 로그인
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google 로그인이 취소되었습니다');
      }

      // 2. Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Firebase 인증
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // 4. 새 사용자인지 확인
      bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // 5. 새 사용자면 Firestore에 문서 생성
        String displayName = googleUser.displayName ?? '사용자';
        String email = googleUser.email;

        await _createUserDocument(userCredential.user!.uid, displayName, email);

        print('✓ Google 회원가입 성공: ${userCredential.user!.uid}');
      } else {
        print('✓ Google 로그인 성공: ${userCredential.user!.uid}');
      }

      return isNewUser; // ← 변경: 호출한 쪽(UI)에 결과 전달
    } on FirebaseAuthException catch (e) {
      throw Exception('Google 인증 실패: ${e.message}');
    } catch (e) {
      throw Exception('Google 로그인 오류: $e');
    }
  }

  // ==========================================
  // 로그아웃
  // ==========================================
  Future<void> signOut() async {
    try {
      // Firebase 로그아웃
      await _auth.signOut();

      // Google 로그아웃
      await _googleSignIn.signOut();

      print('✓ 로그아웃 성공');
    } catch (e) {
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
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('사용자 정보 조회 실패: $e');
    }
  }

  // ==========================================
  // displayName 업데이트
  // ==========================================
  Future<void> updateDisplayName(String uid, String newName) async {
    try {
      if (newName.isEmpty) {
        throw Exception('이름을 입력해주세요');
      }

      if (newName.length > 50) {
        throw Exception('이름은 50자 이하여야 합니다');
      }

      await _firestore.collection('users').doc(uid).update({
        'displayName': newName,
        'displayNameLower': newName.toLowerCase(), // ★ 추가: 검색용 소문자 필드
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 이름 업데이트 완료: $newName');
    } catch (e) {
      throw Exception('이름 업데이트 실패: $e');
    }
  }

  // ==========================================
  // 온보딩 완료 처리
  // ==========================================
  // GoalScreen에서 weeklyGoal 저장까지 성공한 직후 호출합니다.
  // 이걸 호출해야만 다음 로그인부터 "온보딩 끝난 사용자"로 인식됩니다.
  Future<void> completeOnboarding(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 온보딩 완료 처리: $uid');
    } catch (e) {
      throw Exception('온보딩 완료 처리 실패: $e');
    }
  }

  // ==========================================
  // 온보딩 완료 여부 확인
  // ==========================================
  // 로그인 성공 직후 이 함수로 확인해서,
  // false면 온보딩 화면으로, true면 홈 화면으로 보내면 됩니다.
  Future<bool> checkOnboardingComplete(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        // 문서가 아예 없다는 건 비정상 상태이므로,
        // 안전하게 "온보딩 안 끝남"으로 취급합니다.
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;

      // 예전에 만들어진 계정(필드 자체가 없는 경우)도 있을 수 있으므로
      // 기본값을 false로 지정해둡니다 (필드 없으면 온보딩 안 된 것으로 간주).
      return data['onboardingComplete'] ?? false;
    } catch (e) {
      throw Exception('온보딩 상태 확인 실패: $e');
    }
  }

  // ==========================================
  // weeklyGoal 업데이트
  // ==========================================
  Future<void> updateWeeklyGoal(String uid, String goal) async {
    try {
      if (!['beginner', 'regular', 'ecoHero'].contains(goal)) {
        throw Exception('올바른 목표 수준을 선택해주세요');
      }

      await _firestore.collection('users').doc(uid).update({
        'weeklyGoal': goal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 주간 목표 업데이트: $goal');
    } catch (e) {
      throw Exception('주간 목표 업데이트 실패: $e');
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
    try {
      // 이미 존재하는지 확인
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        print('✓ 사용자 문서가 이미 존재합니다');
        return;
      }

      // 새 사용자 문서 생성
      await _firestore.collection('users').doc(uid).set({
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(), // ★ 추가: 검색용 소문자 필드
        'email': email,
        'weeklyGoal': 'beginner',
        'character': {
          'level': 1,
          'xp': 0,
          'color': '#FF5733',
          'raise': {'pet': 0, 'feed': 0},
        },
        'reservedHotspotId': null,
        // 온보딩(이름 → username → weeklyGoal 설정)을 끝까지 마쳤는지 여부
        // 회원가입 직후에는 항상 false이며, GoalScreen에서 목표 저장이
        // 성공한 시점에만 completeOnboarding()을 통해 true로 바뀝니다.
        'onboardingComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✓ 사용자 문서 생성됨: $uid');
    } catch (e) {
      print('⚠️ 사용자 문서 생성 오류: $e');
      // 사용자는 이미 인증되었으므로, 문서 생성 실패는 비치명적
    }
  }
}
