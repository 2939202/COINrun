import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

// 이 화면이 하는 일 세 가지
enum AuthMode {
  signIn, // 이메일로 로그인
  signUp, // 이메일로 새로 가입
  link; // 게스트 계정에 이메일 붙이기 (기록 유지)

  String get title => switch (this) {
    AuthMode.signIn => '로그인',
    AuthMode.signUp => '회원가입',
    AuthMode.link => '계정 만들기',
  };

  String get submitLabel => switch (this) {
    AuthMode.signIn => '로그인',
    AuthMode.signUp => '가입하고 시작하기',
    AuthMode.link => '이 계정으로 저장하기',
  };
}

// ============================================================
// 로그인 화면
//
// 로그인에 성공하면 따로 화면을 넘기지 않습니다. AuthGate가 로그인 상태를
// 지켜보고 있다가 알아서 홈 화면으로 바꿔줍니다.
// (계정 연결(link)일 때만, 설정 화면으로 돌아가야 해서 직접 닫습니다)
//
// 모양은 아직 다듬지 않았습니다. 디자인 방향이 정해지면 이 파일만 다시 만들면 됩니다.
// ============================================================
class LoginScreen extends StatefulWidget {
  final AuthMode mode;

  const LoginScreen({super.key, this.mode = AuthMode.signIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  late AuthMode _mode = widget.mode;
  bool _isBusy = false;
  String? _error;

  // 계정 연결로 들어왔으면 로그인/가입을 오갈 필요가 없습니다.
  bool get _isLinking => widget.mode == AuthMode.link;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // 서버에 보내기 전에 여기서 걸러낼 수 있는 것은 걸러냅니다.
  String? _validate() {
    final String email = _email.text.trim();
    if (email.isEmpty) return '이메일을 입력해 주세요.';
    if (!email.contains('@')) return '이메일 형식이 올바르지 않습니다.';
    if (_password.text.length < 6) return '비밀번호는 6자 이상으로 정해 주세요.';
    return null;
  }

  Future<void> _submit() async {
    final String? invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    await _run(() async {
      final auth = AuthService.instance;
      final String email = _email.text;
      final String password = _password.text;
      switch (_mode) {
        case AuthMode.signIn:
          await auth.signInWithEmail(email, password);
        case AuthMode.signUp:
          await auth.signUpWithEmail(email, password);
        case AuthMode.link:
          await auth.linkGuestToEmail(email, password);
          if (mounted) Navigator.pop(context, true);
      }
    });
  }

  Future<void> _startAsGuest() =>
      _run(() => AuthService.instance.signInAsGuest());

  // 로그인 칸에 적어둔 이메일을 그대로 들고 갑니다. 다시 칠 필요가 없게요.
  Future<void> _forgotPassword() async {
    final bool? sent = await showDialog<bool>(
      context: context,
      builder: (context) => PasswordResetDialog(initialEmail: _email.text),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('가입된 이메일이면 비밀번호 재설정 메일이 갑니다. 받은편지함(스팸함까지) 확인해 주세요.'),
        ),
      );
    }
  }

  // 버튼 잠그기 + 오류 메시지 처리를 한곳에서 합니다.
  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
      // 성공하면 AuthGate가 화면을 바꾸므로 여기서 할 일이 없습니다.
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '잠시 후 다시 시도해 주세요.');
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: _isLinking ? AppBar(title: Text(_mode.title)) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (!_isLinking) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                '코인런',
                style: textTheme.displayLarge?.copyWith(fontSize: 56),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '달린 만큼 강해지는 나만의 캐릭터',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.mute),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            if (_isLinking) ...[
              Text(
                '지금까지 모은 골드와 레벨은 그대로 두고, '
                '이메일만 붙여둡니다. 폰을 바꿔도 이어서 할 수 있어요.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            TextField(
              controller: _email,
              enabled: !_isBusy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _password,
              enabled: !_isBusy,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '비밀번호 (6자 이상)',
                border: OutlineInputBorder(),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isBusy ? null : _submit,
                child: Text(_mode.submitLabel),
              ),
            ),

            if (_mode == AuthMode.signIn)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isBusy ? null : _forgotPassword,
                  child: const Text('비밀번호를 잊으셨나요?'),
                ),
              ),

            if (!_isLinking) ...[
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () => setState(() {
                        _mode = _mode == AuthMode.signIn
                            ? AuthMode.signUp
                            : AuthMode.signIn;
                        _error = null;
                      }),
                child: Text(
                  _mode == AuthMode.signIn
                      ? '계정이 없으신가요? 회원가입'
                      : '이미 계정이 있으신가요? 로그인',
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: _isBusy ? null : _startAsGuest,
                  child: const Text('가입 없이 게스트로 시작하기'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '게스트로 시작해도 나중에 설정에서 이메일을 붙일 수 있어요. '
                '그때 기록은 그대로 남습니다. '
                '다만 이메일을 붙이기 전에 앱을 지우면 기록이 사라집니다.',
                style: textTheme.labelMedium?.copyWith(color: AppColors.mute),
              ),
            ],

            if (_isBusy) ...[
              const SizedBox(height: AppSpacing.lg),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

// 비밀번호 찾기 창
//
// 링크가 든 메일을 보내고, 사용자는 메일의 링크에서 새 비밀번호를 정합니다.
// (앱 안에서 새 비밀번호를 받지 않습니다. 본인 메일함에 들어갈 수 있어야 본인이 맞다고 보는 방식입니다)
// 보내는 데 성공하면 true로 닫힙니다.
class PasswordResetDialog extends StatefulWidget {
  final String initialEmail;

  const PasswordResetDialog({super.key, this.initialEmail = ''});

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail.trim(),
  );

  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '이메일을 입력해 주세요.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = '이메일 형식이 올바르지 않습니다.');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) Navigator.pop(context, true);
      return;
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '잠시 후 다시 시도해 주세요.');
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('비밀번호 찾기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '가입한 이메일을 적어주세요. 새 비밀번호를 정하는 링크를 보내드려요.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _email,
            enabled: !_isBusy,
            autofocus: widget.initialEmail.trim().isEmpty,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              labelText: '이메일',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isBusy ? null : _send,
          child: _isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('메일 보내기'),
        ),
      ],
    );
  }
}
