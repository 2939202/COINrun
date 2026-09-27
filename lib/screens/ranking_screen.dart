import 'package:flutter/material.dart';

import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

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
    return Column(
      children: [
        _MyRankCard(kind: widget.kind, user: widget.user, rank: _myRank),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<RankingEntry>>(
            stream: _top,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const _Message('랭킹을 불러오지 못했습니다.\n인터넷 연결을 확인해 주세요.');
              }

              final List<RankingEntry> entries = snapshot.data ?? [];
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
            },
          ),
        ),
      ],
    );
  }
}

// 맨 위에 붙는 내 순위
class _MyRankCard extends StatelessWidget {
  final RankingKind kind;
  final UserModel user;
  final Future<int?> rank;

  const _MyRankCard({
    required this.kind,
    required this.user,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: AppColors.black,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('내 순위', style: textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                FutureBuilder<int?>(
                  future: rank,
                  builder: (context, snapshot) {
                    final bool waiting =
                        snapshot.connectionState == ConnectionState.waiting;
                    final int? myRank = snapshot.data;
                    // 아직 한 번도 안 뛰었으면 순위가 없습니다.
                    final String text = waiting
                        ? '...'
                        : (myRank == null ? '기록 없음' : '$myRank위');
                    return Text(
                      text,
                      style: textTheme.displayLarge?.copyWith(
                        color: waiting ? AppColors.white : AppColors.volt,
                        fontSize: (!waiting && myRank == null) ? 28 : 40,
                      ),
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
                style: textTheme.titleMedium?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                rankingValueLabel(
                  kind,
                  totalDistance: user.totalDistance,
                  level: user.level,
                ),
                style: textTheme.labelMedium,
              ),
            ],
          ),
        ],
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

    return Container(
      // 목록에서 나를 빨리 찾을 수 있게 표시합니다.
      color: isMe ? AppColors.volt : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('$rank', style: textTheme.titleLarge),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.nickname,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Lv.${entry.level} · ${RunRules.tierName(entry.level)}',
                  style: textTheme.labelMedium,
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
            style: textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
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
          ).textTheme.bodyMedium?.copyWith(color: AppColors.grey500),
        ),
      ),
    );
  }
}
