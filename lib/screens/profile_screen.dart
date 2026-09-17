import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 캐릭터 & 상점'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 유저 정보 카드
            Card(
              color: Colors.indigo.shade50,
              child: ListTile(
                leading: const Icon(Icons.person, size: 40, color: Colors.indigo),
                title: Text(
                  userData.nickname,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('레벨: Lv.${userData.level} | 보유 골드: ${userData.gold} G'),
              ),
            ),
            const SizedBox(height: 20),

            // 현재 장착 장비
            const Text(
              '현재 장착 장비',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield, color: Colors.amber),
                title: Text(userData.equipment),
                subtitle: const Text('현재 적용 중인 무기입니다.'),
              ),
            ),
            const SizedBox(height: 24),

            // 상점 영역
            const Text(
              '장비 상점',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shopping_bag, color: Colors.redAccent),
                title: const Text('강철 검'),
                subtitle: const Text('공격력 +10 | 가격: 100 G'),
                trailing: ElevatedButton(
                  onPressed: () {
                    // 추후 장비 구매 기능 연결 위치
                  },
                  child: const Text('구매'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}