import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ranking_entry.dart';
import '../services/auth_service.dart';
import '../services/friend_repository.dart';
import '../services/link_service.dart';
import '../services/ranking_repository.dart';

// ============================================================
// 친구 링크가 들어오면 친구 요청을 보낼지 묻습니다.
//
// 앱 맨 위(MaterialApp.builder)에 한 번 깔아 둡니다. 어느 화면에 있든
//   링크 -> 로그인 확인 -> 상대 닉네임 찾기 -> "○○님에게 친구 요청을 보낼까요?" -> 보내기
// 상대가 이미 나에게 신청해 두었다면 보내는 순간 바로 친구가 됩니다. (FriendRepository.request)
// 내 링크면 아무것도 하지 않습니다.
// ============================================================
class FriendLinkHandler extends StatefulWidget {
  final Widget child;

  const FriendLinkHandler({super.key, required this.child});

  // 창과 알림을 띄울 곳. MaterialApp에 같이 넘깁니다.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey();

  @override
  State<FriendLinkHandler> createState() => _FriendLinkHandlerState();
}

class _FriendLinkHandlerState extends State<FriendLinkHandler> {
  StreamSubscription<String>? _subscription;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subscription = LinkService.instance.links.listen(_handle);
    // 링크로 앱이 켜졌으면 그 링크도 처리합니다.
    LinkService.instance.initialLink().then((link) {
      if (link != null) _handle(link);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    FriendLinkHandler.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // 앱이 막 켜졌으면 첫 화면이 뜰 때까지 잠깐 기다립니다.
  Future<BuildContext?> _dialogContext() async {
    for (int i = 0; i < 20; i++) {
      final BuildContext? context =
          FriendLinkHandler.navigatorKey.currentContext;
      if (context != null) return context;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  Future<void> _handle(String link) async {
    final String? uid = FriendRepository.uidFromLink(link);
    if (uid == null || _busy) return;
    _busy = true;
    try {
      // 앱이 막 켜졌으면 로그인 상태를 불러올 때까지 기다립니다.
      final User? account = await AuthService.instance.authStateChanges.first;
      if (account == null) {
        _toast('로그인한 뒤 친구 링크를 다시 열어 주세요.');
        return;
      }
      if (account.isAnonymous) {
        _toast('게스트는 친구를 추가할 수 없어요. 설정에서 이메일을 연결해 주세요.');
        return;
      }
      if (account.uid == uid) return;

      final RankingEntry? entry = await RankingRepository.instance.entryOf(uid);
      if (entry == null) {
        _toast('찾을 수 없는 플레이어예요.');
        return;
      }
      final BuildContext? context = await _dialogContext();
      if (context == null || !context.mounted) return;
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('친구 요청'),
          content: Text('${entry.nickname}님에게 친구 요청을 보낼까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('보내기'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await FriendRepository.instance.request(account.uid, uid);
      _toast('${entry.nickname}님에게 친구 요청을 보냈어요.');
    } on FriendException catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast('친구 요청을 보내지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
