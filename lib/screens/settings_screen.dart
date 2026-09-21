import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 사운드 설정 상태 변수
  bool _isBgmEnabled = true;
  bool _isSfxEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // ------------------------------------------------------------
          // 계정 정보 섹션
          // ------------------------------------------------------------
          const _SectionHeader(title: '계정 정보'),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('계정 로그인'),
            subtitle: const Text('구글 / 게스트 로그인 상태'),
            trailing: ElevatedButton(
              onPressed: () {
                // 로그인/로그아웃 로직 연결 위치
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('로그인 기능 준비 중입니다.')),
                );
              },
              child: const Text('로그아웃'),
            ),
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
