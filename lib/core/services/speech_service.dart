import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// UI state enumeration for voice-to-text input.
enum VoiceState {
  /// Microphone is available and ready to record.
  idle,

  /// Microphone is actively listening to citizen speech.
  listening,

  /// Speech recognition is finalizing/processing words.
  processing,

  /// Speech recognized and transcript is ready/editable.
  ready,

  /// Speech recognition encountered an error (network, timeout, etc.).
  error,

  /// Microphone permission was denied by citizen or OS.
  permissionDenied,
}

/// Abstract contract for Speech-to-Text emergency input service.
///
/// Ensures clean separation between UI components and platform-specific
/// speech recognition engines, enabling headless testing and modularity.
abstract class SpeechService {
  /// Whether the service is currently capturing microphone speech.
  bool get isListening;

  /// Whether speech recognition is initialized and available on the device.
  bool get isAvailable;

  /// Initializes the underlying speech recognition engine and checks permissions.
  Future<bool> initialize({
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  });

  /// Starts listening for voice input and continuously streams recognized text.
  ///
  /// Calls [onResult] with the latest recognized words and whether it's final.
  Future<bool> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  });

  /// Stops active listening and returns final recognized transcript.
  Future<void> stopListening();

  /// Cancels listening and discards partial transcript.
  Future<void> cancelListening();

  /// Releases resources and stream controllers.
  void dispose();
}

/// Production implementation of [SpeechService] using the `speech_to_text` package.
///
/// CRITICAL PRIVACY ASSURANCE:
/// - Never writes audio files to disk.
/// - Never uploads raw audio recordings to any server.
/// - Transmits only client-side recognized text strings into the incident flow.
class SpeechToTextService implements SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  void Function(String error)? _onErrorCallback;
  void Function(String status)? _onStatusCallback;

  @override
  bool get isListening => _speech.isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<bool> initialize({
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    _onErrorCallback = onError;
    _onStatusCallback = onStatus;

    try {
      _isAvailable = await _speech.initialize(
        onError: (val) {
          debugPrint('SpeechToText error: ${val.errorMsg}');
          _onErrorCallback?.call(val.errorMsg);
        },
        onStatus: (val) {
          debugPrint('SpeechToText status: $val');
          _onStatusCallback?.call(val);
        },
        debugLogging: false,
      );
      return _isAvailable;
    } catch (e) {
      debugPrint('SpeechToText initialization exception: $e');
      _isAvailable = false;
      _onErrorCallback?.call('Initialization failed: $e');
      return false;
    }
  }

  @override
  Future<bool> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (!_isAvailable) {
      final initialized = await initialize(
        onError: _onErrorCallback,
        onStatus: _onStatusCallback,
      );
      if (!initialized) return false;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          cancelOnError: true,
          partialResults: true,
          localeId: localeId,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('SpeechToText listen error: $e');
      _onErrorCallback?.call('Failed to start listening: $e');
      return false;
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('SpeechToText stop error: $e');
    }
  }

  @override
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('SpeechToText cancel error: $e');
    }
  }

  @override
  void dispose() {
    _speech.stop();
  }
}

/// In-memory mock implementation of [SpeechService] for deterministic unit and widget testing.
class MockSpeechService implements SpeechService {
  bool _isListening = false;
  bool _isAvailable = true;
  bool simulatePermissionDenied = false;
  bool simulateInitError = false;
  String? simulatedWords;

  void Function(String error)? _onError;
  void Function(String status)? _onStatus;
  void Function(String recognizedWords, bool isFinal)? _currentOnResult;

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  void setAvailable(bool available) {
    _isAvailable = available;
  }

  @override
  Future<bool> initialize({
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    _onError = onError;
    _onStatus = onStatus;

    if (simulatePermissionDenied) {
      _isAvailable = false;
      _onError?.call('error_permission_denied');
      return false;
    }
    if (simulateInitError) {
      _isAvailable = false;
      _onError?.call('Speech recognition unavailable');
      return false;
    }
    _isAvailable = true;
    _onStatus?.call('ready');
    return true;
  }

  @override
  Future<bool> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (simulatePermissionDenied) {
      _onError?.call('error_permission_denied');
      return false;
    }
    if (!_isAvailable) {
      _onError?.call('Speech recognition not available');
      return false;
    }

    _isListening = true;
    _currentOnResult = onResult;
    _onStatus?.call('listening');

    if (simulatedWords != null) {
      // Simulate speech result callback
      onResult(simulatedWords!, true);
    }
    return true;
  }

  /// Manually emit recognition result during tests
  void emitWords(String words, {bool isFinal = true}) {
    _currentOnResult?.call(words, isFinal);
  }

  /// Manually emit status update during tests
  void emitStatus(String status) {
    _onStatus?.call(status);
  }

  /// Manually emit error during tests
  void emitError(String error) {
    _onError?.call(error);
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    _onStatus?.call('notListening');
  }

  @override
  Future<void> cancelListening() async {
    _isListening = false;
    _onStatus?.call('notListening');
  }

  @override
  void dispose() {
    _isListening = false;
  }
}
