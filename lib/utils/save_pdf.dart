import 'dart:io';
import 'package:path_provider/path_provider.dart';

// PDF 파일을 앱의 문서 디렉토리에 저장하는 함수
Future<String?> savePdfToAppDirectory(String pdfPath) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = pdfPath.split('/').last; // 파일 이름 추출
    final newPath = '${directory.path}/$fileName';
    final newFile = await File(pdfPath).copy(newPath); // 파일 복사
    print('PDF 저장 경로: $newPath');
    return newFile.path; // 복사된 파일 경로 반환
  } catch (e) {
    print('PDF 저장 실패: $e');
    return null;
  }
}
