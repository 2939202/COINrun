import 'package:flutter/material.dart';

import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/notched_box.dart';

// ============================================================
// 랭킹 화면
//
// 기준 두 가지를 탭으로 오갑니다.
//   거리 - 누적 러닝 거리. 많이 뛴 사람이 위로.
//   레벨 - 지금까지 받은 경험치 총합. 같은 레벨이어도 누가 앞섰는지 가려집니다.
//
// 모양은 아직 다듬지 않았습니다. 디자인 방향이 정해지면 이 파일만 다시 만들면 됩니다.
// ============================================================
class RankingScreen extends StatefulWidget {
  final String userId;
  final UserModel user;

  const RankingScreen({super.key, required this.userId, required this.user});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: RankingKind.values.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('랭킹'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.black,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppColors.black,
          unselectedLabelColor: AppColors.mute,
          // 탭 글자는 스타일을 통째로 바꿔 끼우는 자리라 글꼴을 꼭 적습니다.
          // (적지 않으면 기본 글꼴로 나옵니다)
          labelStyle: const TextStyle(
            fontFamily: AppTheme.hangulSerifFont,
            fontSize: 17,
            fontWeight: AppTheme.serifWeight,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: AppTheme.sansFont,
            fontSize: 17,
            fontWeight: AppTheme.sansMedium,
          ),
          dividerColor: AppColors.sand,
          tabs: [for (final kind in RankingKind.values) Tab(text: kind.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final kind in RankingKind.values)
            _RankingList(kind: kind, userId: widget.userId, user: widget.user),
        ],
      ),
    );
  }
}

class _RankingList extends StatefulWidget {
  final RankingKind kind;
  final String userId;
  final UserModel user;

  const _RankingList({
    required this.kind,
    required this.userId,
    required this.user,
  });

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList> {
  // 스트림과 Future는 한 번만 만들어 둡니다.
  // (build 안에서 만들면 다시 그릴 때마다 새로 연결되고 질의도 다시 나갑니다)
  late final Stream<List<RankingEntry>> _top = RankingRepository.instance
      .watchTop(widget.kind);
  late final Future<int?> _myRank = RankingRepository.instance.myRank(
    widget.kind,
    widget.user,
  );

  @override
  Widget build(BuildContext context) {
    // 내 순위 카드에 "/ N명"을 보여주려면 목록 개수가 필요해서 한 스트림으로 묶습니다.
    return StreamBuilder<List<RankingEntry>>(
      stream: _top,
      builder: (context, snapshot) {
        final List<RankingEntry> entries = snapshot.data ?? const [];
        return Column(
          children: [
            _MyRankCard(
              kind: widget.kind,
              user: widget.user,
              rank: _myRank,
              total: entries.length,
            ),
            Expanded(child: _buildList(snapshot, entries)),
          ],
        );
      },
    );
  }

  Widget _buildList(
    AsyncSnapshot<List<RankingEntry>> snapshot,
    List<RankingEntry> entries,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return const _Message('랭킹을 불러오지 못했습니다.\n인터넷 연결을 확인해 주세요.');
    }
    if (entries.isEmpty) {
      return const _Message('아직 아무도 달리지 않았어요.\n첫 번째가 되어 보세요.');
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _RankRow(
        rank: index + 1,
        entry: entries[index],
        kind: widget.kind,
        isMe: entries[index].userId == widget.userId,
      ),
    );
  }
}

// 맨 위에 붙는 내 순위
class _MyRankCard extends StatelessWidget {
  final RankingKind kind;
  final UserModel user;
  final Future<int?> rank;
  final int total;

  const _MyRankCard({
    required this.kind,
    required this.user,
    required this.rank,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: NotchedBox(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MY RANK',
                    style: AppTheme.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FutureBuilder<int?>(
                    future: rank,
                    builder: (context, snapshot) {
                      final bool waiting =
                          snapshot.connectionState == ConnectionState.waiting;
                      final int? myRank = snapshot.data;
                      // 게스트는 랭킹에 줄이 없고, 뛴 적이 없으면 순위가 없습니다.
                      if (waiting) {
                        return Text(
                          '...',
                          style: AppTheme.number.copyWith(
                            fontSize: 40,
                            color: AppColors.white,
                          ),
                        );
                      }
                      if (myRank == null) {
                        return Text(
                          user.isGuest ? '게스트' : '기록 없음',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.white,
                          ),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$myRank',
                            style: AppTheme.number.copyWith(
                              fontSize: 44,
                              color: AppColors.white,
                            ),
                          ),
                          Text(
                            '위',
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                          Text(
                            '  / $total명',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.sand,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user.nickname,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  rankingValueLabel(
                    kind,
                    totalDistance: user.totalDistance,
                    level: user.level,
                  ),
                  style: AppTheme.number.copyWith(
                    fontSize: 22,
                    color: AppColors.accent,
                  ),
                ),
                if (user.isGuest) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: 170,
                    child: Text(
                      '설정에서 계정을 저장하면 랭킹에 올라가요.',
                      textAlign: TextAlign.right,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.accent,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 목록 한 줄
class _RankRow extends StatelessWidget {
  final int rank;
  final RankingEntry entry;
  final RankingKind kind;
  final bool isMe;

  const _RankRow({
    required this.rank,
    required this.entry,
    required this.kind,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Color text = isMe ? AppColors.white : AppColors.black;
    final Color sub = isMe ? AppColors.sand : AppColors.mute;

    return Container(
      // 목록에서 나를 빨리 찾을 수 있게 검게 칠합니다.
      color: isMe ? AppColors.black : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank, isMe: isMe),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.nickname,
                  style: textTheme.titleMedium?.copyWith(color: text),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Lv.${entry.level} · ${RunRules.tierName(entry.level)}',
                  style: textTheme.bodyMedium?.copyWith(color: sub),
                ),
              ],
            ),
          ),
          Text(
            rankingValueLabel(
              kind,
              totalDistance: entry.totalDistance,
              level: entry.level,
            ),
            style: AppTheme.number.copyWith(fontSize: 20, color: text),
          ),
          if (kind == RankingKind.distance)
            Text(' km', style: textTheme.labelMedium?.copyWith(color: sub)),
        ],
      ),
    );
  }
}

// 등수 동그라미.
//   1등은 채워진 원, 2등은 테두리, 3등은 점선, 그 아래는 숫자만.
class _RankBadge extends StatelessWidget {
  final int rank;
  final bool isMe;

  const _RankBadge({required this.rank, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final TextStyle number = AppTheme.number.copyWith(
      fontSize: 15,
      color: isMe ? AppColors.white : AppColors.black,
    );

    if (rank > 3) {
      return SizedBox(
        width: 34,
        child: Center(child: Text('$rank', style: number)),
      );
    }

    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _BadgePainter(rank: rank),
        child: Center(child: Text('$rank', style: number)),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  final int rank;

  const _BadgePainter({required this.rank});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 1;

    if (rank == 1) {
      canvas.drawCircle(center, radius, Paint()..color = AppColors.sand);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.accent;

    if (rank == 3) {
      // 3등은 점선 테두리
      const int dashes = 16;
      const double sweep = 6.283185 / dashes;
      for (int i = 0; i < dashes; i += 2) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * sweep,
          sweep,
          false,
          stroke,
        );
      }
      return;
    }

    canvas.drawCircle(center, radius, stroke);
  }

  @override
  bool shouldRepaint(_BadgePainter oldDelegate) => oldDelegate.rank != rank;
}

// 기준에 맞는 값을 글자로
String rankingValueLabel(
  RankingKind kind, {
  required double totalDistance,
  required int level,
}) {
  return switch (kind) {
    RankingKind.distance => '${formatKm(totalDistance)} km',
    RankingKind.level => 'Lv.$level',
  };
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mute),
        ),
      ),
    );
  }
}
