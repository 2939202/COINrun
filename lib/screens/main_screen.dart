import 'package:flutter/material.dart';

import '../game/equipment_rules.dart';
import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/run_log.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/run_log_tile.dart';
import '../widgets/runner_figure.dart';
import '../widgets/week_summary.dart';
import 'profile_screen.dart'; //프로필
import 'ranking_screen.dart'; //랭킹
import 'run_history_screen.dart'; //전체 기록
import 'run_detail_screen.dart'; //러닝 기록 상세
import 'run_screen.dart'; //달리기 시작
import 'settings_screen.dart'; //설정

// ============================================================
// 홈 화면
//   인사 + 골드/설정 -> 이번 주 -> 캐릭터(레벨/랭킹) -> 최근 러닝
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
                // 이번 주가 맨 위. 누적 총계보다 훨씬 자주 궁금한 숫자입니다.
                WeekSummary(userId: _userId),
                const SizedBox(height: AppSpacing.xl),
                // 캐릭터가 이 앱의 주인공입니다. 레벨과 랭킹을 여기에 붙여둡니다.
                _CharacterBlock(
                  user: user,
                  onTapCharacter: () =>
                      _open(ProfileScreen(userId: _userId, userData: user)),
                  onTapRanking: () =>
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
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.mute),
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
            backgroundColor: AppColors.accent,
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

// 홈의 주인공. 캐릭터 + 레벨 + 랭킹을 한 덩어리로 묶습니다.
//
// 예전에는 검은 레벨 카드와 캐릭터 카드가 따로 떨어져 있었습니다. 둘은 결국 같은 얘기라
// 자리를 두 배로 쓰면서, 정작 캐릭터는 어깨까지 잘린 썸네일로 들어가 있었습니다.
class _CharacterBlock extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTapCharacter;
  final VoidCallback onTapRanking;

  const _CharacterBlock({
    required this.user,
    required this.onTapCharacter,
    required this.onTapRanking,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final int needed = RunRules.expToNextLevel(user.level);
    final double progress = (user.exp / needed).clamp(0.0, 1.0);

    return Column(
      children: [
        GestureDetector(
          onTap: onTapCharacter,
          child: SizedBox(
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const RunnerFigure(),
                // 입은 장비를 캐릭터 옆에 작게 얹습니다.
                Positioned(
                  right: 0,
                  top: 0,
                  child: _Tag(text: EquipmentRules.equippedSetName(user)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Lv.${user.level}', style: textTheme.titleLarge),
            Text(
              '  ·  ${RunRules.tierName(user.level)}',
              style: textTheme.titleMedium?.copyWith(color: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: AppColors.black,
            backgroundColor: AppColors.sand,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text('${user.exp} / $needed EXP', style: textTheme.labelMedium),
            const Spacer(),
            Text('다음 레벨까지 ${needed - user.exp}', style: textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // 랭킹은 여기로 내렸습니다. 보고 싶은 사람만 누릅니다.
        // 편차가 큰 운동에서 절대 순위를 홈에 크게 걸어두면 대부분에게는 꺾이는 숫자입니다.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onTapRanking,
            child: _RankLabel(user: user),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.sand),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

// 랭킹 버튼 안의 글자. 순위를 알아낸 뒤에는 "랭킹 · 거리 4위"로 바뀝니다.
class _RankLabel extends StatefulWidget {
  final UserModel user;

  const _RankLabel({required this.user});

  @override
  State<_RankLabel> createState() => _RankLabelState();
}

class _RankLabelState extends State<_RankLabel> {
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
        return Text(rank == null ? '랭킹 보기' : '랭킹  ·  거리 $rank위');
      },
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
        color: AppColors.cream,
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
