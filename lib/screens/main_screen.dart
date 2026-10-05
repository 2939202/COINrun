import 'package:flutter/material.dart';

import '../models/run_log.dart';
import '../models/user_model.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/home_widgets.dart';
import '../widgets/notched_box.dart';
import '../widgets/run_log_tile.dart';
import 'profile_screen.dart'; //프로필
import 'ranking_screen.dart'; //랭킹
import 'run_detail_screen.dart'; //러닝 기록 상세
import 'run_history_screen.dart'; //전체 기록
import 'run_screen.dart'; //달리기 시작
import 'settings_screen.dart'; //설정

// ============================================================
// 홈 화면
//   인사 -> 레벨 카드 -> 누적 기록 -> 캐릭터/랭킹 -> 최근 러닝(1개)
//   최근 러닝은 1개만 보여줘서 홈 화면이 거의 스크롤 없이 한 화면에 들어오게 합니다.
//   나머지는 "전체 기록"에서 봅니다.
//   화면 맨 아래에는 "러닝 시작" 버튼이 항상 고정되어 있습니다.
// ============================================================
class MainScreen extends StatefulWidget {
  final String userId;

  const MainScreen({super.key, required this.userId});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String get _userId => widget.userId; //로그인한 계정의 uid

  // 스트림은 한 번만 만들어 둡니다. (build 안에서 만들면 다시 그릴 때마다 새로 연결됨)
  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    _userId,
  );
  late final Stream<List<RunLog>> _recentRunsStream = UserRepository.instance
      .watchRecentRuns(_userId);

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final UserModel? user = snapshot.data;
        // AuthGate가 들여보내기 전에 문서를 만들어 두므로 여기서 null은 거의 없습니다.
        // (막 만들어진 문서가 도착하기 전 한 순간만 null일 수 있습니다)
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                HomeHeader(
                  user: user,
                  onSettings: () => _open(SettingsScreen(userId: _userId)),
                ),
                const SizedBox(height: HomeHeader.nameGap),
                LevelCard(user: user),
                const SizedBox(height: AppSpacing.xl),
                TotalsRow(user: user),
                const SizedBox(height: AppSpacing.xl),
                ShortcutsRow(
                  user: user,
                  onCharacter: () =>
                      _open(ProfileScreen(userId: _userId, userData: user)),
                  onRanking: () =>
                      _open(RankingScreen(userId: _userId, user: user)),
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildRecentRuns(),
              ],
            ),
          ),
          bottomNavigationBar: _buildStartButton(),
        );
      },
    );
  }

  Widget _buildRecentRuns() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '최근 러닝',
              style: AppTheme.serifNumber.copyWith(
                fontSize: 20,
                color: AppColors.black,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _open(RunHistoryScreen(userId: _userId)),
              child: Text(
                '전체 기록',
                style: AppTheme.sans.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<RunLog>>(
          stream: _recentRunsStream,
          builder: (context, snapshot) {
            // 감춘 기록은 받아온 뒤에 걸러지므로, 3개를 받아 그중 맨 앞 1개만 씁니다.
            // 처음부터 1개만 받으면 그게 감춘 기록일 때 빈칸이 됩니다.
            final List<RunLog> runs = (snapshot.data ?? []).take(1).toList();
            if (runs.isEmpty) {
              return DashedBox(
                child: Center(
                  child: Text(
                    '아직 기록이 없어요 · 첫 러닝을 시작해 보세요',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.mute,
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final run in runs) ...[
                  RunLogTile(
                    run: run,
                    onTap: () =>
                        _open(RunDetailScreen(userId: _userId, run: run)),
                  ),
                  if (run != runs.last) const Divider(),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SafeArea(
      // 아래 여백: 내비게이션 바에 바싹 붙는 기종이 있어서 넉넉하게 둡니다.
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppTheme.bottomButtonGap,
      ),
      // 시작 버튼만 둥근 모양입니다. 모서리를 자른 팔각형은 검은 카드들이 씁니다.
      child: Material(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(RunScreen(userId: _userId)),
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              // 시안처럼 안쪽에 흰 테두리를 한 겹 더 그립니다.
              border: Border.all(color: AppColors.white, width: 1.2),
              borderRadius: BorderRadius.circular(AppRadius.md - 6),
            ),
            // Center를 쓰면 안 됩니다. 화면 아래에 붙는 자리는 높이 제한이 화면
            // 전체라서 Center가 그만큼 늘어나 버튼이 화면을 덮습니다.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '시작',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontSize: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
