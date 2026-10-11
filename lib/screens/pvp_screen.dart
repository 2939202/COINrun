import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../game/character_outfit.dart';
import '../game/pvp_battle.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/character_view.dart';
import '../widgets/notched_box.dart';

// ============================================================
// 게임 플레잉(PVP)
//
// 상대 고르기 -> 자동 대결 화면.
// 상대는 랭킹 목록(leaderboard)에서 고릅니다. 내 레벨과 가까운 사람부터 보여줍니다.
// 대결 규칙과 능력치 계산은 game/pvp_battle.dart에 있습니다.
// ============================================================
class PvpScreen extends StatefulWidget {
  final String userId;
  final UserModel user;

  const PvpScreen({super.key, required this.userId, required this.user});

  @override
  State<PvpScreen> createState() => _PvpScreenState();
}

class _PvpScreenState extends State<PvpScreen> {
  late final Stream<List<RankingEntry>> _board = RankingRepository.instance
      .watchTop(RankingKind.level);

  Fighter get _me => Fighter(
    id: widget.userId,
    name: widget.user.nickname,
    level: widget.user.level,
    totalKm: widget.user.totalDistance / 1000,
  );

  static Fighter _fighterOf(RankingEntry entry) => Fighter(
    id: entry.userId,
    name: entry.nickname,
    level: entry.level,
    totalKm: entry.totalDistance / 1000,
  );

  void _challenge(RankingEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          challenger: _me,
          opponent: _fighterOf(entry),
          challengerParts: CharacterOutfit.partsFor(
            widget.user.look ?? CharacterLook.female,
            widget.user.equippedSetId,
          ),
          // 겉모습을 올리기 전의 상대는 여자 기본 옷으로 그립니다.
          opponentParts: CharacterOutfit.partsFor(
            entry.look ?? CharacterLook.female,
            entry.equippedSetId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Fighter me = _me;

    return Scaffold(
      appBar: AppBar(title: const Text('게임 플레잉')),
      body: StreamBuilder<List<RankingEntry>>(
        stream: _board,
        builder: (context, snapshot) {
          final List<RankingEntry> entries =
              (snapshot.data ?? const [])
                  .where((entry) => entry.userId != widget.userId)
                  .toList()
                // 나와 레벨이 비슷한 사람부터
                ..sort(
                  (a, b) => (a.level - me.level).abs().compareTo(
                    (b.level - me.level).abs(),
                  ),
                );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _MyFighterCard(fighter: me),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '연습 대결이에요. 이겨도 골드는 받지 않아요. '
                '같은 상대와는 하루 동안 결과가 같아요.',
                style: textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('상대 고르기', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    '아직 겨룰 상대가 없어요. 친구에게 달리랑을 알려주세요!',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.mute,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final entry in entries) ...[
                  _OpponentTile(
                    fighter: _fighterOf(entry),
                    myPower: me.power,
                    onChallenge: () => _challenge(entry),
                  ),
                  const Divider(),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MyFighterCard extends StatelessWidget {
  final Fighter fighter;

  const _MyFighterCard({required this.fighter});

  @override
  Widget build(BuildContext context) {
    final TextStyle label = AppTheme.sans.copyWith(
      color: AppColors.sandOnDark,
      fontSize: 13,
    );
    final TextStyle value = AppTheme.serifNumber.copyWith(
      color: AppColors.white,
      fontSize: 22,
    );

    Widget stat(String name, String number) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: value),
          const SizedBox(height: AppSpacing.xs),
          Text(name, style: label),
        ],
      ),
    );

    return NotchedBox(
      cut: 16,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MY FIGHTER',
            style: AppTheme.caption.copyWith(color: AppColors.sandOnDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  fighter.name,
                  style: AppTheme.serifNumber.copyWith(
                    color: AppColors.white,
                    fontSize: 26,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('전투력 ', style: label),
              Text(
                '${fighter.power}',
                style: value.copyWith(color: AppColors.accentOnDark),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              stat('체력', '${fighter.maxHp}'),
              stat('공격', fighter.attack.toStringAsFixed(0)),
              stat('방어', fighter.defense.toStringAsFixed(0)),
              stat('속도', fighter.speed.toStringAsFixed(0)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('레벨과 누적 거리가 오를수록 강해져요.', style: label),
        ],
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  final Fighter fighter;
  final int myPower;
  final VoidCallback onChallenge;

  const _OpponentTile({
    required this.fighter,
    required this.myPower,
    required this.onChallenge,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final int gap = fighter.power - myPower;
    final String hint = gap > 15
        ? '강한 상대'
        : gap < -15
        ? '해볼 만한 상대'
        : '비슷한 상대';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fighter.name,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Lv.${fighter.level} · ${fighter.totalKm.toStringAsFixed(1)}km · '
                  '전투력 ${fighter.power} · $hint',
                  style: textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            onPressed: onChallenge,
            child: const Text('대결'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 대결 화면 - 계산은 한 번에 끝내 두고, 한 차례씩 보여줍니다.
// 가운데 3D에서 두 캐릭터가 마주 보고, 차례마다 치고 맞습니다.
// ============================================================
class BattleScreen extends StatefulWidget {
  final Fighter challenger;
  final Fighter opponent;

  // 3D로 그릴 두 사람의 파츠 (game/character_outfit.dart)
  final List<String> challengerParts;
  final List<String> opponentParts;

  const BattleScreen({
    super.key,
    required this.challenger,
    required this.opponent,
    required this.challengerParts,
    required this.opponentParts,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  static const Duration _turnGap = Duration(milliseconds: 650);

  late final BattleResult _result = PvpBattle.fight(
    widget.challenger,
    widget.opponent,
  );
  int _shown = 0; // 지금까지 보여준 차례 수
  Timer? _timer;

  bool get _finished => _shown >= _result.turns.length;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_turnGap, (_) => _next());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (_finished) {
      _timer?.cancel();
      return;
    }
    final BattleTurn turn = _result.turns[_shown];
    setState(() => _shown++);
    if (turn.critical) _buzz(60);
    if (_finished) {
      _timer?.cancel();
      _buzz(_result.challengerWon ? 300 : 120);
    }
  }

  // 결과를 바로 보고 싶을 때
  void _skip() {
    _timer?.cancel();
    setState(() => _shown = _result.turns.length);
  }

  Future<void> _buzz(int ms) async {
    try {
      if (await Vibration.hasVibrator()) await Vibration.vibrate(duration: ms);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final BattleTurn? last = _shown == 0 ? null : _result.turns[_shown - 1];
    final int myHp = last?.challengerHp ?? widget.challenger.maxHp;
    final int theirHp = last?.opponentHp ?? widget.opponent.maxHp;
    final List<BattleTurn> log = _result.turns
        .take(_shown)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('대결')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HpBar(
              fighter: widget.opponent,
              hp: theirHp,
              hit: last != null && last.byChallenger && last.damage > 0,
            ),
            // 왼쪽이 나, 오른쪽이 상대입니다.
            SizedBox(
              height: 220,
              child: CharacterView(
                me: widget.challengerParts,
                foe: widget.opponentParts,
                strike: last == null
                    ? null
                    : CharacterStrike(
                        turn: _shown,
                        byMe: last.byChallenger,
                        landed: !last.dodged && last.damage > 0,
                      ),
              ),
            ),
            _HpBar(
              fighter: widget.challenger,
              hp: myHp,
              hit: last != null && !last.byChallenger && last.damage > 0,
              isMe: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_finished)
              _ResultBanner(won: _result.challengerWon)
            else
              const SizedBox(height: 0),
            const SizedBox(height: AppSpacing.md),
            Text('전투 기록', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                children: [
                  for (final turn in log)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        _describe(turn),
                        style: textTheme.bodyMedium?.copyWith(
                          color: turn.critical
                              ? AppColors.accent
                              : turn.byChallenger
                              ? AppColors.black
                              : AppColors.mute,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: _finished
                  ? ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('다른 상대 고르기'),
                    )
                  : OutlinedButton(
                      onPressed: _skip,
                      child: const Text('결과 바로 보기'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _describe(BattleTurn turn) {
    final String attacker = turn.byChallenger
        ? widget.challenger.name
        : widget.opponent.name;
    final String defender = turn.byChallenger
        ? widget.opponent.name
        : widget.challenger.name;
    if (turn.dodged) return '$defender, $attacker의 공격을 피했다!';
    if (turn.critical) return '$attacker의 회심의 일격! ${turn.damage} 피해';
    return '$attacker의 공격 · ${turn.damage} 피해';
  }
}

class _HpBar extends StatelessWidget {
  final Fighter fighter;
  final int hp;
  final bool hit; // 방금 맞았는지 (흔들림)
  final bool isMe;

  const _HpBar({
    required this.fighter,
    required this.hp,
    required this.hit,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio = hp / fighter.maxHp;
    final Color fill = ratio > 0.5
        ? AppColors.accent
        : ratio > 0.2
        ? AppColors.gold
        : AppColors.error;

    return AnimatedSlide(
      offset: hit ? const Offset(0.015, 0) : Offset.zero,
      duration: const Duration(milliseconds: 90),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isMe ? AppColors.cream : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.black, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMe ? '${fighter.name} (나)' : fighter.name,
                    style: AppTheme.serifNumber.copyWith(
                      fontSize: 18,
                      color: AppColors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Lv.${fighter.level}',
                  style: AppTheme.sans.copyWith(
                    fontSize: 13,
                    color: AppColors.label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: ratio),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  color: fill,
                  backgroundColor: AppColors.sand,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'HP $hp / ${fighter.maxHp}',
              style: AppTheme.sans.copyWith(
                fontSize: 12,
                color: AppColors.mute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final bool won;

  const _ResultBanner({required this.won});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: won ? AppColors.black : AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            won ? '승리!' : '패배',
            style: AppTheme.serifNumber.copyWith(
              fontSize: 30,
              color: won ? AppColors.accentOnDark : AppColors.black,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            won ? '달린 만큼 강해졌어요.' : '조금 더 달리고 다시 도전해요.',
            style: AppTheme.sans.copyWith(
              fontSize: 14,
              color: won ? AppColors.sandOnDark : AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}
