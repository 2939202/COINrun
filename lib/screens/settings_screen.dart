import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userId;

  const SettingsScreen({super.key, required this.userId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 사운드 설정 상태 변수
  // (아직 화면 안에서만 바뀌고 저장되지는 않습니다. 소리를 넣을 때 같이 붙일 예정입니다)
  bool _isBgmEnabled = true;
  bool _isSfxEnabled = true;

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
    if (linked == true) {
      setState(() {}); // 계정 표시를 새로 그립니다.
      _toast('계정이 저장되었습니다. 이제 다른 기기에서도 이어서 할 수 있어요.');
    }
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

  Future<void> _editNickname(String current) async {
    final controller = TextEditingController(text: current);
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('닉네임 바꾸기'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(hintText: '12자까지'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || name == current) return;
    await UserRepository.instance.updateNickname(widget.userId, name);
    _toast('닉네임을 바꿨습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final User? account = AuthService.instance.currentUser;
    final bool isGuest = account?.isAnonymous ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // ------------------------------------------------------------
          // 계정 정보 섹션
          // ------------------------------------------------------------
          const _SectionHeader(title: '계정 정보'),

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
              isGuest ? '이메일을 붙이면 폰을 바꿔도 이어서 할 수 있어요.' : (account?.email ?? '-'),
            ),
            trailing: isGuest
                ? ElevatedButton(
                    onPressed: _linkAccount,
                    child: const Text('계정 저장하기'),
                  )
                : null,
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: _signOut,
          ),
          const Divider(),

          // ------------------------------------------------------------
          // 사운드 및 환경 설정 섹션
          // ------------------------------------------------------------
          const _SectionHeader(title: '사운드 설정'),
          SwitchListTile(
            secondary: const Icon(Icons.music_note),
            title: const Text('배경음악 (BGM)'),
            value: _isBgmEnabled,
            onChanged: (bool value) {
              setState(() {
                _isBgmEnabled = value;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('효과음 (SFX)'),
            value: _isSfxEnabled,
            onChanged: (bool value) {
              setState(() {
                _isSfxEnabled = value;
              });
            },
          ),
          const Divider(),

          // ------------------------------------------------------------
          // 앱 정보 및 서비스 관리 섹션
          // ------------------------------------------------------------
          const _SectionHeader(title: '앱 정보'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('앱 버전'),
            trailing: Text('v1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('이용약관 및 개인정보 처리방침'),
            onTap: () {
              // 약관 모달 또는 웹뷰 연동 위치
            },
          ),
        ],
      ),
    );
  }
}

// 섹션 헤더 위젯
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
