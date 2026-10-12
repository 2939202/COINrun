import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../game/character_outfit.dart';
import '../game/pvp_battle.dart';
import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/ranking_repository.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/character_view.dart';
import '../widgets/notched_box.dart';

// ============================================================
// 게임 플레잉(PVP)
//
// [자동 매칭] -> 찾는 중 화면 -> 상대를 찾으면 자동 대결 화면.
// 상대는 랭킹 목록(leaderboard)에서 나와 같은 등급(브론즈·실버·골드…)인 사람 중에서
// 무작위로 고릅니다. 같은 등급에 아무도 없으면 한 등급씩 아래로 내려가며 찾습니다.
// 대결 규칙과 능력치 계산은 game/pvp_battle.dart에 있습니다.
// ============================================================
class PvpScreen extends StatelessWidget {
  final String userId;
  final UserModel user;

  const PvpScreen({super.key, required this.userId, required this.user});

  Fighter get _me => Fighter(
    id: userId,
    name: user.nickname,
    level: user.level,
    totalKm: user.totalDistance / 1000,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('게임 플레잉')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _MyFighterCard(fighter: _me),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '같은 등급(${RunRules.tierName(user.level)})끼리만 겨뤄요. '
            '연습 대결이라 이겨도 골드는 받지 않아요.',
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MatchingScreen(userId: userId, user: user, me: _me),
                ),
              ),
              icon: const Icon(Icons.bolt),
              label: const Text('자동 매칭'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 찾는 중 화면
//
// 같은 등급 사람을 불러오는 동안 "상대를 찾는 중"을 보여줍니다. 너무 빨리 끝나면
// 찾는 느낌이 안 나서 최소 2.5초는 보여줍니다. 찾으면 잠깐 상대를 보여주고 대결로 넘어갑니다.
// ============================================================
class MatchingScreen extends StatefulWidget {
  final String userId;
  final UserModel user;
  final Fighter me;

  const MatchingScreen({
    super.key,
    required this.userId,
    required this.user,
    required this.me,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

enum _MatchState { searching, found, none, failed }

class _MatchingScreenState extends State<MatchingScreen> {
  static const Duration _minSearch = Duration(milliseconds: 2500);
  static const Duration _showFound = Duration(milliseconds: 1200);

  _MatchState _state = _MatchState.searching;
  RankingEntry? _opponent;
  bool _lowerTier = false; // 같은 등급이 없어서 아래 등급과 붙었는지

  @override
  void initState() {
    super.initState();
    _search();
  }

  static Fighter _fighterOf(RankingEntry entry) => Fighter(
    id: entry.userId,
    name: entry.nickname,
    level: entry.level,
    totalKm: entry.totalDistance / 1000,
  );

  Future<void> _search() async {
    setState(() {
      _state = _MatchState.searching;
      _opponent = null;
    });
    final Future<void> wait = Future.delayed(_minSearch);
    // 내 등급부터 찾고, 아무도 없으면 한 등급씩 내려가며 찾습니다.
    List<RankingEntry> others = const [];
    _lowerTier = false;
    try {
      final List<int> starts = RunRules.tierStarts
          .where((start) => start <= widget.user.level)
          .toList()
          .reversed
          .toList();
      for (final int start in starts) {
        final List<RankingEntry> found = await RankingRepository.instance
            .sameTier(start == starts.first ? widget.user.level : start);
        others = found.where((entry) => entry.userId != widget.userId).toList();
        if (others.isNotEmpty) break;
        _lowerTier = true;
      }
    } catch (_) {
      await wait;
      if (mounted) setState(() => _state = _MatchState.failed);
      return;
    }
    await wait;
    if (!mounted) return;
    if (others.isEmpty) {
      setState(() => _state = _MatchState.none);
      return;
    }
    final RankingEntry pick = others[Random().nextInt(others.length)];
    setState(() {
      _state = _MatchState.found;
      _opponent = pick;
    });
    await Future.delayed(_showFound);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          challenger: widget.me,
          opponent: _fighterOf(pick),
          challengerParts: widget.user.parts(),
          // 겉모습을 올리기 전의 상대는 여자 기본 옷으로 그립니다.
          opponentParts: CharacterOutfit.partsFor(
            pick.look ?? CharacterLook.female,
            pick.equippedSetId,
            dogStage: pick.dogStage,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final String tier = RunRules.tierName(widget.user.level);
    final RankingEntry? opponent = _opponent;

    final Widget body = switch (_state) {
      _MatchState.searching => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.accentOnDark,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Dots(text: '상대를 찾는 중'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tier,
            style: textTheme.labelMedium?.copyWith(color: AppColors.sandOnDark),
          ),
        ],
      ),
      _MatchState.found => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MATCH!',
            style: AppTheme.caption.copyWith(color: AppColors.accentOnDark),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            opponent?.nickname ?? '',
            style: AppTheme.serifNumber.copyWith(
              fontSize: 30,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_lowerTier) ...[
            Text(
              '같은 등급 상대가 없어 아래 등급과 겨뤄요',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.accentOnDark,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            'Lv.${opponent?.level ?? 0} · '
            '${RunRules.tierName(opponent?.level ?? widget.user.level)}',
            style: textTheme.labelMedium?.copyWith(color: AppColors.sandOnDark),
          ),
        ],
      ),
      _MatchState.none || _MatchState.failed => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _state == _MatchState.none ? '겨룰 상대가 아직 없어요.' : '상대를 불러오지 못했어요.',
            style: textTheme.bodyLarge?.copyWith(color: AppColors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: const BorderSide(color: AppColors.trackOnDark),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('돌아가기'),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(onPressed: _search, child: const Text('다시 찾기')),
            ],
          ),
        ],
      ),
    };

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('자동 매칭', style: TextStyle(color: AppColors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: body,
        ),
      ),
    );
  }
}

// "상대를 찾는 중." -> ".." -> "..." 를 되풀이합니다.
class _Dots extends StatefulWidget {
  final String text;

  const _Dots({required this.text});

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> {
  int _count = 1;
  late final Timer _timer = Timer.periodic(
    const Duration(milliseconds: 400),
    (_) => setState(() => _count = _count % 3 + 1),
  );

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.text}${'.' * _count}${' ' * (3 - _count)}',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: AppColors.white),
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
    _playSounds(turn);
    if (turn.critical) _buzz(60);
    if (_finished) {
      _timer?.cancel();
      _buzz(_result.challengerWon ? 300 : 120);
    }
  }

  // 치는 순간 "휙퍽", 주먹이 닿을 때(뷰어의 IMPACT, 약 0.35초 뒤) 맞으면 "퍽", 피하면 "휙"
  static const Duration _impact = Duration(milliseconds: 330);

  void _playSounds(BattleTurn turn) {
    SoundService.instance.play(Sfx.punch);
    final bool landed = !turn.dodged && turn.damage > 0;
    Future.delayed(_impact, () {
      if (!mounted) return;
      SoundService.instance.play(landed ? Sfx.hit : Sfx.whoosh);
    });
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
            // 끝나면 버튼 없이 결과만 둡니다. (나갈 때는 위의 뒤로 가기)
            SizedBox(
              height: 52,
              child: _finished
                  ? null
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
