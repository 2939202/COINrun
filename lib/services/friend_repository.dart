import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ranking_entry.dart';
import 'ranking_repository.dart';

// ============================================================
// 친구 (나의 길드)
//
// Firestore의 friendRequests/{보낸사람}_{받는사람} 문서 하나가 친구 신청 하나입니다.
//   status: 'pending'  -> 받은 사람이 수락하면 'accepted' (= 친구)
//   거절하거나 친구를 끊으면 문서를 지웁니다.
// 친구 목록은 "내가 보냈거나 받은 신청 중 accepted인 것"입니다.
// 남의 users 문서에는 쓸 수 없어서(본인만), 친구 관계를 이 컬렉션 하나에 둡니다.
// 규칙은 firestore.rules의 friendRequests를 보세요.
//
// 친구를 찾는 방법은 두 가지입니다.
//   1) 플레이어 번호 8자리 (leaderboard의 playerNo)
//   2) 플레이어 카드의 QR (coinrun://player/<uid>)
// 게스트는 랭킹(leaderboard)에 없어서 찾을 수도, 길드에 그릴 수도 없습니다.
// ============================================================
class FriendRequest {
  final String id;
  final String fromId;
  final String toId;
  final bool accepted;

  const FriendRequest({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.accepted,
  });

  factory FriendRequest.fromMap(String id, Map<String, dynamic> map) {
    return FriendRequest(
      id: id,
      fromId: map['fromId'] as String? ?? '',
      toId: map['toId'] as String? ?? '',
      accepted: map['status'] == 'accepted',
    );
  }

  // 나와 이어진 사람
  String otherOf(String me) => fromId == me ? toId : fromId;
}

// 친구 추가가 안 되는 이유를 화면에 그대로 보여주기 위한 예외
class FriendException implements Exception {
  final String message;

  const FriendException(this.message);

  @override
  String toString() => message;
}

class FriendRepository {
  FriendRepository._();

  static final FriendRepository instance = FriendRepository._();

  // 친구 링크 모양. 플레이어 카드 QR과 공유 글에 들어갑니다.
  // (AndroidManifest의 intent-filter와 같아야 합니다: scheme coinrun, host app, /player)
  static const String linkPrefix = 'coinrun://app/player/';
  // 예전 QR 모양. 이미 찍어 둔 그림도 읽히게 남겨 둡니다.
  static const String oldLinkPrefix = 'coinrun://player/';
  // 공유·QR에 실제로 넣는 링크. 카톡 등은 coinrun:// 를 눌리는 링크로 안 만들어 주므로
  // https 페이지(hosting/p/index.html)를 거쳐 앱을 엽니다.
  static const String webLinkPrefix = 'https://spot7123-3ad2d.web.app/p/';

  static String linkFor(String uid) => '$webLinkPrefix$uid';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('friendRequests');

  static String docId(String fromId, String toId) => '${fromId}_$toId';

  // 링크 글자 -> uid. 코인런 친구 링크가 아니면 null
  static String? uidFromLink(String raw) {
    final String text = raw.trim();
    final String? prefix = [
      linkPrefix,
      oldLinkPrefix,
      webLinkPrefix,
    ].where(text.startsWith).firstOrNull;
    if (prefix == null) return null;
    final String uid = text.substring(prefix.length);
    return uid.isEmpty || uid.contains('/') ? null : uid;
  }

  // 내가 보냈거나 받은 신청 전부 (두 질의를 합칩니다)
  Stream<List<FriendRequest>> _watch(String field, String me) {
    return _requests
        .where(field, isEqualTo: me)
        .snapshots()
        .map(
          (query) => [
            for (final doc in query.docs)
              FriendRequest.fromMap(doc.id, doc.data()),
          ],
        );
  }

  Stream<List<FriendRequest>> watchSent(String me) => _watch('fromId', me);
  Stream<List<FriendRequest>> watchReceived(String me) => _watch('toId', me);

  // 신청 보내기. 상대가 이미 나에게 보냈다면 바로 수락해서 친구가 됩니다.
  Future<void> request(String me, String other) async {
    if (other == me) throw const FriendException('나 자신은 추가할 수 없어요.');
    final RankingEntry? entry = await RankingRepository.instance.entryOf(other);
    if (entry == null) {
      throw const FriendException('찾을 수 없는 플레이어예요. (게스트는 친구로 추가할 수 없어요)');
    }
    final reverse = await _requests.doc(docId(other, me)).get();
    if (reverse.exists) {
      await accept(FriendRequest.fromMap(reverse.id, reverse.data()!));
      return;
    }
    final mine = _requests.doc(docId(me, other));
    if ((await mine.get()).exists) {
      throw const FriendException('이미 신청했거나 친구예요.');
    }
    await mine.set({
      'fromId': me,
      'toId': other,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> accept(FriendRequest request) {
    return _requests.doc(request.id).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  // 거절, 신청 취소, 친구 끊기 모두 문서를 지웁니다.
  Future<void> remove(FriendRequest request) =>
      _requests.doc(request.id).delete();
}
