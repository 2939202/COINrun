import 'package:flutter/material.dart';

import '../game/equipment_rules.dart';
import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/run_log.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/run_log_tile.dart';
import '../widgets/stat_block.dart';
import 'profile_screen.dart'; //프로필
import 'ranking_screen.dart'; //랭킹
import 'run_history_screen.dart'; //전체 기록
import 'run_detail_screen.dart'; //러닝 기록 상세
import 'run_screen.dart'; //달리기 시작
import 'settings_screen.dart'; //설정

// ============================================================
// 홈 화면
//   인사 + 골드/설정 -> 레벨 카드 -> 누적 기록 -> 캐릭터/랭킹 -> 최근 러닝
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                _buildHeader(user),
                const SizedBox(height: AppSpacing.lg),
                _LevelCard(user: user),
                const SizedBox(height: AppSpacing.xl),
                _buildTotals(user),
                const SizedBox(height: AppSpacing.xl),
                _buildShortcuts(user),
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

  Widget _buildHeader(UserModel user) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('안녕하세요,', style: textTheme.labelMedium),
              Text(
                user.nickname,
                style: textTheme.headlineMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _GoldPill(gold: user.gold),
        IconButton(
          tooltip: '설정',
          onPressed: () => _open(SettingsScreen(userId: _userId)),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  // 누적 기록 - 박스 없이 큰 숫자만 (나이키 런 스타일)
  Widget _buildTotals(UserModel user) {
    return Row(
      children: [
        StatBlock(
          value: formatKm(user.totalDistance),
          label: '총 킬로미터',
          alignment: CrossAxisAlignment.start,
        ),
        StatBlock(
          value: formatHoursMinutes(user.totalRunSeconds),
          label: '총 시간',
          alignment: CrossAxisAlignment.start,
        ),
        _RankStat(user: user),
      ],
    );
  }

  Widget _buildShortcuts(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutCard(
            icon: Icons.shield_outlined,
            title: '내 캐릭터',
            subtitle: EquipmentRules.equippedSetName(user),
            onTap: () => _open(ProfileScreen(userId: _userId, userData: user)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ShortcutCard(
            icon: Icons.emoji_events_outlined,
            title: '랭킹',
            subtitle: '전체 순위 보기',
            onTap: () => _open(RankingScreen(userId: _userId, user: user)),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRuns() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('최근 러닝', style: textTheme.titleLarge),
            const Spacer(),
            TextButton(
              onPressed: () => _open(RunHistoryScreen(userId: _userId)),
              child: const Text('전체 기록'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<RunLog>>(
          stream: _recentRunsStream,
          builder: (context, snapshot) {
            final List<RunLog> runs = snapshot.data ?? [];
            if (runs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  '아직 러닝 기록이 없어요.\n첫 러닝을 시작해서 골드와 경험치를 모아보세요.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey500,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final run in runs) ...[
                  RunLogTile(
                    run: run,
                    onTap: () => _open(RunDetailScreen(run: run)),
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
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SizedBox(
        height: 64,
        child: ElevatedButton.icon(
          onPressed: () => _open(RunScreen(userId: _userId)),
          icon: const Icon(Icons.play_arrow_rounded, size: 32),
          label: const Text('러닝 시작'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.volt,
            foregroundColor: AppColors.black,
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 홈 화면 전용 작은 위젯들
// ------------------------------------------------------------

// 홈의 "순위" 칸
//
// 순위는 남들과 비교해야 알 수 있어서 유저 문서에는 없습니다.
// 화면에 들어올 때 한 번만 물어봅니다. (Firestore의 count 집계라 문서를 받아오지 않습니다)
class _RankStat extends StatefulWidget {
  final UserModel user;

  const _RankStat({required this.user});

  @override
  State<_RankStat> createState() => _RankStatState();
}

class _RankStatState extends State<_RankStat> {
  late final Future<int?> _rank = RankingRepository.instance.myRank(
    RankingKind.distance,
    widget.user,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _rank,
      builder: (context, snapshot) {
        final int? rank = snapshot.data;
        return StatBlock(
          value: rank == null ? '-' : '$rank위',
          label: '거리 순위',
          alignment: CrossAxisAlignment.start,
        );
      },
    );
  }
}

// 검은 레벨 카드: 큰 레벨 숫자 + 등급 + 경험치 바
class _LevelCard extends StatelessWidget {
  final UserModel user;

  const _LevelCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final int needed = RunRules.expToNextLevel(user.level);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LEVEL',
                style: textTheme.labelMedium?.copyWith(letterSpacing: 2),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.volt,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  RunRules.tierName(user.level),
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '${user.level}',
            style: textTheme.displayLarge?.copyWith(
              color: AppColors.white,
              fontSize: 96,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: user.exp / needed,
              minHeight: 8,
              color: AppColors.volt,
              backgroundColor: AppColors.grey700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${user.exp} / $needed EXP',
                style: textTheme.labelMedium?.copyWith(color: AppColors.white),
              ),
              const Spacer(),
              Text(
                '다음 레벨까지 ${needed - user.exp}',
                style: textTheme.labelMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoldPill extends StatelessWidget {
  final int gold;

  const _GoldPill({required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 4,
        vertical: AppSpacing.sm - 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_outlined, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$gold G',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// 회색 정사각형 바로가기 카드
class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 150,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 28),
                    const Spacer(),
                    const Icon(Icons.arrow_outward, size: 18),
                  ],
                ),
                const Spacer(),
                Text(title, style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
