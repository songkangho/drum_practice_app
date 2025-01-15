import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:score_app/utils/save_pdf.dart';
import 'package:score_app/services/storage_service.dart';

class AddScoreScreen extends StatefulWidget {
  @override
  _AddScoreScreenState createState() => _AddScoreScreenState();
}

class _AddScoreScreenState extends State<AddScoreScreen> {
  String? pdfPath;
  bool isLoading = false;
  final StorageService _storageService = StorageService();

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        pdfPath = result.files.single.path;
      });
    }
  }

  Future<void> saveData() async {
    if (pdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF를 선택하세요')),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    final savedPath = await savePdfToAppDirectory(pdfPath!);
    if (savedPath != null) {
      await _storageService.savePdf(savedPath);

      final initialScoreData = {
        'rectangles': [],
        'cycles': {}
      };
      await _storageService.saveScoreData(savedPath, initialScoreData);

      setState(() {
        isLoading = false;
      });
      Navigator.pop(context);
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 저장 실패!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('악보 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: pickPdf,
              icon: Icon(Icons.upload_file),
              label: Text(pdfPath == null ? 'PDF 선택하기' : 'PDF 다시 선택'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.0),
              ),
            ),
            if (pdfPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  '선택된 파일: ${pdfPath!.split('/').last}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveData,
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('저장'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
