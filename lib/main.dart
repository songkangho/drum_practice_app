import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/pdf_grid_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Score App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: PdfGridScreen(), // 앱의 첫 화면으로 HomeScreen 설정
    );
  }
}
