import 'package:flutter/material.dart';

import '../game/backdrop_catalog.dart';
import '../game/character_outfit.dart';
import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/honor_level.dart';
import '../game/pet_catalog.dart';
import '../game/run_rules.dart';
import '../models/equipment_set.dart';
import '../models/user_model.dart';
import '../services/course_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/character_view.dart';
import '../widgets/gold_coin.dart';
import '../widgets/notched_box.dart';
import 'guild_screen.dart';
import 'shop_screen.dart';

// ============================================================
// 내 캐릭터
//
// 흰 바탕 전체에 3D 캐릭터를 세우고, 그 위에 반투명한 것들을 얹습니다.
//
//   [여자|남자]          LV.10 · BRONZE
//                          닉네임            ┌ STATUS 더보기┐
//                                            │ 힘 3  체력 3 │
//               (3D 캐릭터, 숨 쉬는 중)       │ 속도 0 명예 - │
//                                            └ INVENTORY ▾ ┘
//   [잡화점 (반투명)]           [나의 길드 (반투명)]
//
// 상태창은 늘 보이고, 더보기를 누르면 능력치마다 무엇이 오르는지 펼칩니다.
// 인벤토리에서는 보이는 옷과 능력치 옷을 따로 고릅니다.
// 왼쪽 위에서 캐릭터를 고릅니다. 윗줄은 여자·남자, 아랫줄은 강아지(허스키·리트리버).
// 강아지는 옷을 입지 않고(능력치 옷만 고름), 간식을 먹을수록 3단계로 자랍니다.
// 캐릭터는 끌면 돌고, 두 손가락으로 벌리면 조금 커집니다.
// 남/여를 아직 고르지 않은 사람에게는 물음표를 보여줍니다.
// ============================================================
class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// 유저 문서를 계속 지켜봅니다. 잡화점에서 옷을 입고 돌아오면 캐릭터가 바로 갈아입습니다.
class _ProfileScreenState extends State<ProfileScreen> {
  late final Stream<UserModel?> _user = UserRepository.instance.watchUser(
    widget.userId,
  );
  late final Stream<HonorLevel> _honor = CourseRepository.instance.watchHonor(
    widget.userId,
  );

  // 고르자마자 바뀌어 보이게 저장이 끝나기 전 값을 잠깐 들고 있습니다.
  CharacterLook? _pending;

  // 아직 사지 않은 세트 중 가장 싼 것 = 다음에 노릴 장비. 다 샀으면 null입니다.
  static EquipmentSet? _nextSet(UserModel user) {
    for (final set in EquipmentCatalog.all) {
      if (!user.owns(set.id)) return set;
    }
    return null;
  }

  // 강아지 이름 짓기 (최대 10자)
  Future<void> _renameDog(UserModel user, CharacterLook dog) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _DogNameDialog(dog: dog, initial: user.dogNameOf(dog.id) ?? ''),
    );
    if (name == null || !mounted) return;
    try {
      await UserRepository.instance.setDogName(widget.userId, dog, name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요.')));
    }
  }

  Future<void> _pickLook(CharacterLook look) async {
    setState(() => _pending = look);
    try {
      await UserRepository.instance.setLook(widget.userId, look);
    } catch (error) {
      if (!mounted) return;
      setState(() => _pending = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 눌러 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: _user,
      builder: (context, snapshot) {
        final UserModel? user = snapshot.data;
        if (user == null) {
          return const Scaffold(
            backgroundColor: AppColors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_pending != null && _pending == user.look) _pending = null;
        return _build(context, user, _pending ?? user.look);
      },
    );
  }

  Widget _build(BuildContext context, UserModel user, CharacterLook? look) {
    final EquipmentSet? next = _nextSet(user);
    final Backdrop backdrop = user.backdrop;
    // 어두운 배경이면 위 막대도 어둡게 맞춥니다.
    final Color barColor = backdrop.dark ? AppColors.black : AppColors.white;
    final Color barText = backdrop.dark ? AppColors.white : AppColors.black;
    return Scaffold(
      backgroundColor: backdrop.color ?? AppColors.white,
      appBar: AppBar(
        backgroundColor: barColor,
        foregroundColor: barText,
        surfaceTintColor: Colors.transparent,
        title: Text('내 캐릭터', style: TextStyle(color: barText)),
        actions: [
          _GoldChip(gold: user.gold),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // 맨 뒤: 고른 배경 (단색이거나 살짝 픽셀화한 그림). 3D 화면은 투명이라 뒤로 비칩니다.
            Positioned.fill(child: _BackdropView(backdrop: backdrop)),
            // 캐릭터가 화면 전체를 씁니다. 위아래 상자는 반투명이라 뒤로 비칩니다.
            Positioned.fill(
              top: 44,
              child: look == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '?',
                            style: AppTheme.serifNumber.copyWith(
                              fontSize: 96,
                              color: AppColors.sand,
                            ),
                          ),
                          Text(
                            '왼쪽 위에서 캐릭터를 골라 주세요',
                            style: AppTheme.sans.copyWith(
                              fontSize: 13,
                              color: AppColors.label,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CharacterView(
                      me: CharacterOutfit.partsFor(
                        look,
                        user.visibleSetId,
                        dogStage: PetCatalog.stageFor(user.fedOf(look.id)),
                      ),
                    ),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: 0,
              right: 0,
              child: Center(
                child: _NamePlate(
                  user: user,
                  look: look,
                  onRenameDog: () => _renameDog(user, look!),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in [
                    CharacterLook.humans,
                    CharacterLook.dogs,
                  ]) ...[
                    Row(
                      children: [
                        for (final option in row)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: _LookChip(
                              label: option.label,
                              selected: option == look,
                              onTap: () => _pickLook(option),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
            // 오른쪽 위: 상태창(늘 보임) -> 그 아래 인벤토리(화살표로 펴고 접기)
            // 머리를 가리지 않게 좁게 둡니다. 인벤토리는 펼칠 때만 넓어집니다.
            Positioned(
              top: 52,
              right: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StreamBuilder<HonorLevel>(
                    stream: _honor,
                    builder: (context, honor) =>
                        _StatusWindow(user: user, honor: honor.data),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Inventory(
                    userId: widget.userId,
                    user: user,
                    look: look ?? CharacterLook.female,
                  ),
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Row(
                children: [
                  Expanded(
                    child: NotchedBox(
                      cut: 12,
                      color: AppColors.black.withValues(alpha: 0.86),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md - 2,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ShopScreen(userId: widget.userId),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '잡화점',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppColors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            next == null ? '전부 갖췄습니다' : '다음 단계 · ${next.name}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.sand),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _GuildSlot(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GuildScreen(userId: widget.userId, user: user),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 이름표: 테두리 없이 작게
class _NamePlate extends StatelessWidget {
  final UserModel user;
  final CharacterLook? look;
  final VoidCallback onRenameDog;

  const _NamePlate({
    required this.user,
    required this.look,
    required this.onRenameDog,
  });

  @override
  Widget build(BuildContext context) {
    final CharacterLook? current = look;
    final String? dogName = current != null && current.isDog
        ? user.dogNameOf(current.id)
        : null;
    // 배경이 사진이거나 어두워도 읽히게 작은 반투명 판 위에 둡니다.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LV.${user.level} · ${RunRules.tierName(user.level).split(' ').first.toUpperCase()}',
            style: AppTheme.caption.copyWith(fontSize: 9.5),
          ),
          const SizedBox(height: 1),
          Text(
            user.nickname,
            style: AppTheme.serifNumber.copyWith(
              fontSize: 17,
              color: AppColors.black,
            ),
          ),
          // 강아지면 그 아래에 강아지 이름. 누르면 이름을 짓거나 바꿉니다.
          if (current != null && current.isDog)
            GestureDetector(
              onTap: onRenameDog,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dogName ?? '${current.label} 이름 짓기',
                      style: AppTheme.sans.copyWith(
                        fontSize: 12,
                        fontWeight: AppTheme.sansMedium,
                        color: dogName == null
                            ? AppColors.accent
                            : AppColors.black,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.edit, size: 12, color: AppColors.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 강아지 이름 창. 입력칸을 이 창이 직접 들고 있다가, 창이 다 닫힌 뒤에 지웁니다.
// (예전에는 창이 닫히는 도중에 입력칸을 지워서 오류가 났습니다)
class _DogNameDialog extends StatefulWidget {
  final CharacterLook dog;
  final String initial;

  const _DogNameDialog({required this.dog, required this.initial});

  @override
  State<_DogNameDialog> createState() => _DogNameDialogState();
}

class _DogNameDialogState extends State<_DogNameDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.dog.label} 이름'),
      content: TextField(
        controller: _field,
        autofocus: true,
        maxLength: 10,
        decoration: const InputDecoration(hintText: '이름을 지어 주세요'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _field.text),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

// 남/여 고르기
class _LookChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LookChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.black, width: 1.2),
        ),
        child: Text(
          label,
          style: AppTheme.sans.copyWith(
            fontSize: 12,
            fontWeight: AppTheme.sansMedium,
            color: selected ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}

// 반투명 판. 상태창과 인벤토리가 같이 씁니다. 뒤로 캐릭터가 비칩니다.
class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md - 2,
        AppSpacing.sm,
        AppSpacing.md - 2,
        AppSpacing.sm,
      ),
      // 배경 그림 위에서도 글자가 잘 읽히게 거의 불투명하게 깝니다.
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.sand),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// 상태창: 힘, 체력, 속도, 명예를 두 줄로 작게 늘 보여줍니다.
// 작은 "더보기"를 누르면 각각 무엇을 올려주는지 한 줄씩 펼칩니다.
class _StatusWindow extends StatefulWidget {
  final UserModel user;
  final HonorLevel? honor;

  const _StatusWindow({required this.user, required this.honor});

  // 상태창과 접힌 인벤토리의 너비. 캐릭터 머리를 가리지 않을 만큼만.
  static const double width = 118;

  @override
  State<_StatusWindow> createState() => _StatusWindowState();
}

class _StatusWindowState extends State<_StatusWindow> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final EquipmentSet? gear = EquipmentRules.equippedSet(widget.user);
    final int honorLevel = widget.honor?.level ?? 0;
    final int power = gear?.power ?? 0;
    final int stamina = gear?.stamina ?? 0;
    // (이름, 값, 더보기에서 보여줄 설명)
    final List<(String, String, String)> rows = [
      ('힘', '$power', '골드 +$power%'),
      ('체력', '$stamina', '경험치 +$stamina%'),
      ('속도', '${gear?.speed ?? 0}', '아직 안 씀'),
      ('명예', honorLevel == 0 ? '-' : '$honorLevel', '코스 하트로 오름'),
    ];
    final TextStyle label = AppTheme.sans.copyWith(
      fontSize: 10.5,
      color: AppColors.label,
    );
    final TextStyle value = AppTheme.number.copyWith(fontSize: 12);

    Widget cell((String, String, String) row) => Expanded(
      child: Row(
        children: [
          Text(row.$1, style: label),
          const SizedBox(width: 3),
          Text(row.$2, style: value),
        ],
      ),
    );

    return SizedBox(
      width: _StatusWindow.width,
      child: _GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('STATUS', style: AppTheme.caption.copyWith(fontSize: 8.5)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _more = !_more),
                  child: Text(
                    _more ? '접기' : '더보기',
                    style: AppTheme.sans.copyWith(
                      fontSize: 9.5,
                      fontWeight: AppTheme.sansMedium,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (_more)
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 26, child: Text(row.$1, style: label)),
                      Text(row.$2, style: value),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          row.$3,
                          style: AppTheme.sans.copyWith(
                            fontSize: 9,
                            color: AppColors.accentDeep,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
            else ...[
              Row(children: [cell(rows[0]), cell(rows[1])]),
              const SizedBox(height: 1),
              Row(children: [cell(rows[2]), cell(rows[3])]),
            ],
          ],
        ),
      ),
    );
  }
}

// 인벤토리: 화살표로 펴고 접습니다.
//   옷   - 가진 옷(기본 옷 포함). 옷마다 [보이기] [능력치]를 따로 고릅니다.
//          보이는 옷과 능력치를 받는 옷을 다르게 입을 수 있습니다.
class _Inventory extends StatefulWidget {
  final String userId;
  final UserModel user;
  final CharacterLook look;

  const _Inventory({
    required this.userId,
    required this.user,
    required this.look,
  });

  @override
  State<_Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<_Inventory> {
  bool _open = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? message;
    try {
      await action();
    } on EquipmentException catch (error) {
      message = error.message;
    } catch (_) {
      message = '잠시 후 다시 시도해 주세요.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserModel user = widget.user;
    // 기본 옷(null)과 사 둔 옷
    final List<EquipmentSet?> clothes = [
      null,
      for (final EquipmentSet set in EquipmentCatalog.all)
        if (user.owns(set.id)) set,
    ];
    return SizedBox(
      // 접혀 있으면 상태창만큼 좁고, 펼치면 버튼이 들어갈 만큼 넓어집니다.
      width: _open ? 188 : _StatusWindow.width,
      child: _GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: [
                  Text(
                    'INVENTORY',
                    style: AppTheme.caption.copyWith(fontSize: 8.5),
                  ),
                  const Spacer(),
                  Icon(
                    _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: AppColors.black,
                  ),
                ],
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 4),
              Text(
                '배경',
                style: AppTheme.sans.copyWith(
                  fontSize: 11,
                  fontWeight: AppTheme.sansMedium,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 3),
              _BackdropRow(
                user: user,
                onPick: (backdrop) {
                  if (!user.ownsBackdrop(backdrop)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${backdrop.name} 배경은 잡화점에서 살 수 있어요.'),
                      ),
                    );
                    return;
                  }
                  _run(
                    () => UserRepository.instance.setBackdrop(
                      widget.userId,
                      backdrop,
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              for (final set in clothes)
                _ClothesRow(
                  // 강아지는 옷을 입지 않아서 여자 옷 그림으로 보여주고 능력치만 고릅니다.
                  icon: CharacterOutfit.iconFor(
                    widget.look.isDog ? CharacterLook.female : widget.look,
                    set?.id,
                  ),
                  name: set?.name ?? '기본 옷',
                  canShow: !widget.look.isDog,
                  shown: user.visibleSetId == set?.id,
                  powered: user.equippedSetId == set?.id,
                  onShow: () => _run(
                    () => UserRepository.instance.wearOutfit(
                      widget.userId,
                      set?.id,
                    ),
                  ),
                  onPower: () => _run(
                    () => UserRepository.instance.equipSet(
                      widget.userId,
                      set?.id,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                '간식 ×${user.snacks}',
                style: AppTheme.sans.copyWith(
                  fontSize: 11,
                  fontWeight: AppTheme.sansMedium,
                  color: AppColors.black,
                ),
              ),
              if (widget.look.isDog)
                _PetRow(
                  pet: widget.look,
                  fed: user.fedOf(widget.look.id),
                  onFeed: () => _run(
                    () => UserRepository.instance.feedPet(
                      widget.userId,
                      widget.look,
                    ),
                  ),
                )
              else
                Text(
                  '강아지 캐릭터에게 줄 수 있어요',
                  style: AppTheme.sans.copyWith(
                    fontSize: 9.5,
                    color: AppColors.label,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// 옷 한 줄: [그림] 이름  [보이기] [능력치]
class _ClothesRow extends StatelessWidget {
  final String icon;
  final String name;
  final bool canShow; // 강아지는 옷을 입지 않아서 [보이기]가 없습니다.
  final bool shown;
  final bool powered;
  final VoidCallback onShow;
  final VoidCallback onPower;

  const _ClothesRow({
    required this.icon,
    required this.name,
    this.canShow = true,
    required this.shown,
    required this.powered,
    required this.onShow,
    required this.onPower,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Image.asset(
              icon,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: AppTheme.sans.copyWith(
                fontSize: 12,
                fontWeight: AppTheme.sansMedium,
                color: AppColors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canShow) ...[
            _TinyToggle(label: '보이기', on: shown, onTap: onShow),
            const SizedBox(width: 3),
          ],
          _TinyToggle(label: '능력치', on: powered, onTap: onPower),
        ],
      ),
    );
  }
}

// 강아지 한 줄: 이름 · 단계 (다음까지 남은 간식)  [간식 주기]
class _PetRow extends StatelessWidget {
  final CharacterLook pet;
  final int fed;
  final VoidCallback onFeed;

  const _PetRow({required this.pet, required this.fed, required this.onFeed});

  @override
  Widget build(BuildContext context) {
    final int stage = PetCatalog.stageFor(fed);
    final int? left = PetCatalog.snacksToNext(fed);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pet.label} · $stage단계',
                  style: AppTheme.sans.copyWith(
                    fontSize: 12,
                    fontWeight: AppTheme.sansMedium,
                    color: AppColors.black,
                  ),
                ),
                Text(
                  left == null ? '다 자랐어요' : '다음 단계까지 간식 $left개',
                  style: AppTheme.sans.copyWith(
                    fontSize: 9.5,
                    color: AppColors.label,
                  ),
                ),
              ],
            ),
          ),
          _TinyToggle(label: '간식 주기', on: false, onTap: onFeed),
        ],
      ),
    );
  }
}

// 작은 글자 버튼. 켜져 있으면 검은 바탕입니다.
class _TinyToggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _TinyToggle({
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 옷은 하나는 꼭 입어야 해서, 켜진 것을 다시 눌러 끌 수는 없습니다.
      onTap: on ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: on ? AppColors.black : AppColors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.black, width: 1),
        ),
        child: Text(
          label,
          style: AppTheme.sans.copyWith(
            fontSize: 10,
            fontWeight: AppTheme.sansMedium,
            color: on ? AppColors.white : AppColors.black,
          ),
        ),
      ),
    );
  }
}

// 나의 길드. 누르면 길드에 들어갑니다. (친구 추가, 함께 걷기)
class _GuildSlot extends StatelessWidget {
  final VoidCallback onTap;

  const _GuildSlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: DashedBox(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md - 2,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '나의 길드',
                      style: textTheme.titleMedium?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text('친구와 함께', style: textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 내 캐릭터 화면 맨 뒤의 배경. 그림은 작게 줄여 둔 것을 칸 그대로 키워 픽셀 느낌을 냅니다.
class _BackdropView extends StatelessWidget {
  final Backdrop backdrop;

  const _BackdropView({required this.backdrop});

  @override
  Widget build(BuildContext context) {
    final String? asset = backdrop.asset;
    if (asset == null) {
      return ColoredBox(color: backdrop.color ?? AppColors.white);
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.none,
    );
  }
}

// 인벤토리의 배경 고르기: 작은 그림 네 개를 가로로
//   가진 것은 눌러서 바로 바꾸고, 안 가진 것은 흐리게 자물쇠를 얹어 둡니다.
class _BackdropRow extends StatelessWidget {
  final UserModel user;
  final void Function(Backdrop backdrop) onPick;

  const _BackdropRow({required this.user, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final b in BackdropCatalog.all)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _BackdropThumb(
              backdrop: b,
              owned: user.ownsBackdrop(b),
              selected: user.backdrop.id == b.id,
              onTap: () => onPick(b),
            ),
          ),
      ],
    );
  }
}

class _BackdropThumb extends StatelessWidget {
  final Backdrop backdrop;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  const _BackdropThumb({
    required this.backdrop,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 40,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? AppColors.black : AppColors.sand,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: owned ? 1 : 0.35,
              child: _BackdropView(backdrop: backdrop),
            ),
            if (!owned)
              const Center(
                child: Icon(Icons.lock, size: 12, color: AppColors.black),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoldChip extends StatelessWidget {
  final int gold;

  const _GoldChip({required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm - 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accent, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GoldCoin(size: 20),
          const SizedBox(width: AppSpacing.sm - 2),
          // 색을 꼭 적습니다. 안 적으면 어두운 배경일 때 위 막대의 흰 글자색을 따라가서
          // 흰 칸 위에서 숫자가 사라집니다.
          Text(
            '$gold',
            style: AppTheme.number.copyWith(
              fontSize: 16,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
