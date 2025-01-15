import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io';
import '../services/pdf_image_service.dart';
import '../services/api_service.dart';
import '../services/metronome_service.dart';
import '../services/storage_service.dart';


class ScoreViewerScreen extends StatefulWidget {
  final String scoreName;
  final String pdfPath;

  ScoreViewerScreen({required this.scoreName, required this.pdfPath});

  @override
  _ScoreViewerScreenState createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends State<ScoreViewerScreen> with SingleTickerProviderStateMixin{

  final StorageService _storageService = StorageService(); // 스토리지 서비스 객체

  //오선보 관련 변수
  final Map<String, List<List<Map<String, dynamic>>>> _rectanglesByScore = {}; // 악보별 검출된 사각형 데이터 저장
  final Map<String, List<Map<String, dynamic>>> _imageSizesByScore = {}; // 악보별 이미지 크기 데이터 저장
  final Map<String, bool> _showRectanglesByScore = {}; // 악보별 사각형 표시 여부 저장
  String get _currentScoreName => widget.scoreName;

  // PDF Viewer 변수
  final PdfImageService _pdfImageService = PdfImageService();
  Uint8List? _currentPageImage; // 현재 페이지 이미지 저장
  double? _renderedImageWidth;
  double? _renderedImageHeight;
  PageController _pageController = PageController();

  PdfDocument? _document;
  int _currentPage = 1;
  int _totalPages = 0;
  Map<int, Uint8List?> _pageCache = {};
  bool _isLoading = true;
  // Metronome 변수
  Map<int, Map<int, int>> rectangleCycleOverrides = {}; 
  late MetronomeService _metronomeService;
  int _currentRectangleIndex = 0;
  bool _isCountingDown = false; // 카운트다운 상태
  int _countdownValue = 4; // 카운트다운 시작 값



  @override
  void initState() {
    super.initState();
    _metronomeService = MetronomeService(this);
    _showRectanglesByScore[_currentScoreName] = false; // 초기 값 설정

    _initializeViewer();
    _metronomeService.initialize();
    _metronomeService.loadBPM(widget.scoreName);
    _metronomeService.onCycleComplete = _handleCycleComplete;
    
  }

  Future<void> _initializeViewer() async {

    await _loadPdf(); // PDF 로드 먼저
    if (_document != null) {
      _loadSavedData();
    } else {
      _showErrorSnackBar('PDF 로드 실패로 검출을 진행할 수 없습니다.');
    }
  }

  Future<void> _detectStaffLinesForAllPages() async {
    // 데이터가 이미 존재하면 상태만 토글
    if (_rectanglesByScore.containsKey(_currentScoreName)&&
        (_rectanglesByScore[_currentScoreName]?.isNotEmpty ?? false)) {
      setState(() {
        _showRectanglesByScore[_currentScoreName] =
            !(_showRectanglesByScore[_currentScoreName] ?? false);
      });
      return;
    }

    final List<List<Map<String, dynamic>>> allPageRectangles = [];
    final List<Map<String, dynamic>> allImageSizes = [];

    try {
      for (int pageNumber = 1; pageNumber <= _totalPages; pageNumber++) {
        final pageImage = await _renderPage(pageNumber);
        if (pageImage == null) continue;

        final tempDir = await getTemporaryDirectory();
        final imagePath = '${tempDir.path}/page_$pageNumber.png';
        final imageFile = File(imagePath)..writeAsBytesSync(pageImage);

        final result = await ApiService.uploadImage(imageFile);
        if (result == null || result['status'] != 'success') {
          continue;
        }


        allPageRectangles.add(List<Map<String, dynamic>>.from(result['rectangles']));
        allImageSizes.add(result['image_size']);
        imageFile.deleteSync();
      }

      if (allPageRectangles.isNotEmpty) {
        setState(() {
          _rectanglesByScore[_currentScoreName] = allPageRectangles;
          _imageSizesByScore[_currentScoreName] = allImageSizes;
          _showRectanglesByScore[_currentScoreName] = true;
        });

        // 데이터 저장
        await _saveCurrentScoreData();
      } 
    } catch (e) {
      _showErrorSnackBar('오선보 검출 중 오류 발생: $e');
    }
  }

  void _handleCycleComplete() {
    setState(() {
      if (_rectanglesByScore.containsKey(_currentScoreName)) {
        final rectangles = _rectanglesByScore[_currentScoreName]![_currentPage - 1];

        // Get the current cycle for the active rectangle (default is 4)
        final currentCycle = rectangleCycleOverrides[_currentPage - 1]?[_currentRectangleIndex+1] ?? 4;
        int currentBpm = rectangleCycleOverrides[_currentPage - 1]?[_currentRectangleIndex+501] ?? 0;
        
        if(currentBpm == 0)
        {
          currentBpm = _metronomeService.metronumBpm;
        }
        // Update and restart the metronome for the new rectangle
        _metronomeService.updateCycleAndBpm(currentCycle,currentBpm);
        _metronomeService.start();
        if (_currentRectangleIndex < rectangles.length - 1) 
        {
          // Move to the next rectangle
          _currentRectangleIndex++;
        } 
        else 
        {
          // Move to the next page
          if (_currentPage < _totalPages) 
          {
            _currentRectangleIndex = 0;
            _currentPage++;
            _pageController.animateToPage(
              _currentPage - 1,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } 
        }
      }
    });
  }

  Future<void> _loadPdf() async {

    if (_document != null) {
      return; // 이미 로드된 경우 종료
    }

    try {
      final document = await PdfDocument.openFile(widget.pdfPath);
      final totalPages = document.pageCount;

      setState(() {
        _document = document;
        _totalPages = totalPages;
      });


      await _preloadPages(_currentPage);
    } catch (e) {
      _showErrorSnackBar('PDF를 로드하는 중 문제가 발생했습니다.');
    }
  }

  Future<void> _preloadPages(int pageNumber) async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (int pageNumber = 1; pageNumber <= _totalPages; pageNumber++) {
        if (!_pageCache.containsKey(pageNumber)) {
          _pageCache[pageNumber] = await _renderPage(pageNumber);
        }
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('모든 페이지 렌더링 중 문제가 발생했습니다.');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> _renderPage(int pageNumber) async {
    if (_document == null) return null;

    try {
      final pageImage = await _pdfImageService.renderPdfPageAsImage(widget.pdfPath, pageNumber);

      if (pageNumber == _currentPage && pageImage != null) 
      {
        // 현재 페이지 이미지를 업데이트
        setState(() {
          _currentPageImage = pageImage; // 페이지 이미지를 저장
        });
      }
      return pageImage;
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadSavedData() async {
    try {
      final scoreData = await _storageService.getScoreData(widget.pdfPath);

      if (scoreData != null) {
        setState(() {
          _rectanglesByScore[_currentScoreName] = (scoreData['rectangles'] as List<dynamic>)
              .map((page) => (page as List<dynamic>)
                  .map((rect) => Map<String, dynamic>.from(rect as Map))
                  .toList())
              .toList();

          _imageSizesByScore[_currentScoreName] = (scoreData['image_sizes'] as List<dynamic>)
              .map((size) => Map<String, dynamic>.from(size as Map))
              .toList();

          rectangleCycleOverrides = (scoreData['cycles'] as Map<String, dynamic>)
              .map((key, value) => MapEntry(
                  int.parse(key),
                  (value as Map<String, dynamic>)
                      .map((k, v) => MapEntry(int.parse(k), v is int ? v : int.tryParse(v.toString())?? 4))));
          
          if (scoreData.containsKey('bpm')) {
            final bpmData = (scoreData['bpm'] as Map<String, dynamic>).map((key, value) =>
              MapEntry(int.parse(key), value is int ? value : int.tryParse(value.toString()) ?? 0));
            bpmData.forEach((key,value){
              rectangleCycleOverrides[key] ??= {};
              rectangleCycleOverrides[key]![key + 500] = value;
            });
          }
                      
        for (int pageIndex = 0; pageIndex < _rectanglesByScore[_currentScoreName]!.length; pageIndex++) {
          rectangleCycleOverrides[pageIndex] ??= {};
          for (int rectIndex = 0; rectIndex < _rectanglesByScore[_currentScoreName]![pageIndex].length; rectIndex++) {
            rectangleCycleOverrides[pageIndex]![rectIndex] ??= 4; // 기본값 4
            rectangleCycleOverrides[pageIndex]![rectIndex + 500] ??= 0;
          }
        }


        });

        final firstRectangleCycle = rectangleCycleOverrides[0]?[0] ?? 4;
        int firstRectangleBpm = rectangleCycleOverrides[0]?[500] ?? 0;
        if(firstRectangleBpm == 0)
        {
          firstRectangleBpm = _metronomeService.metronumBpm;
        }
        _metronomeService.updateCycleAndBpm(firstRectangleCycle,firstRectangleBpm);
      } else {
        //_detectStaffLinesForAllPages();
      }
    } catch (e) {

      _detectStaffLinesForAllPages();
    }
  }

  Future<void> _saveCurrentScoreData() async {
    final scoreData = {
      'rectangles': _rectanglesByScore[_currentScoreName]?.map((pageRectangles) =>
          pageRectangles.map((rect) => Map<String, dynamic>.from(rect)).toList()).toList(),
      'image_sizes': _imageSizesByScore[_currentScoreName]?.map((size) => Map<String, dynamic>.from(size)).toList(),
      'cycles': rectangleCycleOverrides.map((key, value) => MapEntry(
          key.toString(), value.map((k, v) => MapEntry(k.toString(), v)))),
      'bpm':rectangleCycleOverrides.map((key,value) => MapEntry(
        key.toString(),
        value.entries
          .where((entry) => entry.key >= 500)
          .map((entry) => MapEntry(entry.key.toString(), entry.value))
          .toList()
          .asMap()
          .map((_,v) => v))),
    };

    try {
      await _storageService.saveScoreData(widget.pdfPath, scoreData);
    } catch (e) {
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true; // 카운트다운 시작
      _countdownValue = 4; // 초기 카운트다운 값
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _countdownValue--;

        if (_countdownValue <= 0) {
          // 카운트다운 종료
          timer.cancel();
          _isCountingDown = false;

          // 메트로놈 시작
          _metronomeService.start();
        }
      });
    });
  }

  Future<void> _showCycleEditDialog(
    BuildContext context,
    int pageIndex,
    int rectangleIndex,
    Map<int, Map<int, int>> rectangleCycleOverrides) async {
    int tempCycle = rectangleCycleOverrides[pageIndex]?[rectangleIndex] ?? 4;
    int tempBPM = rectangleCycleOverrides[pageIndex]?[rectangleIndex + 500] ?? 0; // 현재 BPM 가져오기

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text('메트로놈 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 메트로놈 주기 설정
                  Text('현재 주기: $tempCycle'),
                  Slider(
                    value: tempCycle.toDouble(),
                    min: 1,
                    max: 16,
                    divisions: 15,
                    label: tempCycle.toString(),
                    onChanged: (value) {
                      dialogSetState(() {
                        tempCycle = value.toInt();
                      });
                    },
                  ),
                  Divider(),
                  // BPM 설정
                  Text(' '),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          dialogSetState(() {
                            if (tempBPM >= 0) tempBPM--; // 최소 BPM 제한
                          });
                        },
                      ),
                      Text(
                        '${tempBPM==0 ? _metronomeService.metronumBpm : tempBPM}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          dialogSetState(() {
                            if (tempBPM < 300) tempBPM++; // 최대 BPM 제한
                          });
                        },
                      ),
                    ],
                  ),
                  Slider(
                    value: tempBPM.toDouble(),
                    min: 0,
                    max: 300,
                    divisions: 260,
                    label: tempBPM.toString(),
                    onChanged: (value) {
                      dialogSetState(() {
                        tempBPM = value.toInt();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // 메트로놈 주기 저장
                      rectangleCycleOverrides[pageIndex] ??= {};
                      rectangleCycleOverrides[pageIndex]![rectangleIndex] = tempCycle;

                      // BPM 저장
                       rectangleCycleOverrides[pageIndex]![rectangleIndex+500] = tempBPM;
                    });
                    _saveCurrentScoreData();

                    Navigator.pop(context);
                  },
                  child: Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleScanner() {

    if (_rectanglesByScore.containsKey(_currentScoreName)) {
      setState(() {
        _showRectanglesByScore[_currentScoreName] =
            !(_showRectanglesByScore[_currentScoreName] ?? false);
      });

      return;
    }

    _detectStaffLinesForAllPages();
  }

  void _refreshScreen() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _initializeViewer();
      _metronomeService.loadBPM(widget.scoreName);
      _metronomeService.onCycleComplete = _handleCycleComplete;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('새로고침 완료')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('새로고침 중 오류 발생: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.scoreName),
      actions: [
        IconButton(
          onPressed: _refreshScreen,
          icon: Icon(Icons.refresh),
          tooltip: '새로고침',
        ),
        IconButton(
          onPressed: () {
            if (_metronomeService.isPlaying) {
              _metronomeService.stop();
            } else if (!_isCountingDown) { // 카운트다운 중복 방지
              _startCountdown();
            }
            setState(() {});
          },
          icon: Icon(
            _metronomeService.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
        IconButton(
          onPressed: () {
            _metronomeService.showBPMDialog(context, widget.scoreName);
          },
          icon: Icon(Icons.speed),
        ),
        IconButton(
          onPressed: _toggleScanner,
          icon: Icon(
            _showRectanglesByScore[_currentScoreName] ?? false
                ? Icons.visibility_off
                : Icons.scanner,
          ),
        ),
      ],
    ),
    body: Stack(
      children: [
        Column(
          children: [
            // PDF Viewer
            Expanded(
              child: PageView.builder(
                itemCount: _totalPages,
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index + 1;
                    _currentRectangleIndex = 0; // 페이지 변경 시 첫 사각형으로 초기화

                    final firstRectangleCycle = rectangleCycleOverrides[_currentPage - 1]?[0] ?? 4;
                    int firstRectangleBpm = rectangleCycleOverrides[_currentPage - 1]?[500] ?? 0;
                    if(firstRectangleBpm == 0)
                    {
                      firstRectangleBpm = _metronomeService.metronumBpm;
                    }
                    _metronomeService.updateCycleAndBpm(firstRectangleCycle,firstRectangleBpm);
                  });
                },
                itemBuilder: (context, index) {
                  return Center(
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : _pageCache[index + 1] != null
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_renderedImageWidth == null || _renderedImageHeight == null) {
                                      setState(() {
                                        _renderedImageWidth = constraints.maxWidth;
                                        _renderedImageHeight = constraints.maxWidth *
                                            (_imageSizesByScore[_currentScoreName]![index]['height'] /
                                                _imageSizesByScore[_currentScoreName]![index]['width']);
                                      });
                                    }
                                  });
                                  return Stack(
                                    children: [
                                      // PDF 페이지 표시
                                      if (_pageCache[index + 1] != null)
                                        Image.memory(
                                          _pageCache[index + 1]!,
                                          fit: BoxFit.contain,
                                          width: constraints.maxWidth,
                                        ),
                                      // 검출된 사각형 표시
                                      if (_renderedImageWidth != null &&
                                          _renderedImageHeight != null &&
                                          _rectanglesByScore.containsKey(_currentScoreName) &&
                                          _rectanglesByScore[_currentScoreName]!.isNotEmpty &&
                                          (_showRectanglesByScore[_currentScoreName] ?? false) &&
                                          index < _rectanglesByScore[_currentScoreName]!.length)
                                        ..._buildRectanglesForPageWithTouch(index),
                                    ],
                                  );
                                },
                              )
                            : Text(
                                '페이지를 로드할 수 없습니다.',
                                style: TextStyle(fontSize: 16.0),
                              ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_isCountingDown) // 카운트다운 중이면 표시
          Center(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Text(
                '$_countdownValue',
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

  List<Widget> _buildRectanglesForPageWithTouch(int pageIndex) {

  if (!_rectanglesByScore.containsKey(_currentScoreName) ||
      !_imageSizesByScore.containsKey(_currentScoreName)) {
    
    return [];
  }

  final originalImageWidth = _imageSizesByScore[_currentScoreName]![pageIndex]['width'];
  final originalImageHeight = _imageSizesByScore[_currentScoreName]![pageIndex]['height'];
  final rectangles = _rectanglesByScore[_currentScoreName]![pageIndex];

  return rectangles.asMap().entries.map((entry) {
    final rect = entry.value;
    final index = entry.key;

    final isHighlighted = index == _currentRectangleIndex;

    final topLeft = rect['top_left'];
    final bottomRight = rect['bottom_right'];


    final left = (topLeft[0] / originalImageWidth) * _renderedImageWidth!;
    final top = (topLeft[1] / originalImageHeight) * _renderedImageHeight!;
    final width = ((bottomRight[0] - topLeft[0]) / originalImageWidth) * _renderedImageWidth!;
    final height = ((bottomRight[1] - topLeft[1]) / originalImageHeight) * _renderedImageHeight!;
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentRectangleIndex = index; // 강조 상태를 업데이트
            final currentMetronomePlay = _metronomeService.isPlaying;
            _metronomeService.stop();

            final currentCycle = rectangleCycleOverrides[_currentPage - 1]?[index] ?? 4;
            int currentBpm = rectangleCycleOverrides[_currentPage - 1]?[index+500] ?? 0;
            if (currentBpm == 0)
            {
              currentBpm = _metronomeService.metronumBpm;
            }
            
            _metronomeService.updateCycleAndBpm(currentCycle,currentBpm);

            if (currentMetronomePlay) {
              if (!_isCountingDown) {
                _startCountdown();
              }
            }
          });
        },
        
        onLongPress: () async {
          // 롱 프레스 이벤트 처리
          rectangleCycleOverrides[_currentPage] ??= {};
          await _showCycleEditDialog(
            context,
            pageIndex,
            index,
            rectangleCycleOverrides,
          );
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isHighlighted ? Colors.green.withOpacity(0.5) : Colors.transparent,
            border: Border.all(color: const Color.fromARGB(255, 238, 160, 154), width: 2),
          ),
        ),
      ),
    );

  }).toList();
}

  @override
  void dispose() {
    _metronomeService.dispose();
    _document?.dispose();
    super.dispose();
  }
}
