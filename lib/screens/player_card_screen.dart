import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../game/character_outfit.dart';
import '../game/player_number.dart';
import '../game/run_rules.dart';
import '../models/ranking_entry.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/friend_repository.dart';
import '../services/ranking_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/look_image.dart';

// ============================================================
// 플레이어 카드 (홈의 레벨 카드를 누르면)
//
// 카드 한 장이 화면을 꽉 채웁니다. 바탕은 검은색입니다.
//
//   COIN RUN · PLAYER CARD                 No. 0482 1937
//
//                      [캐릭터 크게]
//
//   닉네임
//   LV.10 · 다이아 러너
//   거리 랭킹 #3     레벨 랭킹 #5
//   ──────────────────────────────────────
//   누적 km · 러닝 시간 · 걸음 · 경험치
//   [QR]  휴대폰 카메라로 찍으면 친구 요청 · SINCE 2026.10.11
//
//   [공유하기]  [번호 복사]      <- 카드 밖 (그림에는 안 들어감)
//
// 공유하기는 카드를 그림으로 찍어서 보냅니다. 메일 같은 개인 정보는 넣지 않습니다.
// QR에는 친구 링크(coinrun://app/player/<uid>)가 들어 있습니다. 휴대폰 카메라로 찍으면
// 코인런이 열리고 친구 요청을 보낼지 묻습니다. 공유 글에도 같은 링크를 넣습니다.
// ============================================================
class PlayerCardScreen extends StatefulWidget {
  final String userId;

  const PlayerCardScreen({super.key, required this.userId});

  // QR 안에 넣는 주소. 길드의 친구 추가가 이 모양을 읽습니다.
  // 휴대폰 카메라로 찍으면 코인런이 열리고 친구 요청을 보낼지 묻습니다. (services/link_service.dart)
  static String qrData(String userId) => FriendRepository.linkFor(userId);

  @override
  State<PlayerCardScreen> createState() => _PlayerCardScreenState();
}

class _PlayerCardScreenState extends State<PlayerCardScreen> {
  late final Stream<UserModel?> _user = UserRepository.instance.watchUser(
    widget.userId,
  );
  late final String _number = PlayerNumber.of(widget.userId);

  // 카드를 그림으로 찍을 때 씁니다.
  final GlobalKey _cardKey = GlobalKey();

  // 순위는 처음 한 번만 물어봅니다. (다시 그릴 때마다 묻지 않게)
  Future<(int?, int?)>? _ranks;
  bool _sharing = false;

  Future<(int?, int?)> _loadRanks(UserModel user) async {
    try {
      final int? distance = await RankingRepository.instance.myRank(
        RankingKind.distance,
        user,
      );
      final int? level = await RankingRepository.instance.myRank(
        RankingKind.level,
        user,
      );
      return (distance, level);
    } catch (_) {
      return (null, null);
    }
  }

  Future<void> _share(UserModel user) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (png == null) throw StateError('그림을 만들지 못했습니다');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'coinrun_${_number.replaceAll(' ', '')}.png',
            ),
          ],
          text:
              '코인런에서 친구 해요! ${user.nickname} (No. $_number)\n'
              '${PlayerCardScreen.qrData(widget.userId)}',
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('공유하지 못했어요. ($error)')));
    }
    if (mounted) setState(() => _sharing = false);
  }

  void _copyNumber() {
    Clipboard.setData(ClipboardData(text: _number));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No. $_number 복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final User? account = AuthService.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.black,
      body: StreamBuilder<UserModel?>(
        stream: _user,
        builder: (context, snapshot) {
          final UserModel? user = snapshot.data;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.sandOnDark),
            );
          }
          _ranks ??= _loadRanks(user);
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    key: _cardKey,
                    // 바탕을 검게 깔아 둡니다. 없으면 카드 바깥 여백과 둥근 모서리가
                    // 투명하게 찍혀서, 공유한 그림에서 테두리가 하얗게 보입니다.
                    child: ColoredBox(
                      color: AppColors.black,
                      child: FutureBuilder<(int?, int?)>(
                        future: _ranks,
                        builder: (context, ranks) => PlayerCardFace(
                          user: user,
                          userId: widget.userId,
                          number: _number,
                          joined: account?.metadata.creationTime,
                          distanceRank: ranks.data?.$1,
                          levelRank: ranks.data?.$2,
                          onClose: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DarkButton(
                          icon: Icons.ios_share,
                          label: _sharing ? '준비 중…' : '공유하기',
                          filled: true,
                          onTap: _sharing ? null : () => _share(user),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _DarkButton(
                          icon: Icons.copy,
                          label: '번호 복사',
                          onTap: _copyNumber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

String _date(DateTime at) {
  final DateTime d = at.toLocal();
  return '${d.year}.${_two(d.month)}.${_two(d.day)}';
}

// 화면을 꽉 채우는 카드. 이 안에 든 것만 그림으로 나갑니다. (메일은 넣지 않음)
//   위: 캐릭터를 크게 (남은 자리를 다 씀)
//   아래: 이름 · 등급 -> 순위 두 칸 -> 기록 네 칸(2x2) -> QR
class PlayerCardFace extends StatelessWidget {
  final UserModel user;
  final String userId;
  final String number;
  final DateTime? joined;
  final int? distanceRank;
  final int? levelRank;
  final VoidCallback? onClose;

  const PlayerCardFace({
    super.key,
    required this.user,
    required this.userId,
    required this.number,
    required this.joined,
    required this.distanceRank,
    required this.levelRank,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final CharacterLook? look = user.look;
    final DateTime? since = joined;
    final bool dog = look != null && look.isDog;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF332B24), Color(0xFF1A1613), Color(0xFF15120F)],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.accentOnDark.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                Text(
                  'COIN RUN',
                  style: AppTheme.caption.copyWith(
                    fontSize: 10,
                    color: AppColors.accentOnDark,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'PLAYER CARD',
                  style: AppTheme.caption.copyWith(
                    fontSize: 9,
                    color: AppColors.sandOnDark.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.sandOnDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 캐릭터: 남은 자리를 다 씁니다. 발밑에 은은한 빛, 뒤에 큰 번호를 깔아 둡니다.
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.35),
                        radius: 0.75,
                        colors: [
                          AppColors.accentOnDark.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  top: AppSpacing.sm,
                  child: Text(
                    'No.\n${number.replaceAll(' ', '\n')}',
                    style: AppTheme.serifNumber.copyWith(
                      fontSize: 18,
                      height: 1.05,
                      letterSpacing: 2,
                      color: AppColors.accentOnDark.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: look == null
                      ? Text(
                          '?',
                          style: AppTheme.serifNumber.copyWith(
                            fontSize: 120,
                            color: AppColors.trackOnDark,
                          ),
                        )
                      : SizedBox.expand(
                          child: LookImage(
                            asset: CharacterOutfit.cardFor(
                              look,
                              user.visibleSetId,
                            ),
                            dogStage: user.dogStage,
                          ),
                        ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              border: Border(
                top: BorderSide(
                  color: AppColors.accentOnDark.withValues(alpha: 0.35),
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.md),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nickname,
                            style: AppTheme.serifNumber.copyWith(
                              fontSize: 26,
                              color: AppColors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dog
                                ? '${look.label} · '
                                      '${user.dogNameOf(look.id) ?? '이름 없음'} · '
                                      '${user.dogStage ?? 1}단계'
                                : 'LV.${user.level} · '
                                      '${RunRules.tierName(user.level)}',
                            style: AppTheme.sans.copyWith(
                              fontSize: 12,
                              color: AppColors.sandOnDark,
                            ),
                          ),
                          if (dog)
                            Text(
                              'LV.${user.level} · ${RunRules.tierName(user.level)}',
                              style: AppTheme.sans.copyWith(
                                fontSize: 12,
                                color: AppColors.sandOnDark,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: QrImageView(
                        data: PlayerCardScreen.qrData(userId),
                        size: 58,
                        padding: EdgeInsets.zero,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _Tile(
                        label: '거리 랭킹',
                        value: distanceRank == null ? '-' : '#$distanceRank',
                        big: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Tile(
                        label: '레벨 랭킹',
                        value: levelRank == null ? '-' : '#$levelRank',
                        big: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _Tile(
                        label: '누적 km',
                        value: formatKm(user.totalDistance),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Tile(
                        label: '러닝 시간',
                        value: formatHoursMinutes(user.totalRunSeconds),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Tile(label: '걸음', value: '${user.totalSteps}'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // 번호는 위에 크게 있어서 여기엔 가입일과 QR 안내만 둡니다.
                Row(
                  children: [
                    Text(
                      since == null ? '' : 'SINCE ${_date(since)}',
                      style: AppTheme.caption.copyWith(
                        fontSize: 9,
                        color: AppColors.sandOnDark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '휴대폰 카메라로 찍으면 친구 요청',
                      style: AppTheme.sans.copyWith(
                        fontSize: 10,
                        color: AppColors.sandOnDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 순위·기록 한 칸
class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final bool big;

  const _Tile({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.sans.copyWith(
              fontSize: 10,
              color: AppColors.sandOnDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: big
                ? AppTheme.serifNumber.copyWith(
                    fontSize: 22,
                    color: AppColors.accentOnDark,
                  )
                : AppTheme.number.copyWith(
                    fontSize: 15,
                    color: AppColors.white,
                  ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _DarkButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color text = filled ? AppColors.black : AppColors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: filled ? AppColors.paperOnDark : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: filled ? AppColors.paperOnDark : AppColors.trackOnDark,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: text),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              label,
              style: AppTheme.sans.copyWith(
                fontSize: 14,
                fontWeight: AppTheme.sansMedium,
                color: text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
