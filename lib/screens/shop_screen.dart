import 'package:flutter/material.dart';

import '../game/backdrop_catalog.dart';
import '../game/character_outfit.dart';
import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/pet_catalog.dart';
import '../models/equipment_set.dart';
import '../models/user_model.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_coin.dart';

// ============================================================
// 잡화점 - 정장 입은 고블린 상인이 운영하는 고급 상점
//
//   ┌──────────────────────────────┐
//   │ [고블린]  "어서 오십시오, 손님…" │  <- 상인과 말풍선 (정중하고 우아한 말투)
//   ├──────────── 진열대 ────────────┤
//   │ ◆ 의복                         │
//   │  [그림] 천옷  힘3 체력3   ◎500  │  <- 놋쇠 테두리 진열 칸
//   │ ◆ 간식                         │
//   │  [그림] 간식  ──●── 12개 ◎960   │  <- 끌어서 개수 고르기 (1~50)
//   │ ◆ 배경                         │
//   │  [그림] 안개 들판        ◎1,500  │  <- 내 캐릭터 화면 배경
//   └──────────────────────────────┘
//
// 사기만 합니다. 산 옷을 입거나 간식을 주는 것은 내 캐릭터 > 인벤토리에서 합니다.
// 이미 산 옷과 배경은 진열대에서 빠집니다.
// ============================================================

// 상점 색. 짙은 마호가니 바탕에 놋쇠 테두리, 벨벳 진열 칸.
const Color _wood = Color(0xFF231812); // 바탕 (짙은 마호가니)
const Color _woodLight = Color(0xFF3A281D); // 상인 자리 위쪽 빛
const Color _velvet = Color(0xFF2E1F1A); // 진열 칸 안
const Color _brass = Color(0xFFC9A45C); // 놋쇠 테두리, 금 글씨
const Color _brassDim = Color(0xFF7D6538); // 흐린 놋쇠 (구분선)
const Color _parchment = Color(0xFFF1E4C6); // 말풍선, 가격표 종이
const Color _ink = Color(0xFF2A1D14); // 종이 위 글씨

class ShopScreen extends StatefulWidget {
  final String userId;

  const ShopScreen({super.key, required this.userId});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // 스트림은 한 번만 만들어 둡니다. (build 안에서 만들면 다시 그릴 때마다 새로 연결됨)
  late final Stream<UserModel?> _userStream = UserRepository.instance.watchUser(
    widget.userId,
  );

  bool _isBusy = false; // 버튼을 두 번 누르지 못하게 잠그는 값

  // 사기를 실행하고, 결과를 아래쪽 알림 띠로 알려줍니다.
  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    String message = successMessage;
    try {
      await action();
    } on EquipmentException catch (error) {
      message = error.message;
    } catch (_) {
      message = '잠시 후 다시 시도해 주세요.';
    }
    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _wood,
      appBar: AppBar(
        backgroundColor: _wood,
        foregroundColor: _brass,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '잡화점',
          style: AppTheme.serifNumber.copyWith(fontSize: 20, color: _brass),
        ),
        actions: [
          StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, snapshot) =>
                _GoldChip(gold: snapshot.data?.gold ?? 0),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userStream,
        builder: (context, snapshot) {
          final UserModel? user = snapshot.data;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: _brass),
            );
          }

          final List<EquipmentSet> forSale = [
            for (final EquipmentSet set in EquipmentCatalog.all)
              if (!user.owns(set.id)) set,
          ];
          final List<Backdrop> backdrops = [
            for (final Backdrop b in BackdropCatalog.forSale)
              if (!user.ownsBackdrop(b)) b,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              _Merchant(soldOut: forSale.isEmpty),
              const _BrassRule(),
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle('의복'),
              if (forSale.isEmpty) const _SoldOutNote('옷은 전부 갖췄습니다'),
              for (final set in forSale) ...[
                _SetCard(
                  set: set,
                  user: user,
                  isBusy: _isBusy,
                  onBuy: () => _run(
                    () => UserRepository.instance.buySet(widget.userId, set.id),
                    '${set.name}을(를) 샀습니다. 바로 입혀 드렸습니다.',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle('간식'),
              _SnackCard(
                user: user,
                isBusy: _isBusy,
                onBuy: (count) => _run(
                  () => UserRepository.instance.buySnack(widget.userId, count),
                  '간식 $count개를 샀습니다. 강아지 캐릭터에게 줄 수 있습니다.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionTitle('배경'),
              if (backdrops.isEmpty) const _SoldOutNote('배경은 전부 갖췄습니다'),
              for (final b in backdrops) ...[
                _BackdropCard(
                  backdrop: b,
                  user: user,
                  isBusy: _isBusy,
                  onBuy: () => _run(
                    () => UserRepository.instance.buyBackdrop(widget.userId, b),
                    '${b.name} 배경을 샀습니다. 바로 깔아 드렸습니다.',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

// 맨 위 상인 자리: 고블린 상인과 말풍선
class _Merchant extends StatelessWidget {
  final bool soldOut;

  const _Merchant({required this.soldOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: const BoxDecoration(
        // 위에서 비추는 등불처럼 위쪽만 살짝 밝게
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.4),
          radius: 1.1,
          colors: [_woodLight, _wood],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 픽셀 그림이라 키울 때 번지지 않게 가장 가까운 칸 그대로 씁니다.
          Image.asset(
            'assets/icons/goblin_merchant.png',
            height: 140,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: _SpeechBubble(
                text: soldOut
                    ? '의복은 모두 손님 곁으로 갔습니다.\n간식이나 배경도 한번 둘러보시지요.'
                    : '어서 오십시오, 귀한 손님.\n오늘도 엄선한 물건만 갖추어 두었습니다.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 양피지 말풍선. 왼쪽 아래 꼬리가 상인 쪽을 가리킵니다.
class _SpeechBubble extends StatelessWidget {
  final String text;

  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _BubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + 2,
          AppSpacing.md,
          AppSpacing.sm + 2,
        ),
        child: Text(
          text,
          style: AppTheme.serifNumber.copyWith(
            fontSize: 13,
            height: 1.45,
            color: _ink,
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final RRect body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.sm),
    );
    final Path tail = Path()
      ..moveTo(0, size.height - 18)
      ..lineTo(-10, size.height - 4)
      ..lineTo(14, size.height)
      ..close();
    final Path path = Path()
      ..addRRect(body)
      ..addPath(tail, Offset.zero);
    canvas.drawPath(path, Paint()..color = _parchment);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _brass,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}

// 상인 자리와 진열대를 나누는 놋쇠 줄 (가운데 마름모)
class _BrassRule extends StatelessWidget {
  const _BrassRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1.4, color: _brass)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.diamond, size: 10, color: _brass),
        ),
        Expanded(child: Container(height: 1.4, color: _brass)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.diamond_outlined, size: 11, color: _brass),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTheme.serifNumber.copyWith(
              fontSize: 15,
              letterSpacing: 2,
              color: _brass,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Container(height: 1, color: _brassDim)),
        ],
      ),
    );
  }
}

class _SoldOutNote extends StatelessWidget {
  final String text;

  const _SoldOutNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTheme.sans.copyWith(
          fontSize: 13,
          color: AppColors.sandOnDark,
        ),
      ),
    );
  }
}

// 옷 한 벌
//   [그림]  천옷  Lv.1 이상            ◎ 500
//           처음 길을 나서는 ...        [구매]
//           힘 3  체력 3  속도 2
class _SetCard extends StatelessWidget {
  final EquipmentSet set;
  final UserModel user;
  final bool isBusy;
  final VoidCallback onBuy;

  const _SetCard({
    required this.set,
    required this.user,
    required this.isBusy,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final PurchaseCheck check = EquipmentRules.checkPurchase(user, set);
    final bool canBuy = check.isOk && !isBusy;
    final String? reason = check.isOk
        ? null
        : check == PurchaseCheck.lockedByLevel
        ? 'Lv.${set.requiredLevel}부터'
        : '골드가 모자라요';
    return _Showcase(
      // 강아지 캐릭터는 옷을 입지 않아서 여자 옷 그림으로 보여줍니다. (능력치만 받습니다)
      image: CharacterOutfit.iconFor(
        (user.look?.isDog ?? true) ? CharacterLook.female : user.look!,
        set.id,
      ),
      title: set.name,
      tag: 'Lv.${set.requiredLevel} 이상',
      description: set.description,
      below: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _StatChip(label: '힘', value: set.power),
          _StatChip(label: '체력', value: set.stamina),
          _StatChip(label: '속도', value: set.speed),
        ],
      ),
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PriceTag(price: set.price),
          const SizedBox(height: AppSpacing.sm),
          _BuyButton(enabled: canBuy, onTap: onBuy),
          if (reason != null) ...[
            const SizedBox(height: 3),
            Text(
              reason,
              style: AppTheme.sans.copyWith(
                fontSize: 10,
                color: AppColors.sandOnDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 간식. 끌어서 개수(1~50)를 고르고, 개수만큼 값을 냅니다.
class _SnackCard extends StatefulWidget {
  final UserModel user;
  final bool isBusy;
  final void Function(int count) onBuy;

  const _SnackCard({
    required this.user,
    required this.isBusy,
    required this.onBuy,
  });

  @override
  State<_SnackCard> createState() => _SnackCardState();
}

class _SnackCardState extends State<_SnackCard> {
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    const Snack snack = PetCatalog.snack;
    final int total = PetCatalog.snackPrice * _count;
    final bool enough = widget.user.gold >= total;
    final bool canBuy = enough && !widget.isBusy;
    return _Showcase(
      image: snack.asset,
      title: snack.name,
      tag: '가진 개수 ${widget.user.snacks}',
      description:
          '${snack.description}\n하나에 ${_Gold.format(PetCatalog.snackPrice)}골드',
      below: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _brass,
                inactiveTrackColor: _brassDim,
                thumbColor: _parchment,
                overlayColor: _brass.withValues(alpha: 0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _count.toDouble(),
                min: 1,
                max: PetCatalog.maxPerPurchase.toDouble(),
                divisions: PetCatalog.maxPerPurchase - 1,
                onChanged: (value) => setState(() => _count = value.round()),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$_count개',
              textAlign: TextAlign.right,
              style: AppTheme.number.copyWith(fontSize: 13, color: _parchment),
            ),
          ),
        ],
      ),
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PriceTag(price: total),
          const SizedBox(height: AppSpacing.sm),
          _BuyButton(enabled: canBuy, onTap: () => widget.onBuy(_count)),
          if (!enough) ...[
            const SizedBox(height: 3),
            Text(
              '골드가 모자라요',
              style: AppTheme.sans.copyWith(
                fontSize: 10,
                color: AppColors.sandOnDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 배경 한 장. 그림을 작게 보여주고 값을 받습니다.
class _BackdropCard extends StatelessWidget {
  final Backdrop backdrop;
  final UserModel user;
  final bool isBusy;
  final VoidCallback onBuy;

  const _BackdropCard({
    required this.backdrop,
    required this.user,
    required this.isBusy,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final bool enough = user.gold >= backdrop.price;
    return _Showcase(
      image: backdrop.asset ?? '',
      cover: true,
      title: backdrop.name,
      tag: '배경',
      description: '내 캐릭터 화면 뒤에 깔립니다',
      below: const SizedBox.shrink(),
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PriceTag(price: backdrop.price),
          const SizedBox(height: AppSpacing.sm),
          _BuyButton(enabled: enough && !isBusy, onTap: onBuy),
          if (!enough) ...[
            const SizedBox(height: 3),
            Text(
              '골드가 모자라요',
              style: AppTheme.sans.copyWith(
                fontSize: 10,
                color: AppColors.sandOnDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 진열 칸 공통 틀: 벨벳 바탕에 놋쇠 테두리
//   [그림]  이름  꼬리표                    [side]
//           설명
//           [below]
class _Showcase extends StatelessWidget {
  final String image;
  final String title;
  final String tag;
  final String description;
  final Widget below;
  final Widget side;
  final bool cover; // 배경 그림처럼 칸을 꽉 채워 보여줄지

  const _Showcase({
    required this.image,
    this.cover = false,
    required this.title,
    required this.tag,
    required this.description,
    required this.below,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_velvet, Color(0xFF241813)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _brass.withValues(alpha: 0.7), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemIcon(asset: image, cover: cover),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTheme.serifNumber.copyWith(
                          fontSize: 16,
                          color: _parchment,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      tag,
                      style: AppTheme.sans.copyWith(
                        fontSize: 10.5,
                        color: _brass,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTheme.sans.copyWith(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.sandOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                below,
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          side,
        ],
      ),
    );
  }
}

// 가격표: 양피지 꼬리표에 금화
class _PriceTag extends StatelessWidget {
  final int price;

  const _PriceTag({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _parchment,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _brass, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GoldCoin(size: 14),
          const SizedBox(width: 4),
          Text(
            _Gold.format(price),
            style: AppTheme.number.copyWith(fontSize: 14, color: _ink),
          ),
        ],
      ),
    );
  }
}

// 구매 버튼: 놋쇠판
class _BuyButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _BuyButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE2C27E), _brass, Color(0xFF9C7B3E)],
                )
              : null,
          color: enabled ? null : _velvet,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: enabled ? _brass : _brassDim),
        ),
        child: Text(
          '구매',
          style: AppTheme.sans.copyWith(
            fontSize: 13,
            fontWeight: AppTheme.sansMedium,
            color: enabled ? _ink : _brassDim,
          ),
        ),
      ),
    );
  }
}

class _Gold {
  _Gold._();

  // 1,000 단위로 쉼표
  static String format(int value) {
    final String text = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) out.write(',');
      out.write(text[i]);
    }
    return out.toString();
  }
}

// 물건 그림. 옷은 3D 캐릭터가 입은 모습을, 간식은 픽셀 그림을 씁니다. (assets/icons/)
class _ItemIcon extends StatelessWidget {
  final String asset;
  final bool cover;

  const _ItemIcon({required this.asset, this.cover = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      padding: EdgeInsets.all(cover ? 0 : 4),
      clipBehavior: cover ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        // 진열 칸 안의 받침: 은은한 빛
        gradient: RadialGradient(
          colors: [_brass.withValues(alpha: 0.28), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _brassDim),
      ),
      // 픽셀 그림이라 키울 때 번지지 않게 가장 가까운 칸 그대로 씁니다.
      child: Image.asset(
        asset,
        fit: cover ? BoxFit.cover : BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.checkroom, size: 24, color: _brass),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _brassDim),
      ),
      child: Text(
        '$label $value',
        style: AppTheme.sans.copyWith(
          fontSize: 11,
          fontWeight: AppTheme.sansMedium,
          color: _parchment,
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _brass, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GoldCoin(size: 20),
          const SizedBox(width: AppSpacing.sm - 2),
          Text(
            _Gold.format(gold),
            style: AppTheme.number.copyWith(fontSize: 15, color: _parchment),
          ),
        ],
      ),
    );
  }
}
