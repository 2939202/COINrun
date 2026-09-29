import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../services/app_permissions.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'permission_screen.dart';

// ============================================================
// 로그인 상태에 따라 보여줄 화면을 고르는 문지기
//
//   로그인 안 됨 -> 로그인 화면
//   로그인 됨   -> 유저 문서를 확인/생성한 뒤 홈 화면
//
// 앱을 껐다 켜도 Firebase가 로그인 상태를 기억하고 있어서, 두 번째부터는
// 로그인 화면을 거치지 않고 바로 홈으로 들어갑니다.
// ============================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        final User? account = snapshot.data;
        if (account == null) return const LoginScreen();

        return _UserDocGate(account: account);
      },
    );
  }
}

// 로그인은 됐지만 Firestore에 유저 문서가 아직 없을 수 있어서(첫 로그인),
// 홈으로 넘어가기 전에 한 번 만들어 둡니다.
class _UserDocGate extends StatefulWidget {
  final User account;

  const _UserDocGate({required this.account});

  @override
  State<_UserDocGate> createState() => _UserDocGateState();
}

class _UserDocGateState extends State<_UserDocGate> {
  late Future<void> _ready = _prepare();

  @override
  void didUpdateWidget(_UserDocGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 계정으로 갈아탔으면 그 계정 문서를 다시 확인합니다.
    if (oldWidget.account.uid != widget.account.uid) {
      _ready = _prepare();
    }
  }

  Future<void> _prepare() => UserRepository.instance.ensureUser(
    widget.account.uid,
    AuthService.defaultNickname(
      uid: widget.account.uid,
      email: widget.account.email,
    ),
    // 게스트는 랭킹에 올리지 않습니다. 나중에 이메일을 붙이면 여기서 false가 되고
    // 그때부터 랭킹에 들어갑니다.
    isGuest: widget.account.isAnonymous,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return _PrepareFailed(
            onRetry: () => setState(() => _ready = _prepare()),
          );
        }
        // 홈으로 보내기 전에 권한을 한 번 받습니다.
        return _PermissionGate(userId: widget.account.uid);
      },
    );
  }
}

// 권한이 갖춰졌는지 보고, 모자라면 안내 화면을 한 번 보여줍니다.
//
// 러닝 화면에서 물어보지 않고 여기서 받는 이유: 러닝 화면은 들어가자마자 GPS와
// 걸음 센서를 함께 켜는데, 그 자리에서 두 권한을 동시에 요청하면 하나가 씹힙니다.
class _PermissionGate extends StatefulWidget {
  final String userId;

  const _PermissionGate({required this.userId});

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  late Future<AppPermissionStatus> _status = AppPermissions.check();

  // 사용자가 "나중에 하기"를 골랐으면 이번 실행 동안은 다시 묻지 않습니다.
  bool _skipped = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppPermissionStatus>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        final AppPermissionStatus? status = snapshot.data;
        // 권한 상태를 못 읽었으면 막지 않고 들여보냅니다.
        final bool ready = _skipped || status == null || status.allGranted;
        if (ready) return MainScreen(userId: widget.userId);

        return PermissionScreen(
          onDone: () => setState(() {
            _skipped = true;
            _status = AppPermissions.check();
          }),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// 첫 로그인 때 인터넷이 끊겨 유저 문서를 만들지 못한 경우
class _PrepareFailed extends StatelessWidget {
  final VoidCallback onRetry;

  const _PrepareFailed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '내 정보를 불러오지 못했습니다.\n인터넷 연결을 확인해 주세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
            TextButton(
              onPressed: AuthService.instance.signOut,
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
