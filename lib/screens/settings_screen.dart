import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/map_tiles.dart';
import 'account_screen.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userId;

  const SettingsScreen({super.key, required this.userId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
          // 앱 정보 및 서비스 관리 섹션
          // ------------------------------------------------------------
          const SettingsSectionHeader(title: '앱 정보'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('앱 버전'),
            trailing: Text('v1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('지도 및 데이터 출처'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => const _CreditsDialog(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('이용약관 및 개인정보 처리방침'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => const _PrivacyDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

// 이용약관 및 개인정보 처리방침 (요약)
//
// 앱이 실제로 하는 일만 적습니다. 바뀌면 이 목록도 같이 고쳐야 합니다.
//   위치: run_screen.dart / location_service.dart
//   공개 범위: firestore.rules (users는 본인만, leaderboard·courses는 로그인한 사람)
//   AI: ai_coach.dart, week_coach.dart (숫자만 보냄)
class _PrivacyDialog extends StatelessWidget {
  const _PrivacyDialog();

  static const List<(String, String)> sections = [
    (
      '모으는 정보',
      '닉네임, 이메일(이메일로 가입한 경우), 러닝 기록(거리·시간·걸음 수·경로·부하도), '
          '레벨과 골드입니다.',
    ),
    (
      '위치',
      '러닝 화면을 연 동안에만 위치를 씁니다. 화면을 꺼도 기록되도록, 달리는 동안에만 '
          '알림을 띄우고 위치를 받습니다. 경로는 본인만 볼 수 있습니다.',
    ),
    (
      '다른 사람에게 보이는 것',
      '랭킹에는 닉네임, 레벨, 누적 거리만 보입니다. 게스트는 랭킹에 오르지 않습니다. '
          '사설 코스를 만들면 그 코스의 경로와 닉네임이 다른 사람에게 보입니다.',
    ),
    (
      'AI 비서',
      '주간·월간 기록에서 계산한 숫자(횟수, 거리, 시간, 페이스, 점수)만 Google Gemini에 '
          '보냅니다. 경로, 닉네임, 이메일은 보내지 않습니다.',
    ),
    (
      '보관과 삭제',
      '러닝 기록은 최근 60개를 보관합니다. 사용자 설정에서 탈퇴하면 기록, 계정 정보, '
          'AI 평가와 목표, 내가 만든 사설 코스가 삭제됩니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('개인정보 처리방침'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (title, body) in sections) ...[
              Text(title, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(body, style: text.bodySmall?.copyWith(height: 1.5)),
              const SizedBox(height: 12),
            ],
            Text(
              '요약본입니다. 정식 출시 전에 전문을 보완합니다.',
              style: text.labelSmall?.copyWith(color: AppColors.label),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

// 지도 및 데이터 출처. 지도 위에는 띄우지 않고 여기에 모아 둡니다.
class _CreditsDialog extends StatelessWidget {
  const _CreditsDialog();

  static const List<(String, String)> credits = [
    ('지도', '${MapTiles.attributionText}\nopenstreetmap.org/copyright (ODbL)'),
    ('당현천 코스 경로', 'OpenStreetMap 데이터 (ODbL)'),
    ('서울 구 경계', '통계청 2013 행정구역 경계\ngithub.com/southkorea/seoul-maps'),
    ('AI 비서', 'Google Gemini (Firebase AI Logic)'),
    ('글꼴', '함렛 Hahmlet (SIL Open Font License), 자연산스'),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('지도 및 데이터 출처'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (title, body) in credits) ...[
              Text(title, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(body, style: text.bodySmall?.copyWith(height: 1.5)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
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
