import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:pdf_render/pdf_render.dart';
import '../services/storage_service.dart';
import 'score_viewer_screen.dart';
import 'add_score_screen.dart'; // 추가 화면 import

class PdfGridScreen extends StatefulWidget {
  @override
  _PdfGridScreenState createState() => _PdfGridScreenState();
}

class _PdfGridScreenState extends State<PdfGridScreen> {
  final StorageService _storageService = StorageService();
  List<String> _pdfPaths = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPdfs();
  }

  Future<void> _loadSavedPdfs() async {
    final savedPdfs = await _storageService.getSavedPdfs();
    setState(() {
      _pdfPaths = savedPdfs;
    });
  }

  Future<Uint8List?> _renderPdfThumbnail(String pdfPath) async {
    try {
      final document = await PdfDocument.openFile(pdfPath);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width.toInt(),
        height: page.height.toInt(),
      );
      ui.Image image = await pageImage.createImageDetached();

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('썸네일 생성 실패: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PDF 목록')),
      body: _pdfPaths.isEmpty
          ? Center(child: Text('저장된 PDF가 없습니다.'))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 0.7,
                ),
                itemCount: _pdfPaths.length,
                itemBuilder: (context, index) {
                  final pdfPath = _pdfPaths[index];
                  return FutureBuilder<Uint8List?>(
                    future: _renderPdfThumbnail(pdfPath),
                    builder: (context, snapshot) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScoreViewerScreen(
                                scoreName: File(pdfPath).uri.pathSegments.last,
                                pdfPath: pdfPath,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 4.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(10.0),
                                  ),
                                  child: snapshot.data != null
                                      ? Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : Center(
                                          child: Text(
                                            '썸네일 실패',
                                            style: TextStyle(fontSize: 12.0),
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        File(pdfPath).uri.pathSegments.last,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20.0,
                                      ),
                                      onPressed: () async {
                                        await _storageService.deletePdf(
                                            pdfPath);
                                        setState(() {
                                          _pdfPaths.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddScoreScreen()),
          ).then((_) {
            _loadSavedPdfs(); // 새로고침
          });
        },
        child: Icon(Icons.add),
        tooltip: '악보 추가',
      ),
    );
  }
}
