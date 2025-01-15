import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetronomeService {
  final AudioPlayer _strongBeatPlayer = AudioPlayer();
  final AudioPlayer _weakBeatPlayer = AudioPlayer();
  late Ticker _ticker;

  bool isPlaying = false;
  int currentBPM = 120; // 기본 BPM
  int metronumBpm = 120;
  int currentRhythmType = 4; // 기본 리듬 유형
  int _currentBeat = -1; // 초기화 시 강제 첫 틱 재생
  int _cycleCounter = 0;
  bool isInitialized = false;
  int correctionNum = 100000;

  int _currentCycle = 4; // 메트로놈 주기 (기본값 4)

  Function? onCycleComplete;

  MetronomeService(TickerProvider tickerProvider) {
  _ticker = tickerProvider.createTicker((elapsed) {
    _onTick(elapsed); // _onTick 호출 확인
  });
}

  Future<void> initialize() async {
  if (isInitialized) return; // 이미 초기화된 경우 다시 실행하지 않음
  isInitialized = true;

  try {
    debugPrint('[App]오디오 파일 로드 시작');
    await _strongBeatPlayer.setAsset('assets/sounds/strong_beat.mp3');
    
    await _weakBeatPlayer.setAsset('assets/sounds/weak_beat.mp3');
    

    await _strongBeatPlayer.load();
    await _weakBeatPlayer.load();

    _strongBeatPlayer.setVolume(1.0);
    _weakBeatPlayer.setVolume(1.0);

  } catch (e) {
    debugPrint('[App][MetronomeService] 오디오 초기화 오류: $e');
  }
}

  void updateCycleAndBpm(int cycle, int bpm) {
    _currentCycle =cycle;
    currentBPM = bpm;
    if (isPlaying) {
      stop(); // 기존 메트로놈 중지
      start(); // 새로운 주기로 시작
    }
  }


  void start() async {
    if (!isPlaying) {
      isPlaying = true;
      _currentBeat = -1; // 초기화 상태로 설정
      _cycleCounter = 0; // 사이클 초기화


      // 강음과 약음 간격(한 박자 간격) 계산
      final intervalInMicroseconds = (60000000 / currentBPM).round(); // 1분 = 60,000,000μs
      final intervalnum = intervalInMicroseconds-correctionNum;
      final interval = Duration(microseconds: intervalnum);
      // 대기 후 첫 번째 강음 출력
      await Future.delayed(interval, () {
        _currentBeat = 0; // 첫 번째 강음 박자 설정
        _playSound(_strongBeatPlayer);
      });

      // Ticker 시작
      _ticker.start();
    }
  }

  void stop() {
    if (!isPlaying) {

      return;
    }
  try {
    _ticker.stop();
    isPlaying = false;
    _currentBeat = 0;
    _cycleCounter = 0;
  } catch (e) {
    debugPrint("[App] [MetronomeService] stop 호출 중 오류 발생: $e");
  }
  }

  void _onTick(Duration elapsed) async {
  // 한 박자의 간격 계산 (BPM 기반)
  final interval = Duration(milliseconds: (60000 / currentBPM).round());
  final totalBeatsElapsed = elapsed.inMilliseconds ~/ interval.inMilliseconds;

  // 현재 전체 진행 중인 박자 (전체 박자 계산)
  final totalBeatsInCycle = currentRhythmType * _currentCycle;
  final currentBeatInTotal = totalBeatsElapsed % totalBeatsInCycle;

  // 현재 주기 내에서 몇 번째 박자인지 계산
  final currentBeatInRhythm = currentBeatInTotal % currentRhythmType;

  // 현재 몇 번째 사이클인지 계산
  final currentCycle = currentBeatInTotal ~/ currentRhythmType;

  // 강제 초기화: 처음 실행 시 강음 출력
  if (_currentBeat == -1) {
    _currentBeat = 0;
    _cycleCounter = 0;
    await _playSound(_strongBeatPlayer);
    return;
  }

  // 이전 상태와 비교하여 새로운 상태라면 처리
  if (_currentBeat != currentBeatInRhythm || _cycleCounter != currentCycle) {
    _currentBeat = currentBeatInRhythm;
    _cycleCounter = currentCycle;

    // 강한 박자 (첫 박자)
    if (_currentBeat == 0) {

      await _playSound(_strongBeatPlayer);
    } else {
      // 약한 박자
      await _playSound(_weakBeatPlayer);
    }

    // 마지막 사이클이 끝났을 때 콜백 호출
    if (_cycleCounter == _currentCycle - 1 && _currentBeat == currentRhythmType - 1) {
      if (onCycleComplete != null) {
        onCycleComplete!();
      }
    }
  }
}

  Future<void> _playSound(AudioPlayer player) async {
  if (player.processingState == ProcessingState.completed) {
    await player.seek(Duration.zero); // 처음부터 재생 준비
  }
  if (player.processingState == ProcessingState.ready) {
    await player.play();
  }
}

  Future<void> loadBPM(String scoreName) async {
    final prefs = await SharedPreferences.getInstance();
    currentBPM = prefs.getInt('bpm_$scoreName') ?? 120; // 기본값 120
    metronumBpm = currentBPM;
  }

  Future<void> saveBPM(String scoreName, int bpm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bpm_$scoreName', bpm);
  }

  Future<void> saveRhythmType(String scoreName, int rhythmType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rhythm_$scoreName', rhythmType);
  }

  Future<void> showBPMDialog(BuildContext context, String scoreName) async {
  int tempBPM = currentBPM;
  int tempRhythmType = currentRhythmType;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: Text('BPM 및 비트 설정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // BPM 조정 UI
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () {
                        dialogSetState(() {
                          if (tempBPM > 10) tempBPM--;
                        });
                      },
                    ),
                    Text(
                      '$tempBPM',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        dialogSetState(() {
                          if (tempBPM < 300) tempBPM++;
                        });
                      },
                    ),
                  ],
                ),
                // BPM 슬라이더 추가
                Slider(
                  value: tempBPM.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 290,
                  label: tempBPM.toString(),
                  onChanged: (value) {
                    dialogSetState(() {
                      tempBPM = value.toInt();
                    });
                  },
                ),
                Divider(),
                // 비트 설정 슬라이더
                Text(
                  '비트: $tempRhythmType',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: tempRhythmType.toDouble(),
                  min: 1,
                  max: 16,
                  divisions: 15,
                  label: tempRhythmType.toString(),
                  onChanged: (value) {
                    dialogSetState(() {
                      tempRhythmType = value.toInt();
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 다이얼로그 닫기
                },
                child: Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  currentBPM = tempBPM;
                  currentRhythmType = tempRhythmType;

                  saveBPM(scoreName, tempBPM);
                  saveRhythmType(scoreName, tempRhythmType);

                  Navigator.pop(context); // 다이얼로그 닫기
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

  void dispose() {
    _strongBeatPlayer.dispose();
    _weakBeatPlayer.dispose();
    _ticker.dispose();
  }
}
