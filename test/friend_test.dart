import 'package:contact/game/player_number.dart';
import 'package:contact/screens/player_card_screen.dart';
import 'package:contact/services/friend_repository.dart';
import 'package:contact/services/ranking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('친구 찾기', () {
    test('플레이어 카드 QR에서 uid를 꺼냅니다', () {
      expect(
        FriendRepository.uidFromLink(PlayerCardScreen.qrData('abc123')),
        'abc123',
      );
      expect(FriendRepository.uidFromLink('https://example.com/abc'), isNull);
      expect(FriendRepository.uidFromLink('coinrun://player/'), isNull);
      expect(FriendRepository.uidFromLink('coinrun://player/a/b'), isNull);
    });

    test('친구 링크는 https 초대 페이지이고, coinrun:// 모양도 읽습니다', () {
      expect(
        PlayerCardScreen.qrData('abc'),
        'https://spot7123-3ad2d.web.app/p/abc',
      );
      expect(FriendRepository.uidFromLink('coinrun://app/player/abc'), 'abc');
      expect(
        FriendRepository.uidFromLink('https://spot7123-3ad2d.web.app/p/abc'),
        'abc',
      );
      expect(FriendRepository.uidFromLink(' coinrun://player/xyz '), 'xyz');
      expect(FriendRepository.uidFromLink('coinrun://app/player/'), isNull);
    });

    test('랭킹에 적는 번호는 플레이어 번호에서 띄어쓰기만 뺀 것입니다', () {
      final String number = RankingRepository.playerNoOf('uid-1');
      expect(number, PlayerNumber.of('uid-1').replaceAll(' ', ''));
      expect(number, matches(RegExp(r'^\d{8}$')));
    });

    test('신청 문서 id는 보낸사람_받는사람입니다', () {
      expect(FriendRepository.docId('a', 'b'), 'a_b');
      const r = FriendRequest(
        id: 'a_b',
        fromId: 'a',
        toId: 'b',
        accepted: true,
      );
      expect(r.otherOf('a'), 'b');
      expect(r.otherOf('b'), 'a');
    });
  });
}
