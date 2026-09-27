import 'package:flutter/material.dart';

import '../services/app_permissions.dart';
import '../theme/app_theme.dart';

// ============================================================
// 권한 안내 화면
//
// 로그인 직후에 한 번 보여줍니다. 예전에는 러닝 화면에 들어갈 때 물어봤는데,
// 두 권한을 동시에 요청하는 바람에 하나가 씹혀서 "허용을 눌러도 안 먹는" 일이
// 있었습니다. 여기서 하나씩 순서대로 받습니다.
//
// "봤는지" 여부를 따로 저장하지 않고 실제 권한 상태만 봅니다. 그래야 나중에
// 설정에서 권한을 꺼도 다시 안내가 뜨고, 저장해둔 값과 실제가 어긋날 일이 없습니다.
// ============================================================
class PermissionScreen extends StatefulWidget {
  // 권한을 받았거나 사용자가 나중에 하기를 고른 뒤에 부릅니다.
  final VoidCallback onDone;

  const PermissionScreen({super.key, required this.onDone});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isAsking = false;
  bool _deniedForever = false;

  Future<void> _request() async {
    if (_isAsking) return;
    setState(() => _isAsking = true);

    final AppPermissionStatus status = await AppPermissions.request();
    if (!mounted) return;

    if (status.canRecord) {
      widget.onDone();
      return;
    }

    // 위치를 "다시 묻지 않음"으로 거부했으면 앱에서는 더 물어볼 수 없습니다.
    final bool blocked = await AppPermissions.locationDeniedForever();
    if (!mounted) return;
    setState(() {
      _isAsking = false;
      _deniedForever = blocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(
                '시작하기 전에',
                style: textTheme.displayLarge?.copyWith(fontSize: 40),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '달린 만큼 기록하려면 세 가지가 필요해요.',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.grey500),
              ),
              const SizedBox(height: AppSpacing.xl),

              const _Item(
                icon: Icons.location_on_outlined,
                title: '위치',
                body: '달린 거리와 지나온 길을 기록합니다. 이게 없으면 러닝이 기록되지 않아요.',
                required: true,
              ),
              const _Item(
                icon: Icons.directions_walk,
                title: '신체 활동',
                body: '걸음 수를 세서 골드를 줍니다. 없으면 거리로 어림잡아서 골드가 적게 나와요.',
              ),
              const _Item(
                icon: Icons.notifications_none,
                title: '알림',
                body: '화면을 꺼도 계속 기록하려면 필요합니다. 없어도 기록은 되지만 알림이 안 보여요.',
              ),

              if (_deniedForever) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '위치 권한이 "다시 묻지 않음"으로 막혀 있어요.\n'
                  '설정에서 직접 켜주셔야 합니다.',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.red),
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isAsking
                      ? null
                      : (_deniedForever
                            ? AppPermissions.openSettings
                            : _request),
                  child: Text(_deniedForever ? '설정 열기' : '권한 허용하기'),
                ),
              ),
              // 막지는 않습니다. 권한 없이도 앱을 둘러볼 수는 있어야 합니다.
              TextButton(
                onPressed: _isAsking ? null : widget.onDone,
                child: const Text('나중에 하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool required;

  const _Item({
    required this.icon,
    required this.title,
    required this.body,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    if (required) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.volt,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('필수', style: textTheme.labelMedium),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(body, style: textTheme.labelMedium?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
