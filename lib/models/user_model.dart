import '../game/backdrop_catalog.dart';
import '../game/character_outfit.dart';
import '../game/pet_catalog.dart';
import '../game/run_rules.dart';

// Firestore의 users/{userId} 문서 한 개를 나타내는 유저 데이터
class UserModel {
  final String nickname;

  // 이메일 없이 게스트로 쓰는 중인지.
  //
  // 게스트는 랭킹에 올리지 않습니다. 앱을 지우면 돌아올 수 없는 계정이라,
  // 랭킹에 남겨두면 주인 없는 줄이 계속 쌓입니다.
  // 나중에 이메일을 붙이면 false가 되고 그때부터 랭킹에 들어갑니다.
  final bool isGuest;

  // 휴지통을 쓰는지. 기본은 꺼짐입니다.
  //   꺼짐 - 삭제하면 바로 사라집니다.
  //   켜짐 - 삭제하면 휴지통으로 가고, 거기서 되살리거나 완전히 지울 수 있습니다.
  final bool trashEnabled;

  // 홈의 "시작"을 누르면 코스 러닝(코스 고르기)으로 갈지.
  // 러닝 화면에서 ⇄로 코스 러닝으로 바꾸면 켜지고, 다시 러닝으로 바꾸면 꺼집니다.
  // 한 번 바꾸면 그 쪽으로 고정되어서, 매번 ⇄를 누르지 않아도 됩니다.
  final bool prefersCourseRun;

  // 캐릭터 모습(남/여). 처음 들어올 때 한 번 고르고, 그 뒤로는 바꿀 수 없습니다.
  // null이면 아직 고르지 않은 것입니다. (홈 대신 고르는 화면을 띄웁니다)
  final CharacterLook? look;
  final int level;
  final int exp; // 현재 레벨에서 쌓인 경험치 (레벨업하면 초과분만 남음)
  final int gold;

  // 장비는 세트 단위입니다. (game/equipment_catalog.dart의 id를 저장합니다)
  final List<String> ownedSetIds; // 사 둔 세트들
  final String? equippedSetId; // 능력치를 받는 세트. null이면 기본 옷(능력치 없음)입니다.

  // 겉으로 보이는 옷. 능력치 옷과 다르게 입을 수 있습니다. (내 캐릭터 > 인벤토리)
  //   null    - 능력치 옷과 같은 옷을 보여줍니다. (예전 문서도 이렇게 읽힙니다)
  //   'basic' - 기본 옷을 보여줍니다.
  //   세트 id  - 그 옷을 보여줍니다.
  final String? outfitSetId;

  // 간식과 강아지 (game/pet_catalog.dart)
  final int snacks; // 가진 간식 개수
  final Map<String, int> petFed; // 강아지 id -> 지금까지 먹은 간식 개수
  final Map<String, String> dogNames; // 강아지 id -> 지어 준 이름

  // 내 캐릭터 화면 배경 (game/backdrop_catalog.dart)
  // 흰색·검은색은 기본이라 여기 적지 않아도 가진 것으로 봅니다.
  final List<String> ownedBackdrops; // 산 배경
  final String backdropId; // 고른 배경. 예전 문서는 흰색

  final double totalDistance; // 누적 러닝 거리 (m)
  final int totalRunSeconds; // 누적 러닝 시간 (초)
  final int totalMovingSeconds; // 누적 "움직인" 시간 (초) - 경험치 기준
  final int totalSteps; // 누적 걸음 수 - 골드 기준
  final int totalExp; // 지금까지 받은 경험치를 전부 합한 값 - 레벨 랭킹 기준

  const UserModel({
    required this.nickname,
    required this.isGuest,
    required this.trashEnabled,
    this.prefersCourseRun = false,
    this.look,
    required this.level,
    required this.exp,
    required this.gold,
    required this.ownedSetIds,
    required this.equippedSetId,
    this.outfitSetId,
    this.snacks = 0,
    this.petFed = const {},
    this.dogNames = const {},
    this.ownedBackdrops = const [],
    this.backdropId = 'white',
    required this.totalDistance,
    required this.totalRunSeconds,
    required this.totalMovingSeconds,
    required this.totalSteps,
    required this.totalExp,
  });

  // 새로 가입한 유저의 기본값 - 장비 없이 맨몸으로 시작합니다.
  factory UserModel.initial(String nickname, {required bool isGuest}) {
    return UserModel(
      nickname: nickname,
      isGuest: isGuest,
      trashEnabled: false,
      level: 1,
      exp: 0,
      gold: 0,
      ownedSetIds: const [],
      equippedSetId: null,
      totalDistance: 0,
      totalRunSeconds: 0,
      totalMovingSeconds: 0,
      totalSteps: 0,
      totalExp: 0,
    );
  }

  bool owns(String setId) => ownedSetIds.contains(setId);

  bool ownsBackdrop(Backdrop backdrop) =>
      backdrop.isFree || ownedBackdrops.contains(backdrop.id);

  // 고른 배경. 산 적 없는 배경이 적혀 있으면 흰색입니다.
  Backdrop get backdrop {
    final Backdrop picked = BackdropCatalog.byId(backdropId);
    return ownsBackdrop(picked) ? picked : BackdropCatalog.white;
  }

  // 화면에 그릴 옷의 세트 id. null이면 기본 옷입니다.
  // 보이는 옷으로 고른 세트를 더는 갖고 있지 않으면 능력치 옷을 따릅니다.
  String? get visibleSetId {
    final String? outfit = outfitSetId;
    if (outfit == null) return equippedSetId;
    if (outfit == basicOutfit) return null;
    return owns(outfit) ? outfit : equippedSetId;
  }

  static const String basicOutfit = 'basic';

  int fedOf(String petId) => petFed[petId] ?? 0;

  // 지어 준 이름. 아직 없으면 null
  String? dogNameOf(String petId) {
    final String? name = dogNames[petId]?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  // 강아지 캐릭터면 지금 단계, 사람이면 null
  int? get dogStage {
    final CharacterLook? current = look;
    if (current == null || !current.isDog) return null;
    return PetCatalog.stageFor(fedOf(current.id));
  }

  // 뷰어에 넘길 파츠 (사람은 보이는 옷, 강아지는 단계)
  List<String> parts() => CharacterOutfit.partsFor(
    look ?? CharacterLook.female,
    visibleSetId,
    dogStage: dogStage ?? 1,
  );

  // Firestore는 숫자를 int/double 구분 없이 줄 수 있어서 num으로 받은 뒤 변환합니다.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      nickname: map['nickname'] ?? '이름없음',
      // 이 값이 없던 시절 문서는 이메일 계정으로 봅니다. 그때는 게스트도 랭킹에 있었고,
      // 지우면 기존 사용자가 랭킹에서 사라져 버리기 때문입니다.
      isGuest: map['isGuest'] as bool? ?? false,
      trashEnabled: map['trashEnabled'] as bool? ?? false,
      prefersCourseRun: map['prefersCourseRun'] as bool? ?? false,
      look: CharacterLook.tryParse(map['look']),
      level: (map['level'] as num?)?.toInt() ?? 1,
      exp: (map['exp'] as num?)?.toInt() ?? 0,
      gold: (map['gold'] as num?)?.toInt() ?? 0,
      // 장비를 붙이기 전에 만든 문서에는 이 필드가 없어서 빈 목록으로 읽힙니다.
      ownedSetIds:
          (map['ownedSetIds'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      equippedSetId: map['equippedSetId'] as String?,
      outfitSetId: map['outfitSetId'] as String?,
      snacks: (map['snacks'] as num?)?.toInt() ?? 0,
      petFed: {
        for (final entry in ((map['petFed'] as Map?) ?? const {}).entries)
          entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
      },
      dogNames: {
        for (final entry in ((map['dogNames'] as Map?) ?? const {}).entries)
          entry.key.toString(): entry.value.toString(),
      },
      ownedBackdrops:
          (map['ownedBackdrops'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      backdropId: map['backdrop'] as String? ?? BackdropCatalog.white.id,
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0,
      totalRunSeconds: (map['totalRunSeconds'] as num?)?.toInt() ?? 0,
      totalMovingSeconds: (map['totalMovingSeconds'] as num?)?.toInt() ?? 0,
      totalSteps: (map['totalSteps'] as num?)?.toInt() ?? 0,
      // 랭킹을 붙이기 전에 만든 문서에는 없습니다. 그럴 땐 레벨과 경험치로 되짚어 구합니다.
      totalExp:
          (map['totalExp'] as num?)?.toInt() ??
          RunRules.totalExpFor(
            (map['level'] as num?)?.toInt() ?? 1,
            (map['exp'] as num?)?.toInt() ?? 0,
          ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'isGuest': isGuest,
      'trashEnabled': trashEnabled,
      'prefersCourseRun': prefersCourseRun,
      if (look != null) 'look': look!.id,
      'level': level,
      'exp': exp,
      'gold': gold,
      'ownedSetIds': ownedSetIds,
      'equippedSetId': equippedSetId,
      if (outfitSetId != null) 'outfitSetId': outfitSetId,
      'totalDistance': totalDistance,
      'totalRunSeconds': totalRunSeconds,
      'totalMovingSeconds': totalMovingSeconds,
      'totalSteps': totalSteps,
      'totalExp': totalExp,
    };
  }
}
