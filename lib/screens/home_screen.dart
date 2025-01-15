import 'package:flutter/material.dart';
import 'pdf_grid_screen.dart';
import 'add_score_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('악보 관리')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // PdfGridScreen으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PdfGridScreen()),
                );
              },
              child: Text('PDF 목록 보기'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // AddScoreScreen으로 이동
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddScoreScreen()),
                );

                // PDF 추가 완료 후 자동으로 PdfGridScreen으로 이동
                if (result != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => PdfGridScreen()),
                  );
                }
              },
              child: Text('PDF 추가하기'),
            ),
          ],
        ),
      ),
    );
  }
}
