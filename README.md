# 코인런

달린 만큼 캐릭터가 강해지는 러닝 앱입니다. GPS로 달린 거리와 걸음 수를 재고,
그만큼 골드와 경험치를 받아서 장비를 갖춥니다. AI 비서가 쌓인 기록을 보고
이번 주의 흐름을 알려줍니다.

## 보상 규칙

| 항목 | 기준 |
|---|---|
| 경험치 | 실제로 움직인 시간 1분당 10 EXP. 빠르게 달릴수록 최대 30% 더 (5분/km 이상) |
| 골드 | 10걸음당 1골드 |
| 코스 러닝 골드 | 걸음 골드 대신 코스 위 코인 30개 x 20골드. 다 먹으면 편도 1.25배, 왕복 1.5배 |

"움직인 시간"은 걷는 속도(1.0m/s) 이상으로 움직인 시간만 셉니다. 시작만 눌러두고
서 있으면 경험치가 쌓이지 않습니다. 걸음 수로 골드를 주는 이유는 차를 타고
벌 수 없게 하기 위해서입니다.

시속 25km(7m/s)보다 빠르게 움직인 구간은 거리·시간·코스 코인에서 모두 뺍니다.
차나 빠른 자전거로 이동하면서 보상을 쌓는 것을 막기 위해서입니다.

장비를 입으면 힘만큼 골드가, 체력만큼 경험치가 더 들어옵니다.

러닝을 마치면 거리와 페이스로 1~5 등급을 매깁니다. (`lib/game/run_grade.dart`)

## 러닝과 코스 러닝

러닝 화면 오른쪽 위 금색 버튼으로 러닝과 코스 러닝을 오갑니다.
코스 러닝은 지금 위치의 구를 찾아(서울 25개 구 경계, `assets/geo/`) 그 구의 코스를
보여줍니다. 클래식 코스는 앱 안에 있고(`lib/game/official_courses.dart`),
사설 코스는 Firestore의 `courses` 컬렉션에서 읽습니다.

지도는 OpenStreetMap 타일을 `flutter_map`으로 띄웁니다. 구글 지도가 아닙니다.
출처는 지도 위가 아니라 설정 > 지도 및 데이터 출처에 모아 두었습니다.

## AI 평가

숫자는 폰에서 계산하고, 문장만 Gemini가 씁니다.

| 맡는 것 | 파일 |
|---|---|
| 점수(꾸준함·운동량·흐름), 기본 분석 문장 | `lib/game/run_insights.dart` |
| 역치 페이스, 러닝 부하, 체력·피로, 급성:만성 부하비 | `lib/game/training_model.dart` |
| 이번 주 목표의 허용 범위 (화면에서는 빼 둠) | `lib/game/goal_policy.dart` |
| 러닝 한 번의 부하도(1~5), 체감 보정 | `lib/game/run_load.dart`, `lib/game/felt_calibration.dart` |
| 이번 주 목표 정하기·저장·달성률 (화면에서는 빼 둠) | `lib/game/week_plan.dart`, `lib/services/week_coach.dart` |
| Gemini 호출, 말투 검사, 저장 | `lib/services/ai_coach.dart` |
| AI 문장 속 숫자가 보낸 사실에서 나왔는지 검사 | `lib/services/ai_guard.dart` |

Gemini는 Firebase AI Logic으로 부릅니다. API 키를 앱에 넣지 않습니다.
보내는 것은 기간별 숫자뿐이고, 경로와 이름은 보내지 않습니다.

## 3D 캐릭터

내 캐릭터 화면 왼쪽 위에서 남자·여자를 고릅니다. 고르기 전에는 물음표가 보입니다.
캐릭터는 내 캐릭터 화면과 게임 플레잉 대결에서 3D로 보입니다. 홈 카드의 얼굴은
같은 3D를 미리 찍어 둔 그림(`assets/icons/face_*.png`)입니다. 파일 하나(`assets/models/character.glb`)에
남녀 머리, 몸, 옷이 같은 자리에 겹쳐 있고, 입은 세트에 맞는 파츠만 켭니다.
(`lib/game/character_outfit.dart`)

| | 장비 없음 | 초급(천옷) | 중급(가죽옷) | 고급(갑옷) |
|---|---|---|---|---|
| 남 | head ArmLeg basic | head ArmLeg fabric | head ArmLeg leather | head armor |
| 여 | womanHEAD woman | womanHEAD ArmLeg fabric | womanHEAD ArmLeg leather | womanHEAD armor |

- 웹뷰 안에서 three.js(r160, `assets/viewer/`)로 그립니다. 인터넷 없이 뜨도록
  앱 안의 작은 서버(`lib/services/asset_server.dart`, 127.0.0.1)가 파일을 내줍니다.
- 숨쉬기, 대결의 때리기·맞기·피하기, 두 번 톡 치면 콩콩 뛰기는 뼈대 없이
  몸 전체를 움직여서 만듭니다.
- 그림체: 작게 그린 뒤 픽셀 그대로 키우고, 캐릭터 위에만 노이즈를 얹습니다.
- 원본 모델(372MB)은 텍스처를 2048px로, 메시를 생김새가 바뀌지 않는 선까지 줄여
  13MB로 넣었습니다. (gltf-transform simplify·quantize)

## 폴더

| 폴더 | 무엇이 들어 있나 |
|---|---|
| `lib/game/` | 게임 규칙과 분석. 보상 계산, 장비 판정, 러닝 기록 모으기, 코스 코인, 훈련 부하 |
| `lib/models/` | 데이터 한 덩어리를 나타내는 클래스 |
| `lib/services/` | 바깥 세상과 이야기하는 곳. Firebase, GPS, 걸음 센서, Gemini |
| `lib/screens/` | 화면 |
| `lib/widgets/` | 화면 여러 곳에서 같이 쓰는 조각 |
| `assets/` | 글꼴(함렛, 자연산스), 캐릭터 그림, 3D 모델과 뷰어, 서울 구 경계 |
| `history/` | 날짜별 작업 이력. 무엇을 왜 그렇게 만들었는지 |

규칙은 화면과 떼어 놓았습니다. 디자인을 새로 만들어도 `lib/game/`은 그대로 씁니다.

### 인벤토리와 상태창

- 내 캐릭터 화면 오른쪽 위 상태창: 힘(골드 +%), 체력(경험치 +%), 속도, 명예, 포만감.
- 인벤토리: 보이는 옷과 능력치 옷을 따로 입습니다. (`UserModel.outfitSetId`, `equippedSetId`)
  기본 옷도 입을 수 있습니다. 잡화점은 사기만 하고, 이미 산 옷은 목록에서 빠집니다.
- 음식(빵)을 사서 먹이면 포만감이 오릅니다. 나중에 쓸 자리입니다. (`lib/game/food_catalog.dart`)
- 장신구: 가입 편지의 선물로 선글라스를 받습니다. 3D에는 뷰어가 직접 만들어 씌웁니다.

### 플레이어 카드와 우편함

- 홈의 레벨 카드를 누르면 플레이어 카드: 고유 번호(`lib/game/player_number.dart`),
  가입일, 계정, 레벨 돌파 기록(`users/{uid}/levels`).
- 안 읽은 편지(`users/{uid}/mail`)가 있으면 레벨 카드 위에 픽셀 부엉이가 앉습니다.

## 시연용

- 홈의 골드를 빠르게 6번 누르면 레벨 10, 골드 30,000이 됩니다.

## 실행

```bash
flutter pub get
flutter run
```

밖에 나가지 않고 시험하려면, 러닝 화면 지도 오른쪽 아래 나침반을 빠르게 6번
누릅니다. 방향 버튼(시뮬레이터)과 GPS 진단 줄이 나옵니다. 다시 6번 누르면 꺼집니다.
시연용이라 출시 빌드에서도 열립니다.

## Firebase 설정

처음 받아서 돌릴 때 콘솔에서 세 가지를 해야 합니다.

1. Authentication > Sign-in method 에서 **익명**과 **이메일/비밀번호** 켜기
2. Firestore 규칙 게시: `firebase deploy --only firestore:rules --project spot7123-3ad2d`
3. AI Logic 에서 **Gemini Developer API** 켜기

## 확인

```bash
flutter analyze lib test
flutter test
```
