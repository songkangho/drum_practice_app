import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart';
import 'dart:ui' as ui;

class PdfImageService 
{
  /// PDF 페이지를 이미지로 렌더링
  Future<Uint8List?> renderPdfPageAsImage(String pdfPath, int pageNumber) async 
  {
    try 
    {
      // PDF 문서를 열기
      final document = await PdfDocument.openFile(pdfPath);
      // 특정 페이지 가져오기
      final page = await document.getPage(pageNumber);
      // 페이지 이미지를 렌더링
      final pageImage = await page.render
      (
        width: (page.width * 2).toInt(), // 고해상도 설정
        height: (page.height * 2).toInt(),
      );
      debugPrint('[App] 렌더링된 PDF 이미지 크기: ${pageImage.width}x${pageImage.height}');

      final image = await pageImage.createImageDetached();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } 
    catch (e) 
    {
      debugPrint('[App] PDF 렌더링 중 오류 발생: $e');
      return null;
    }
  }
}
