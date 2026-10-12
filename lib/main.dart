import 'package:flutter/material.dart'; //플러터의 기본 UI구성 요소
import 'package:firebase_core/firebase_core.dart'; //파이어 베이스의 기본 설정을 위한 핵심 패키지
import 'firebase_options.dart'; //삼성인지 애플인지 판단하고 설정하는 파이어베이스
import 'screens/auth_gate.dart'; //로그인 여부를 보고 화면을 고르는 문지기
import 'theme/app_theme.dart'; //앱 전체 디자인 기준 (색상, 글꼴, 버튼 모양)
import 'widgets/friend_link_handler.dart'; //친구 링크(QR)를 받으면 친구 요청을 보낼지 묻습니다

void main() async {
  //메인 시작
  //여기서   async:비동기 처리가 함수가 무어냐?
  //        파이어베이스 프로그램이 끝날 때까지 기다리지 않고 UI작업을 한다는 겁니다. 없으면 화면 까매짐.
  WidgetsFlutterBinding.ensureInitialized(); //runApp이 인되어 있어서 안된 밀키트 연결 작업 진행.
  await Firebase.initializeApp(
    //파이어베이스 백엔드 연결 작업이 끝날 때까진 UI키고 좀 기다려도.
    options: DefaultFirebaseOptions.currentPlatform,
  ); //비동기로 초기화합니다. 여기서 초기화는 리셋이 아닙니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  //상태 변화가 없는 정적인 위젯을 만들 때 씁니다.
  const MyApp({super.key}); //지금 제 앱을 정의 했습니다.
  //const MyApp ({Key? key}) :super(key: key);의 최신 단축형이라네요. 키 값을 넘겨주는 겁니다.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, //못생긴 디버그 띠 제거해줍니다.
      title: '코인런', //앱의 제목을
      theme: AppTheme.light(), //theme/app_theme.dart에서 정한 디자인을 앱 전체에 적용합니다.
      home: const AuthGate(), //로그인 안 했으면 로그인 화면, 했으면 홈 화면
      // 친구 링크는 어느 화면에서든 받아야 해서 앱 맨 위에 깔아 둡니다.
      navigatorKey: FriendLinkHandler.navigatorKey,
      scaffoldMessengerKey: FriendLinkHandler.messengerKey,
      builder: (context, child) =>
          FriendLinkHandler(child: child ?? const SizedBox.shrink()),
    );
  }
}
