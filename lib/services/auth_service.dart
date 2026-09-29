import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// 로그인 담당
//
// [로그인 방법 두 가지]
//   1) 게스트 - 이메일 없이 바로 시작합니다. 기기에 계정이 남아 있어서 앱을 껐다 켜도 이어집니다.
//      다만 앱을 지우거나 폰을 바꾸면 기록이 사라집니다.
//   2) 이메일 - 어디서든 같은 기록으로 들어올 수 있습니다.
//
// [게스트로 놀다가 이메일로 바꾸는 경우]
//   linkGuestToEmail을 씁니다. 새 계정을 만드는 게 아니라 지금 계정에 이메일을 붙이는 방식이라,
//   userId(uid)가 그대로 유지되고 모아둔 골드/레벨/기록도 그대로 남습니다.
//   (새로 가입해 버리면 uid가 바뀌어서 그동안의 기록을 잃게 됩니다)
//
// [Firebase 콘솔 설정]
//   Authentication > Sign-in method 에서 "익명"과 "이메일/비밀번호"를 켜두어야 합니다.
//   꺼져 있으면 operation-not-allowed 오류가 납니다.
// ============================================================
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 로그인/로그아웃될 때마다 값을 흘려보냅니다. 로그인 안 했으면 null입니다.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // 이메일 없이 게스트로 쓰는 중인지
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  Future<User> signInAsGuest() => _guard(() => _auth.signInAnonymously());

  Future<User> signUpWithEmail(String email, String password) => _guard(
    () => _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  Future<User> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  // 게스트 계정에 이메일을 붙입니다. uid가 그대로라서 기록이 유지됩니다.
  Future<User> linkGuestToEmail(String email, String password) {
    final User? user = _auth.currentUser;
    if (user == null) throw const AuthException('로그인 상태가 아닙니다.');
    if (!user.isAnonymous) throw const AuthException('이미 계정이 연결되어 있습니다.');

    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    return _guard(() => user.linkWithCredential(credential));
  }

  Future<void> signOut() => _auth.signOut();

  // 계정 자체를 없앱니다. Firestore 데이터는 UserRepository가 먼저 지웁니다.
  //
  // 마지막 로그인이 오래됐으면 Firebase가 거절합니다(requires-recent-login).
  // 계정을 지우는 일은 되돌릴 수 없어서, 본인이 맞는지 다시 확인하려는 것입니다.
  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) throw const AuthException('로그인 상태가 아닙니다.');
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const AuthException(
          '보안을 위해 다시 로그인한 뒤에 탈퇴할 수 있습니다.\n'
          '로그아웃했다가 다시 로그인해 주세요.',
        );
      }
      throw AuthException(_messageFor(error.code));
    }
  }

  // 회원가입 화면에서 닉네임을 따로 받지 않으므로 자동으로 지어줍니다.
  // (설정 화면에서 언제든 바꿀 수 있습니다)
  //   이메일이 있으면 앞부분을 쓰고, 게스트면 uid 앞 4글자를 붙여 서로 구분되게 합니다.
  static String defaultNickname({required String uid, String? email}) {
    final String local = (email ?? '').trim().split('@').first;
    if (local.isNotEmpty) return local;
    final String tail = uid.length >= 4 ? uid.substring(0, 4) : uid;
    return '러너$tail';
  }

  // Firebase가 주는 영어 오류 코드를 한국어 문장으로 바꿔서 던집니다.
  Future<User> _guard(Future<UserCredential> Function() action) async {
    try {
      final UserCredential credential = await action();
      final User? user = credential.user;
      if (user == null) throw const AuthException('로그인에 실패했습니다.');
      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageFor(error.code));
    }
  }

  static String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다. 로그인으로 들어와 주세요.';
      case 'credential-already-in-use':
        return '이미 다른 계정에 쓰이고 있는 이메일입니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상으로 정해 주세요.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 맞지 않습니다.';
      case 'user-disabled':
        return '사용이 중지된 계정입니다.';
      case 'network-request-failed':
        return '인터넷 연결을 확인해 주세요.';
      case 'too-many-requests':
        return '시도가 너무 많았습니다. 잠시 후 다시 해주세요.';
      case 'operation-not-allowed':
        // 개발 중에 가장 자주 보게 되는 오류라 무엇을 켜야 하는지까지 적어둡니다.
        return '이 로그인 방식이 꺼져 있습니다. '
            'Firebase 콘솔 > Authentication > Sign-in method에서 켜주세요.';
      default:
        return '로그인에 실패했습니다. ($code)';
    }
  }
}

// 로그인 실패 이유를 화면에 그대로 보여주기 위한 예외
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}
