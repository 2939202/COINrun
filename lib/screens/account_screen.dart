import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart' show NicknameDialog, SettingsSectionHeader;

// ============================================================
// 사용자 설정 (설정 > 사용자 설정)
//
// 계정에 관한 것을 한곳에 모았습니다.
//   닉네임 / 계정 종류(게스트면 계정 저장하기) / 비밀번호 바꾸기 / 로그아웃 / 회원 탈퇴
//
// 설정 첫 화면에는 "사용자 설정" 한 줄만 두어서, 자주 안 쓰는 계정 항목이
// 휴지통이나 사운드 같은 설정을 밀어내지 않게 했습니다.
// ============================================================
class AccountScreen extends StatefulWidget {
  final String userId;

  const AccountScreen({super.key, required this.userId});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isDeleting = false; // 탈퇴 처리 중 (화면을 덮어 두 번 누르지 못하게)

  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    widget.userId,
  );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 게스트 계정에 이메일을 붙입니다. uid가 그대로라 기록은 유지됩니다.
  Future<void> _linkAccount() async {
    final bool? linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(mode: AuthMode.link),
      ),
    );
    if (linked != true) return;

    // 이제 게스트가 아니므로 랭킹에 올립니다.
    // (ensureUser가 isGuest 변화를 보고 알아서 처리합니다)
    final account = AuthService.instance.currentUser;
    if (account != null) {
      await UserRepository.instance.ensureUser(
        widget.userId,
        AuthService.defaultNickname(uid: account.uid, email: account.email),
        isGuest: account.isAnonymous,
      );
    }

    if (!mounted) return;
    setState(() {}); // 계정 표시를 새로 그립니다.
    _toast('계정이 저장되었습니다. 이제 랭킹에도 오르고, 다른 기기에서 이어서 할 수 있어요.');
  }

  Future<void> _changePassword() async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
    if (changed == true) _toast('비밀번호를 바꿨습니다.');
  }

  Future<void> _signOut() async {
    final bool isGuest = AuthService.instance.isGuest;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        // 게스트는 로그아웃하면 돌아올 방법이 없어서 미리 알려줍니다.
        content: Text(
          isGuest
              ? '게스트 계정은 로그아웃하면 다시 들어올 수 없어서 '
                    '지금까지 모은 골드와 레벨이 사라집니다.\n'
                    '먼저 "계정 저장하기"로 이메일을 붙여두는 것을 권합니다.'
              : '다음에 같은 이메일로 로그인하면 기록이 그대로 남아 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.instance.signOut();
    // AuthGate가 로그인 화면으로 바꿔주므로, 위에 쌓인 화면만 걷어냅니다.
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // 회원 탈퇴 - 랭킹, 러닝 기록, 유저 문서, 계정 순서로 지웁니다.
  Future<void> _deleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 탈퇴할까요?'),
        content: const Text(
          '지금까지 모은 골드, 레벨, 러닝 기록이 모두 사라집니다.\n'
          '되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      // 데이터를 먼저 지웁니다. 계정을 먼저 지우면 권한이 사라져서
      // 남은 데이터를 지울 수 없게 됩니다.
      await UserRepository.instance.deleteAccountData(widget.userId);
      await AuthService.instance.deleteAccount();
      // AuthGate가 로그인 화면으로 바꿔주므로, 위에 쌓인 화면(설정, 사용자 설정)만 걷어냅니다.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _toast(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _toast('탈퇴에 실패했습니다. 인터넷 연결을 확인해 주세요.');
    }
  }

  Future<void> _editNickname(String current) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => NicknameDialog(current: current),
    );

    if (name == null || name == current) return;
    await UserRepository.instance.updateNickname(widget.userId, name);
    _toast('닉네임을 바꿨습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final User? account = AuthService.instance.currentUser;
    final bool isGuest = account?.isAnonymous ?? false;

    if (_isDeleting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('탈퇴 처리 중입니다...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('사용자 설정')),
      body: ListView(
        children: [
          const SettingsSectionHeader(title: '계정 정보'),

          StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, snapshot) {
              final String nickname = snapshot.data?.nickname ?? '-';
              return ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('닉네임'),
                subtitle: Text(nickname),
                trailing: const Icon(Icons.edit_outlined),
                onTap: snapshot.data == null
                    ? null
                    : () => _editNickname(nickname),
              );
            },
          ),

          ListTile(
            leading: Icon(
              isGuest ? Icons.person_outline : Icons.account_circle,
            ),
            title: Text(isGuest ? '게스트로 이용 중' : '이메일 계정'),
            subtitle: Text(
              isGuest
                  ? '이메일을 붙이면 폰을 바꿔도 이어서 할 수 있어요.'
                  : (account?.email ?? '-'),
            ),
            trailing: isGuest
                ? ElevatedButton(
                    onPressed: _linkAccount,
                    child: const Text('계정 저장하기'),
                  )
                : null,
          ),

          // 게스트는 비밀번호가 없어서 보여주지 않습니다.
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('비밀번호 바꾸기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
            ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: _signOut,
          ),
          ListTile(
            leading: const Icon(
              Icons.person_remove_outlined,
              color: Colors.red,
            ),
            title: const Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
            subtitle: const Text('계정과 기록을 모두 지웁니다'),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}

// 비밀번호 바꾸기 창
//
// 지금 비밀번호 / 새 비밀번호 / 새 비밀번호 확인 세 칸입니다.
// 바꾸는 데 성공하면 true로 닫힙니다.
// 컨트롤러를 이 위젯이 들고 있는 이유는 NicknameDialog 설명과 같습니다.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_current.text.isEmpty) return '지금 비밀번호를 입력해 주세요.';
    if (_next.text.length < 6) return '새 비밀번호는 6자 이상으로 정해 주세요.';
    if (_next.text != _confirm.text) return '새 비밀번호가 서로 다릅니다.';
    if (_next.text == _current.text) return '지금 비밀번호와 다른 비밀번호로 정해 주세요.';
    return null;
  }

  Future<void> _submit() async {
    final String? invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await AuthService.instance.changePassword(_current.text, _next.text);
      if (mounted) Navigator.pop(context, true);
      return;
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '잠시 후 다시 시도해 주세요.');
    }
    if (mounted) setState(() => _isBusy = false);
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        enabled: !_isBusy,
        obscureText: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비밀번호 바꾸기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_current, '지금 비밀번호'),
            _field(_next, '새 비밀번호 (6자 이상)'),
            _field(_confirm, '새 비밀번호 확인'),
            if (_error != null)
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isBusy ? null : _submit,
          child: _isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('바꾸기'),
        ),
      ],
    );
  }
}
