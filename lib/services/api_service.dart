import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';

class ApiService {
  static const String baseUrl = 'http://192.168.55.85:8000';
  static const String uploadEndpoint = '/process-image/';

  // 이미지 업로드 및 분석 요청
  static Future<Map<String, dynamic>?> uploadImage(File imageFile) async {
    final url = Uri.parse('$baseUrl$uploadEndpoint');
    print('API Request: POST $url'); // 디버깅 로그

    final request = http.MultipartRequest('POST', url);
    try {
      // 이미지 파일 추가
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      print('Uploading image: ${imageFile.path}');

      // 서버로 요청 보내기
      final response = await request.send().timeout(Duration(seconds: 10));

      // 응답 확인
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        print('Response: $responseBody');
        return jsonDecode(responseBody);
      } else {
        print('Server Error: HTTP ${response.statusCode}');
        return {
          "status": "error",
          "message": "HTTP ${response.statusCode}: Unable to process the request"
        };
      }
    } on SocketException {
      print('Network Error: Unable to reach the server');
      return {
        "status": "error",
        "message": "Network Error: Unable to reach the server"
      };
    } on HttpException {
      print('HTTP Error: Invalid response received');
      return {
        "status": "error",
        "message": "HTTP Error: Invalid response received"
      };
    } on TimeoutException {
      print('Timeout Error: Request took too long');
      return {
        "status": "error",
        "message": "Timeout Error: Request took too long"
      };
    } catch (e) {
      print('Unknown Exception: $e');
      return {
        "status": "error",
        "message": "Unknown Error: $e"
      };
    }
  }
}
