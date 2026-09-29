import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../game/equipment_catalog.dart';
import '../game/equipment_rules.dart';
import '../game/run_rules.dart';
import '../models/equipment_set.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'shop_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  final UserModel userData;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  // 아직 사지 않은 세트 중 가장 싼 것 = 다음에 노릴 장비. 다 샀으면 null입니다.
  EquipmentSet? get _nextSet {
    for (final set in EquipmentCatalog.all) {
      if (!userData.owns(set.id)) return set;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 캐릭터'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              // 1. 중앙 3D 캐릭터 모델 배치 영역 (웹/모바일 경로 분기 적용)
              Center(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: ModelViewer(
                    src: kIsWeb
                        ? 'assets/assets/models/Untitled.glb'
                        : 'assets/models/Untitled.glb',
                    alt: '3D 캐릭터 모델',
                    autoRotate: true,
                    cameraControls: true,
                  ),
                ),
              ),

              // 2. 우측 상단 유저 정보 표시 영역
              Positioned(
                top: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '골드 : ${userData.gold}G',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '경험치 : ${userData.exp} / ${RunRules.expToNextLevel(userData.level)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '장착중인 장비',
                      style: TextStyle(fontSize: 12, color: AppColors.mute),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      EquipmentRules.equippedSetName(userData),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.shield_outlined, size: 30),
                        SizedBox(width: 8),
                        Icon(Icons.colorize, size: 30),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. 좌측 하단 잡화점 버튼
              Positioned(
                bottom: 10,
                left: 0,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShopScreen(userId: userId),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.black, width: 2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cream,
                          ),
                          child: const Text(
                            '잡화점',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '다음 단계의',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mute,
                              ),
                            ),
                            Text(
                              _nextSet?.name ?? '전부 갖췄습니다',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. 우측 하단 집 영역
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 130,
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.black, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        '나중에\n만들\n길드 및\n인테리어가\n가능한 집',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, height: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
