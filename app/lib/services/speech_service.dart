import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechState { idle, listening, error }

/// 语音输入。只负责"说话 → 文字"，不做任何时间解析（那是 US-023 / P2）。
///
/// 失败一律降级为可读的中文提示，绝不静默失败（见 02 §2.4）。
class SpeechService extends ChangeNotifier {
  SpeechService._();

  static final SpeechService instance = SpeechService._();

  final SpeechToText _speech = SpeechToText();

  SpeechState _state = SpeechState.idle;
  String _words = '';
  String? _errorMessage;
  bool _initialized = false;

  SpeechState get state => _state;
  String get words => _words;
  String? get errorMessage => _errorMessage;
  bool get isListening => _state == SpeechState.listening;

  /// 开始识别。返回错误文案（null = 成功开始）。
  Future<String?> start() async {
    _errorMessage = null;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      return _fail('没有麦克风权限，去设置里开启');
    }

    if (!await _ensureInitialized()) {
      return _fail('这台设备暂时用不了语音识别，请手动输入');
    }

    _words = '';
    _state = SpeechState.listening;
    notifyListeners();

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          _words = result.recognizedWords;
          notifyListeners();
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: 'zh_CN',
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
        ),
      );
      return null;
    } catch (_) {
      return _fail('这台设备暂时用不了语音识别，请手动输入');
    }
  }

  /// 结束识别，返回识别到的文本（已 trim）。
  Future<String> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      // 未开始/已结束时忽略
    }
    if (_state != SpeechState.error) _state = SpeechState.idle;
    notifyListeners();
    return _words.trim();
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // ignore
    }
    _words = '';
    if (_state != SpeechState.error) _state = SpeechState.idle;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == SpeechState.error) _state = SpeechState.idle;
    notifyListeners();
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      final ok = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          _fail(_messageFor(error.errorMsg));
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              _state == SpeechState.listening) {
            _state = SpeechState.idle;
            notifyListeners();
          }
        },
      );
      _initialized = ok;
      return ok;
    } catch (_) {
      // 某些设备没有识别服务时，initialize 会直接抛 PlatformException
      _initialized = false;
      return false;
    }
  }

  String? _fail(String message) {
    _errorMessage = message;
    _state = SpeechState.error;
    notifyListeners();
    return message;
  }

  String _messageFor(String code) {
    switch (code) {
      case 'permissionDenied':
      case 'permission_permanently_denied':
        return '没有麦克风权限，去设置里开启';
      case 'no_match':
      case 'speech_timeout':
        return '没听清，再说一次？';
      case 'network':
      case 'network_timeout':
        return '语音识别需要联网，检查一下网络';
      case 'recognizer_busy':
        return '识别服务忙，稍后再试';
      default:
        return '语音识别出错了，请手动输入';
    }
  }

  /// 桌面端：鼠标"按住说话"别扭，改为点击开始/点击结束。
  static bool get isDesktop =>
      !(Platform.isAndroid || Platform.isIOS);
}
