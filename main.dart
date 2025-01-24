import 'dart:async'; // 비동기 작업 (Future, Stream) 처리
import 'package:flutter/material.dart'; // Flutter UI 구성
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 네이버 지도 SDK 사용
import 'naver.dart'; // naver.dart 파일 임포트

void main() async {
  await _initialize(); // 네이버 지도 SDK 초기화
  runApp(MyApp()); // 앱 실행
}

// 네이버 지도 SDK 초기화 함수
Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 앱 초기화 보장
  await NaverMapSdk.instance.initialize(clientId: 'rz7lsxe3oo'); // 네이버 지도 SDK에 클라이언트 ID 등록
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EEE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('RUNNING MATE'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // "달리기 시작" 버튼을 눌렀을 때 NaverMapApp 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NaverMapApp()), // NaverMapApp으로 전환
            );
          },
          child: Text('달리기 시작'),
        ),
      ),
    );
  }
}