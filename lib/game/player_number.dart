// ============================================================
// 플레이어 번호
//
// 계정 uid(긴 영문·숫자)를 사람이 읽기 쉬운 8자리 숫자로 바꿉니다. 예: 0482 1937
// 같은 계정이면 늘 같은 번호입니다. 앱을 다시 켜도 같도록 직접 계산합니다. (FNV-1a)
// 화면에 보여주기 위한 번호라, 다른 사람과 겹칠 확률이 아주 작게나마 있습니다.
// ============================================================
class PlayerNumber {
  PlayerNumber._();

  static String of(String uid) {
    int hash = 0x811c9dc5;
    for (final int unit in uid.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    final String digits = (hash % 100000000).toString().padLeft(8, '0');
    return '${digits.substring(0, 4)} ${digits.substring(4)}';
  }
}
