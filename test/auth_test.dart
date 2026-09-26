import 'package:contact/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('기본 닉네임 짓기', () {
    test('이메일이 있으면 @ 앞부분을 쓴다', () {
      expect(
        AuthService.defaultNickname(uid: 'abcd1234', email: 'runner@test.com'),
        'runner',
      );
    });

    test('게스트(이메일 없음)는 uid 앞 4글자를 붙인다', () {
      expect(AuthService.defaultNickname(uid: '3f9a77bc'), '러너3f9a');
    });

    test('uid가 4글자보다 짧아도 잘리지 않고 그대로 쓴다', () {
      expect(AuthService.defaultNickname(uid: 'ab'), '러너ab');
    });

    test('이메일이 빈 문자열이거나 @로 시작하면 게스트처럼 짓는다', () {
      expect(AuthService.defaultNickname(uid: '3f9a77bc', email: ''), '러너3f9a');
      expect(
        AuthService.defaultNickname(uid: '3f9a77bc', email: '@test.com'),
        '러너3f9a',
      );
    });
  });
}
