import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../game/character_outfit.dart';
import '../game/player_number.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/friend_repository.dart';
import '../services/ranking_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/character_view.dart';
import '../widgets/look_image.dart';

// ============================================================
// 나의 길드
//
// 방 사진(assets/backgrounds/guild.png)을 화면에 꽉 깔고, 그 위에 투명한 3D 화면을 얹습니다.
//   - 벽의 큰 액자: 길드장(나)의 초상화. 캐릭터 그림을 픽셀로 뭉개서 그림처럼 겁니다.
//   - 나무 바닥: 3D 캐릭터들이 걸어 다닙니다. 원근법은 3D 카메라가 맡습니다.
//     앞(아래)으로 오면 크고, 안쪽(위)으로 가면 작아집니다. (assets/viewer/index.html의 길드)
//   - 왼쪽 아래 조이스틱: 살짝 밀면 걷고, 끝까지 밀면 뜁니다.
//   - 친구들은 혼자 돌아다닙니다. 오른쪽 위 [친구]에서 추가·수락·끊기를 합니다.
//
// 사진은 화면 비율이 달라도 꽉 차게(cover) 아래쪽에 맞춰 깝니다. 그래서 잘린 만큼을 계산해
// 액자와 바닥이 화면 어디에 오는지 구한 뒤, 초상화 자리와 3D 바닥 위치를 맞춥니다.
// ============================================================
class GuildScreen extends StatefulWidget {
  final String userId;
  final UserModel user;

  const GuildScreen({super.key, required this.userId, required this.user});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

// 배경 사진 속 자리 (사진 크기 대비 비율)
class _Room {
  static const String asset = 'assets/backgrounds/guild.png';
  static const Size size = Size(220, 330);
  // 액자 안쪽
  static const Rect frame = Rect.fromLTRB(0.11, 0.08, 0.89, 0.76);
  // 나무 바닥의 뒤쪽 끝(벽과 만나는 곳)과 앞쪽 끝
  static const double floorBack = 0.80;
  static const double floorFront = 0.985;
}

// 길드에 그리는 친구 수 (너무 많으면 폰이 버거워서)
const int _maxWalkers = 8;

class _GuildScreenState extends State<GuildScreen> {
  final ValueNotifier<Offset> _move = ValueNotifier(Offset.zero);
  final List<StreamSubscription<List<FriendRequest>>> _subs = [];
  List<FriendRequest> _sent = const [];
  List<FriendRequest> _received = const [];
  final Map<String, RankingEntry?> _entries = {}; // uid -> 랭킹 줄 (없으면 null)

  String get _me => widget.userId;

  @override
  void initState() {
    super.initState();
    if (!widget.user.isGuest) {
      _subs.add(
        FriendRepository.instance.watchSent(_me).listen((list) {
          _sent = list;
          _refresh();
        }),
      );
      _subs.add(
        FriendRepository.instance.watchReceived(_me).listen((list) {
          _received = list;
          _refresh();
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _move.dispose();
    super.dispose();
  }

  List<FriendRequest> get _friends => [
    ..._sent.where((r) => r.accepted),
    ..._received.where((r) => r.accepted),
  ];
  List<FriendRequest> get _incoming =>
      _received.where((r) => !r.accepted).toList();
  List<FriendRequest> get _outgoing => _sent.where((r) => !r.accepted).toList();

  // 새로 보이는 사람의 이름과 겉모습을 랭킹에서 받아 옵니다.
  Future<void> _refresh() async {
    final Set<String> uids = {
      for (final r in [..._sent, ..._received]) r.otherOf(_me),
    };
    final List<String> missing = uids
        .where((uid) => !_entries.containsKey(uid))
        .toList();
    if (mounted) setState(() {});
    for (final uid in missing) {
      try {
        _entries[uid] = await RankingRepository.instance.entryOf(uid);
      } catch (_) {
        _entries[uid] = null;
      }
    }
    if (mounted && missing.isNotEmpty) setState(() {});
  }

  List<List<String>> get _walkers => [
    for (final r in _friends.take(_maxWalkers))
      if (_entries[r.otherOf(_me)] case final RankingEntry e)
        CharacterOutfit.partsFor(
          e.look ?? CharacterLook.female,
          e.equippedSetId,
          dogStage: e.dogStage,
        ),
  ];

  // 사진을 꽉 차게(cover) 아래쪽에 맞춰 깔았을 때 사진이 놓이는 자리
  static Rect _coverRect(Size box) {
    final double scale = max(
      box.width / _Room.size.width,
      box.height / _Room.size.height,
    );
    final double w = _Room.size.width * scale, h = _Room.size.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, box.height - h, w, h);
  }

  void _openFriends() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _Palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _FriendsSheet(
        me: _me,
        user: widget.user,
        // 열린 동안에도 새 신청·수락이 바로 보이게 이 화면의 값을 그대로 읽습니다.
        state: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserModel user = widget.user;
    final int pending = _incoming.length;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final Size box = constraints.biggest;
          final Rect room = _coverRect(box);
          Rect inRoom(Rect r) => Rect.fromLTRB(
            room.left + r.left * room.width,
            room.top + r.top * room.height,
            room.left + r.right * room.width,
            room.top + r.bottom * room.height,
          );
          final Rect frame = inRoom(_Room.frame);
          final double floorBack =
              (room.top + _Room.floorBack * room.height) / box.height;
          final double floorFront = min(
            0.975,
            (room.top + _Room.floorFront * room.height) / box.height,
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: room,
                child: Image.asset(
                  _Room.asset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Positioned.fromRect(
                rect: frame,
                child: _Portrait(user: user),
              ),
              Positioned.fill(
                child: CharacterView(
                  me: user.parts(),
                  guild: true,
                  friends: _walkers,
                  move: _move,
                  floorBack: floorBack,
                  floorFront: floorFront,
                ),
              ),
              // 위: 뒤로 · 이름 · 친구
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: _Palette.paper,
                          ),
                        ),
                        Text(
                          '나의 길드',
                          style: AppTheme.serifNumber.copyWith(
                            fontSize: 20,
                            color: _Palette.paper,
                          ),
                        ),
                        const Spacer(),
                        _FriendButton(pending: pending, onTap: _openFriends),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                bottom: AppSpacing.lg + MediaQuery.of(context).padding.bottom,
                child: _Joystick(value: _move),
              ),
            ],
          );
        },
      ),
    );
  }
}

// 이 화면에서 쓰는 색. 쨍한 금색 대신 바랜 놋쇠만 씁니다.
class _Palette {
  static const Color brass = Color(0xFFB59A6A);
  static const Color brassDark = Color(0xFF6E5A3C);
  static const Color paper = Color(0xFFEDE3CF);
  static const Color sheet = Color(0xFF1E1A17);
  static const Color line = Color(0xFF3A332D);
}

// 액자 속 길드장 초상화. 캐릭터 그림을 픽셀로 뭉개서 유화처럼 겁니다.
class _Portrait extends StatelessWidget {
  final UserModel user;

  const _Portrait({required this.user});

  @override
  Widget build(BuildContext context) {
    final CharacterLook? look = user.look;
    return LayoutBuilder(
      builder: (context, c) {
        final double plateW = min(c.maxWidth * 0.62, 190);
        return Stack(
          alignment: Alignment.center,
          children: [
            // 그림 바탕: 어두운 방에 은은한 불빛이 든 듯한 갈색 번짐
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.7,
                    colors: [
                      const Color(0xFF6B5843).withValues(alpha: 0.55),
                      const Color(0xFF2B241E).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: c.maxHeight * 0.08,
              bottom: c.maxHeight * 0.2,
              left: 0,
              right: 0,
              child: look == null
                  ? Center(
                      child: Text(
                        '?',
                        style: AppTheme.serifNumber.copyWith(
                          fontSize: 80,
                          color: _Palette.brassDark,
                        ),
                      ),
                    )
                  : Opacity(
                      opacity: 0.92,
                      child: look.isDog
                          ? LookImage(
                              asset: CharacterOutfit.cardFor(look, null),
                              dogStage: user.dogStage,
                            )
                          // 사람 그림은 아주 작게 읽어서(36칸) 칸 그대로 키웁니다.
                          : ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.85, 0.1, 0.05, 0, 6, //
                                0.08, 0.82, 0.05, 0, 4, //
                                0.06, 0.1, 0.7, 0, 0, //
                                0, 0, 0, 1, 0, //
                              ]),
                              child: Image.asset(
                                CharacterOutfit.cardFor(
                                  look,
                                  user.visibleSetId,
                                ),
                                fit: BoxFit.contain,
                                cacheWidth: 36,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                    ),
            ),
            // 놋쇠 이름판
            Positioned(
              bottom: c.maxHeight * 0.06,
              child: Container(
                width: plateW,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      _Palette.brassDark,
                      _Palette.brass,
                      _Palette.brassDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF4A3C28)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '길드장 · ${user.nickname}',
                  style: AppTheme.serifNumber.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF2A2117),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FriendButton extends StatelessWidget {
  final int pending;
  final VoidCallback onTap;

  const _FriendButton({required this.pending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _Palette.brass.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, size: 18, color: _Palette.paper),
            const SizedBox(width: 6),
            Text(
              '친구',
              style: AppTheme.sans.copyWith(
                fontSize: 13,
                fontWeight: AppTheme.sansMedium,
                color: _Palette.paper,
              ),
            ),
            if (pending > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFA0473A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pending',
                  style: AppTheme.number.copyWith(
                    fontSize: 11,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 조이스틱. 가운데에서 민 방향과 거리(0~1)를 넘깁니다. (위가 +y)
class _Joystick extends StatefulWidget {
  final ValueNotifier<Offset> value;

  const _Joystick({required this.value});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  static const double _size = 128;
  static const double _knob = 52;
  Offset _knobAt = Offset.zero; // 가운데 기준 (화면 좌표, 아래가 +y)

  void _update(Offset local) {
    const double radius = (_size - _knob) / 2;
    Offset d = local - const Offset(_size / 2, _size / 2);
    if (d.distance > radius) d = d / d.distance * radius;
    setState(() => _knobAt = d);
    widget.value.value = Offset(d.dx / radius, -d.dy / radius);
  }

  void _release() {
    setState(() => _knobAt = Offset.zero);
    widget.value.value = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(
                  color: _Palette.brass.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
            ),
            Transform.translate(
              offset: _knobAt,
              child: Container(
                width: _knob,
                height: _knob,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    colors: [
                      Color(0xFFD7C7A3),
                      _Palette.brass,
                      _Palette.brassDark,
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 친구 창 (아래에서 올라옵니다)
//   내 번호 · 번호로 추가 · 내 친구 링크 공유 · 받은 신청(수락/거절) · 보낸 신청(취소) · 친구(끊기)
//   (QR은 앱 안에서 찍지 않습니다. 휴대폰 카메라로 플레이어 카드 QR을 찍으면 링크로 열립니다)
// ============================================================
class _FriendsSheet extends StatefulWidget {
  final String me;
  final UserModel user;
  final _GuildScreenState state;

  const _FriendsSheet({
    required this.me,
    required this.user,
    required this.state,
  });

  @override
  State<_FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<_FriendsSheet> {
  final TextEditingController _number = TextEditingController();
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 길드 화면이 새 목록을 받으면 이 창도 다시 그립니다.
    _tick = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _number.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _toast(done);
    } on FriendException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('잠시 후 다시 시도해 주세요. ($e)');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addByNumber() async {
    final String digits = _number.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 8) {
      _toast('플레이어 번호 8자리를 넣어 주세요.');
      return;
    }
    await _run(() async {
      final RankingEntry? entry = await RankingRepository.instance
          .findByPlayerNo(digits);
      if (entry == null) {
        throw const FriendException('그 번호의 플레이어를 찾지 못했어요.');
      }
      await FriendRepository.instance.request(widget.me, entry.userId);
    }, '친구 신청을 보냈어요.');
    _number.clear();
  }

  // 내 친구 링크를 공유합니다. 받은 사람이 누르면 코인런이 열리고 친구 요청을 보낼지 묻습니다.
  Future<void> _shareLink() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '코인런에서 친구 해요! (No. ${PlayerNumber.of(widget.me)})\n'
              '${FriendRepository.linkFor(widget.me)}',
        ),
      );
    } catch (_) {
      _toast('공유하지 못했어요.');
    }
  }

  String _nameOf(String uid) =>
      widget.state._entries[uid]?.nickname ?? '불러오는 중…';

  @override
  Widget build(BuildContext context) {
    final _GuildScreenState s = widget.state;
    final TextStyle head = AppTheme.caption.copyWith(
      fontSize: 10,
      color: _Palette.brass,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _Palette.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '친구',
              style: AppTheme.serifNumber.copyWith(
                fontSize: 22,
                color: _Palette.paper,
              ),
            ),
            const SizedBox(height: 4),
            if (widget.user.isGuest)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '게스트는 랭킹에 없어서 친구를 추가하거나 받을 수 없어요.\n'
                  '설정에서 이메일 계정을 연결해 주세요.',
                  style: AppTheme.sans.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.sandOnDark,
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    '내 번호  No. ${PlayerNumber.of(widget.me)}',
                    style: AppTheme.sans.copyWith(
                      fontSize: 12,
                      color: AppColors.sandOnDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: PlayerNumber.of(widget.me)),
                      );
                      _toast('번호를 복사했어요.');
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 14,
                      color: _Palette.brass,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('ADD FRIEND', style: head),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _number,
                      keyboardType: TextInputType.number,
                      maxLength: 9,
                      style: AppTheme.number.copyWith(
                        fontSize: 16,
                        letterSpacing: 2,
                        color: _Palette.paper,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '플레이어 번호 8자리',
                        hintStyle: AppTheme.sans.copyWith(
                          fontSize: 13,
                          color: AppColors.mute,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _Palette.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _Palette.line),
                        ),
                      ),
                      onSubmitted: (_) => _addByNumber(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SheetButton(
                    label: '신청',
                    filled: true,
                    onTap: _busy ? null : _addByNumber,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SheetButton(
                icon: Icons.ios_share,
                label: '내 친구 링크 공유',
                onTap: _shareLink,
              ),
              const SizedBox(height: 20),
              if (s._incoming.isNotEmpty) ...[
                Text('받은 신청', style: head),
                for (final r in s._incoming)
                  _PersonRow(
                    name: _nameOf(r.fromId),
                    entry: s._entries[r.fromId],
                    actions: [
                      _SheetButton(
                        label: '수락',
                        filled: true,
                        onTap: _busy
                            ? null
                            : () => _run(
                                () => FriendRepository.instance.accept(r),
                                '친구가 되었어요.',
                              ),
                      ),
                      const SizedBox(width: 6),
                      _SheetButton(
                        label: '거절',
                        onTap: _busy
                            ? null
                            : () => _run(
                                () => FriendRepository.instance.remove(r),
                                '거절했어요.',
                              ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
              Text('친구 ${s._friends.length}명', style: head),
              if (s._friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '아직 친구가 없어요. 번호로 신청하거나 내 친구 링크를 보내 보세요.',
                    style: AppTheme.sans.copyWith(
                      fontSize: 12,
                      color: AppColors.sandOnDark,
                    ),
                  ),
                ),
              for (final r in s._friends)
                _PersonRow(
                  name: _nameOf(r.otherOf(widget.me)),
                  entry: s._entries[r.otherOf(widget.me)],
                  actions: [
                    _SheetButton(
                      label: '끊기',
                      onTap: _busy
                          ? null
                          : () => _run(
                              () => FriendRepository.instance.remove(r),
                              '친구를 끊었어요.',
                            ),
                    ),
                  ],
                ),
              if (s._outgoing.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('보낸 신청', style: head),
                for (final r in s._outgoing)
                  _PersonRow(
                    name: _nameOf(r.toId),
                    entry: s._entries[r.toId],
                    actions: [
                      _SheetButton(
                        label: '취소',
                        onTap: _busy
                            ? null
                            : () => _run(
                                () => FriendRepository.instance.remove(r),
                                '신청을 취소했어요.',
                              ),
                      ),
                    ],
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String name;
  final RankingEntry? entry;
  final List<Widget> actions;

  const _PersonRow({
    required this.name,
    required this.entry,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final RankingEntry? e = entry;
    final CharacterLook? look = e?.look;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Palette.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2E2823),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: look == null
                ? null
                : LookImage(
                    asset: CharacterOutfit.faceFor(look, e!.equippedSetId),
                    dogStage: look.isDog ? e.dogStage : null,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.sans.copyWith(
                    fontSize: 14,
                    fontWeight: AppTheme.sansMedium,
                    color: _Palette.paper,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (e != null)
                  Text(
                    'Lv.${e.level}',
                    style: AppTheme.sans.copyWith(
                      fontSize: 11,
                      color: AppColors.sandOnDark,
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback? onTap;

  const _SheetButton({
    required this.label,
    this.icon,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = filled ? const Color(0xFF231C14) : _Palette.paper;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: filled ? _Palette.brass : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: filled ? _Palette.brass : _Palette.brassDark,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppTheme.sans.copyWith(
                  fontSize: 13,
                  fontWeight: AppTheme.sansMedium,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
