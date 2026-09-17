import 'package:flutter/material.dart'; //플러터의 기본 UI구성 요소
import 'package:firebase_core/firebase_core.dart'; //파이어 베이스의 기본 설정을 위한 핵심 패키지
import 'package:cloud_firestore/cloud_firestore.dart'; // 파이어 베이스의 nosqld 데이터 베이스 패키지
import 'firebase_options.dart'; //삼성인지 애플인지 판단하고 설정하는 파이어베이스
import 'models/user_model.dart';//유저 정보
import 'screens/profile_screen.dart'; //프로필
import 'screens/run_screen.dart'; //달리기 시작
import 'screens/settings_screen.dart'; //설정



void main() async { //메인 시작
  //여기서   async:비동기 처리가 함수가 무어냐?
  //        파이어베이스 프로그램이 끝날 때까지 기다리지 않고 UI작업을 한다는 겁니다. 없으면 화면 까매짐.
  WidgetsFlutterBinding.ensureInitialized(); //runApp이 인되어 있어서 안된 밀키트 연결 작업 진행.
  await Firebase.initializeApp( //파이어베이스 백엔드 연결 작업이 끝날 때까진 UI키고 좀 기다려도.
    options: DefaultFirebaseOptions.currentPlatform,
  );//비동기로 초기화합니다. 여기서 초기화는 리셋이 아닙니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget { //상태 변화가 없는 정적인 위젯을 만들 때 씁니다.
  const MyApp({super.key}); //지금 제 앱을 정의 했습니다.
  //const MyApp ({Key? key}) :super(key: key);의 최신 단축형이라네요. 키 값을 넘겨주는 겁니다.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, //못생긴 디버그 띠 제거해줍니다.
      title: '달리랑 RPG', //앱의 제목을 설정합니다.
      theme: ThemeData.light(),//라이트 모드 테마입니다.
      home: const MainScreen(), //메인 화면
    );
  }
}
//아래는 메인화면을 담당하는 위젯입니다. : MainScreen
class MainScreen extends StatelessWidget {
  //"MainScreen"이라는 제 변수명에 StatelessWidget이라는 설계 밀키트를 상속받아 확장합니다.
  const MainScreen({super.key}); //18번 줄 참고

  @override//나 상속받았다 친절하게 부연설명하는 겁니다 : 애노테이션 : @
  Widget build(BuildContext context) { //위젯을 그리는 함수래요.
    const String userId = "user_test_01"; //테스트 유저 아이디

    return Scaffold(
      appBar: AppBar(//앱의 상단 "바"이고요.
        title: const Text('달리랑 RPG'),//타이틀
      ),
      body: StreamBuilder<DocumentSnapshot>(//문서데이터를 실시간으로 반영하는 자동 새로고침
        stream: FirebaseFirestore.instance//파이어 스토어 데이터 베이스 접근
            .collection('users')//유저들이라는 폴더에 들어가서
            .doc(userId)//유저아이디 문서를 지정하고
            .snapshots(),//변화 때 마다 열어
        builder: (context, snapshot) {//위치정보를 기반으로 현재 상태를 받은 데이터로 새로 빌더해 (그려)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }//이거 뭐 현재 상태(파이어 베이스)를 로딩 중이면 삥글 삥글 도는 거 띄우라는 거에요

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(//현재 상태 문서가 없거나 아예 존재하지를 않아버린다면,
              child: ElevatedButton( //클릭 가능한 버튼을 출력하라는 겁니다. : ElevatedButton
                onPressed: () async { //버튼을 터치할 때 비동기로 작동하시고요
                  await FirebaseFirestore.instance //근데 밑엔 코드 실행 말고 저장 끝날때 까지 wait하세요
                      .collection('users') //유저들 폴더에서
                      .doc(userId) //user_test_01이거 찾기
                      .set({ //데이터 생성 및 덮어쓰기
                    'nickname': '러너1호',
                    'level': 1,
                    'gold': 0,
                    'equipment': '기본 장비',
                    'myRank': 0,
                  });
                },
                child: const Text('테스트 유저 데이터 생성하기'),
              ),
            );
          }
          UserModel userData = UserModel.fromMap(
              snapshot.data!.data() as Map<String, dynamic>
          );
          //Map<String, dynamic> userData =
          // 문서가 존재할 경우, 수신된 데이터를 Map 형태로 변환
          //snapshot.data!.data() as Map<String, dynamic>;
          //맵으로 쓴다는건데요 키, 값을 같이 쓴다는 거고요

          return Padding(//경계선 안쪽으로 여백을 만들어주는 패딩이고요
            padding: const EdgeInsets.all(16.0),
            child: Column(//컬럼: 수직 세로라는 뜻이고요
              children: [
                // 상단 랭킹 표시 (MVP용 1~10등 요약)
                Card(
                  color: const Color(0xFFFF8787),
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events, color: Color(
                        0xFFFFFFFF)),
                    title: const Text(
                      '실시간 랭킹 (TOP 10)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('내 현재 순위: ${userData.myRank}위'),
                    trailing: TextButton(
                      onPressed: () {
                        // 랭킹 상세 페이지 이동 로직 위치(비워둠)
                      },
                      child: const Text('전체보기', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                //내 캐릭터 이동 버튼 -> 프로필 스크린 이동
                _buildMainCategoryButton(
                  context: context,
                  icon: Icons.person,
                  title: '내 캐릭터',
                  subtitle: 'Lv.${userData.level} | ${userData.gold} G | 상점 및 장비',
                  color: const Color(0xFFE3344C),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userData: userData),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 대분류 버튼 2: 시작 (상점 연결)
                _buildMainCategoryButton(
                  context: context,
                  icon: Icons.play_arrow,
                  title: '시작',
                  subtitle: '러닝 플레이 및 지도 확인',
                  color: const Color(0xFFBA163C),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RunScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 대분류 버튼 설정 (로그인, 사운드)
                _buildMainCategoryButton(
                  context: context,
                  icon: Icons.settings,
                  title: '설정',
                  subtitle: '계정 로그인 및 사운드 설정',
                  color: Colors.grey.shade700,
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                        ),
                    );
                    // 설정 페이지 이동
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 대분류 버튼 생성 공통 위젯
  Widget _buildMainCategoryButton({
    required BuildContext context,
    required IconData icon, // 버튼 아이콘
    required String title,// 메인 타이틀 텍스트
    required String subtitle, // 서브 타이틀 텍스트
    required Color color, // 버튼 배경색
    required VoidCallback onTap, // 클릭 이벤트 콜백 함수
  }) {
    return SizedBox(
      width: double.infinity, // 가로 너비를 화면 전체로 설정 : 무한대
      height: 90, // 고정 높이 90 설정
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, // 파라미터로 받은 색상 적용
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), //모서리 둥글기
          ),
        ),
        onPressed: onTap, // 전달받은 함수 실행
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.white), // 아이콘 생성
            const SizedBox(width: 16), // 아이콘과 텍스트 사이 간격
            Column(
              mainAxisAlignment: MainAxisAlignment.center,// 정중앙 세로 정렬
              crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 가로 정렬
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}