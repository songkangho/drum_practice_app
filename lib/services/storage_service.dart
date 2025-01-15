import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _pdfKey = 'saved_pdfs';
  static const _scoreDataKey = 'score_data';

  // PDF 파일 경로 저장
  Future<void> savePdf(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPdfs = prefs.getStringList(_pdfKey) ?? [];
    if (!savedPdfs.contains(path)) {
      savedPdfs.add(path);
      await prefs.setStringList(_pdfKey, savedPdfs);
    }
  }

  // 저장된 PDF 경로 가져오기
  Future<List<String>> getSavedPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_pdfKey) ?? [];
  }

  // PDF 파일 삭제
  Future<void> deletePdf(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPdfs = prefs.getStringList(_pdfKey) ?? [];
    savedPdfs.remove(path);
    await prefs.setStringList(_pdfKey, savedPdfs);

    // 관련 악보 데이터도 삭제
    final existingData = prefs.getString(_scoreDataKey) ?? '{}';
    final decodedData = jsonDecode(existingData) as Map<String, dynamic>;
    decodedData.remove(path);
    await prefs.setString(_scoreDataKey, jsonEncode(decodedData));
  }

  // 악보 데이터 저장
  Future<void> saveScoreData(String scoreName, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getString(_scoreDataKey) ?? '{}';
    final decodedData = jsonDecode(existingData) as Map<String, dynamic>;

    decodedData[scoreName] = data;
    await prefs.setString(_scoreDataKey, jsonEncode(decodedData));
  }

  // 악보 데이터 불러오기
  Future<Map<String, dynamic>?> getScoreData(String scoreName) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getString(_scoreDataKey) ?? '{}';
    final decodedData = jsonDecode(existingData) as Map<String, dynamic>;
    return decodedData[scoreName] as Map<String, dynamic>?;
  }
}
