import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'trash_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // ------------------------------------------------------------
          // 계정 - 닉네임, 비밀번호, 로그아웃, 탈퇴는 "사용자 설정" 안에 모아뒀습니다.
          // ------------------------------------------------------------
          const SettingsSectionHeader(title: '계정'),
          StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, snapshot) {
              final account = AuthService.instance.currentUser;
              final bool isGuest = account?.isAnonymous ?? false;
              final String nickname = snapshot.data?.nickname ?? '-';
              return ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('사용자 설정'),
                subtitle: Text(
                  '$nickname · ${isGuest ? '게스트' : (account?.email ?? '-')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountScreen(userId: widget.userId),
                  ),
                ),
              );
            },
          ),
          const Divider(),

          // ------------------------------------------------------------
          // 기록 관리
          // ------------------------------------------------------------
          const SettingsSectionHeader(title: '기록'),
          StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, snapshot) {
              final UserModel? user = snapshot.data;
              final bool enabled = user?.trashEnabled ?? false;
              return SwitchListTile(
                secondary: const Icon(Icons.delete_outline),
                title: const Text('휴지통 사용'),
                subtitle: Text(
                  enabled ? '삭제한 기록이 휴지통으로 가서 되살릴 수 있어요.' : '삭제하면 바로 지워집니다.',
                ),
                value: enabled,
                onChanged: user == null
                    ? null
                    : (value) => UserRepository.instance.setTrashEnabled(
                        widget.userId,
                        value,
                      ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: const Text('휴지통'),
            // 휴지통을 꺼도 들어갈 수 있게 둡니다. 끄기 전에 버린 것이 남아 있을 수 있어서입니다.
            subtitle: Text(
              '${UserRepository.trashKeepDays}일 동안 보관 · '
              '최대 ${UserRepository.maxTrashedRuns}개',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrashScreen(userId: widget.userId),
              ),
            ),
          ),
          const Divider(),

          // ------------------------------------------------------------
          // 사운드 및 환경 설정 섹션
          // ------------------------------------------------------------
          const SettingsSectionHeader(title: '사운드 설정'),
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
          const SettingsSectionHeader(title: '앱 정보'),
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

// 닉네임 바꾸기 다이얼로그
//
// 입력칸 컨트롤러를 이 위젯이 직접 들고 있다가 dispose에서 버립니다.
// showDialog가 돌려주는 Future는 다이얼로그가 닫히기 시작할 때 이미 끝나는데,
// 닫히는 애니메이션이 도는 동안 TextField는 계속 다시 그려집니다.
// 그래서 바깥에서 컨트롤러를 만들고 Future가 끝나자마자 버리면
// "A TextEditingController was used after being disposed" 오류로 빨간 화면이 뜹니다.
class NicknameDialog extends StatefulWidget {
  final String current;

  const NicknameDialog({super.key, required this.current});

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  static const int maxLength = 12;

  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 빈 이름으로 저장되면 홈 화면에 이름이 사라지므로 막습니다.
  void _submit() {
    final String name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('닉네임 바꾸기'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: '$maxLength자까지'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        // 빈 칸이면 저장 버튼을 눌러도 아무 일이 없도록 아예 잠급니다.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) => TextButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: const Text('저장'),
          ),
        ),
      ],
    );
  }
}

// 섹션 헤더 위젯 (사용자 설정 화면도 같이 씁니다)
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTheme.sans.copyWith(
          fontSize: 14,
          fontWeight: AppTheme.sansMedium,
          color: AppColors.accentDeep,
        ),
      ),
    );
  }
}
