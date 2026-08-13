import 'dart:async';
import 'dart:developer';

import 'package:flutter_agentic_app/provider/base_provider.dart';
import 'package:flutter_agentic_app/services/voice_agent_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceAgentPhase { idle, listening, thinking, speaking }

class ToolCallLog {
  final String name;
  final Map<String, Object?> args;
  final Map<String, Object?>? result;
  final DateTime at;

  const ToolCallLog({
    required this.name,
    required this.args,
    this.result,
    required this.at,
  });

  bool get isComplete => result != null;
}

class VoiceTurn {
  final String userText;
  final String? agentText;
  final List<ToolCallLog> tools;

  const VoiceTurn({
    required this.userText,
    this.agentText,
    this.tools = const [],
  });
}

class VoiceAgentProvider extends BaseProvider {
  VoiceAgentProvider({
    SpeechToText? speech,
    VoiceAgentService? agentService,
  }) : _speech = speech ?? SpeechToText() {
    _agent =
        agentService ??
        VoiceAgentService(
          onToolStarted: _onToolStarted,
          onToolFinished: _onToolFinished,
        );
  }

  static const _softSpeechErrors = {
    'error_speech_timeout',
    'error_no_match',
    'error_busy',
    'error_client',
  };

  final SpeechToText _speech;
  late final VoiceAgentService _agent;

  VoiceAgentPhase _phase = VoiceAgentPhase.idle;
  String _partialTranscript = '';
  String _lastReply = '';
  double _soundLevel = 0;
  bool _speechReady = false;
  bool _handlingUtterance = false;
  String? _localeId;
  final List<VoiceTurn> _turns = [];
  final List<ToolCallLog> _activeTools = [];

  VoiceAgentPhase get phase => _phase;
  String get partialTranscript => _partialTranscript;
  String get lastReply => _lastReply;
  double get soundLevel => _soundLevel;
  bool get isListening => _phase == VoiceAgentPhase.listening;
  List<VoiceTurn> get turns => List.unmodifiable(_turns);
  List<ToolCallLog> get activeTools => List.unmodifiable(_activeTools);

  Future<bool> ensureReady() async {
    if (_speechReady) return true;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      setError('Microphone permission is required for voice mode.');
      return false;
    }

    _speechReady = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: (status) {
        log('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (_phase == VoiceAgentPhase.listening &&
              !_handlingUtterance &&
              _partialTranscript.trim().isEmpty) {
            _phase = VoiceAgentPhase.idle;
            notifyListeners();
          }
        }
      },
    );

    if (!_speechReady) {
      setError('Speech recognition is unavailable on this device.');
      return false;
    }

    _localeId = await _resolveLocale();
    return true;
  }

  Future<String?> _resolveLocale() async {
    try {
      final system = await _speech.systemLocale();
      if (system != null) return system.localeId;

      final locales = await _speech.locales();
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('en')) {
          return locale.localeId;
        }
      }
      return locales.isNotEmpty ? locales.first.localeId : null;
    } catch (_) {
      return null;
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    log('Speech error: ${error.errorMsg} (permanent: ${error.permanent})');

    // Timeout / no-match are normal when the user pauses or speech is unclear.
    if (_softSpeechErrors.contains(error.errorMsg)) {
      if (_handlingUtterance) return;

      final leftover = _partialTranscript.trim();
      if (leftover.isNotEmpty) {
        unawaited(_processUtterance(leftover));
        return;
      }

      _phase = VoiceAgentPhase.idle;
      _soundLevel = 0;
      setError('Didn’t catch that — tap the orb and try again.');
      return;
    }

    _phase = VoiceAgentPhase.idle;
    _soundLevel = 0;
    setError(
      error.permanent
          ? 'Speech recognition failed. Check mic permissions and try again.'
          : 'Speech recognition hiccup. Tap the orb to retry.',
    );
  }

  Future<void> toggleListening() async {
    if (_phase == VoiceAgentPhase.thinking || _handlingUtterance) return;

    if (_phase == VoiceAgentPhase.listening) {
      await stopListening();
      return;
    }

    await startListening();
  }

  Future<void> startListening() async {
    clearError();
    final ready = await ensureReady();
    if (!ready) return;

    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    _partialTranscript = '';
    _activeTools.clear();
    _soundLevel = 0;
    _handlingUtterance = false;
    _phase = VoiceAgentPhase.listening;
    notifyListeners();

    await _speech.listen(
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) {
        if (_phase != VoiceAgentPhase.listening) return;
        _soundLevel = level;
        notifyListeners();
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: _localeId,
      ),
    );
  }

  Future<void> stopListening() async {
    final text = _partialTranscript.trim();
    await _speech.stop();

    if (_phase != VoiceAgentPhase.listening || _handlingUtterance) return;

    if (text.isNotEmpty) {
      await _processUtterance(text);
    } else {
      _phase = VoiceAgentPhase.idle;
      _soundLevel = 0;
      notifyListeners();
    }
  }

  Future<void> submitText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    clearError();
    await _processUtterance(trimmed);
  }

  void clearSession() {
    _turns.clear();
    _activeTools.clear();
    _partialTranscript = '';
    _lastReply = '';
    _phase = VoiceAgentPhase.idle;
    _handlingUtterance = false;
    _agent.resetChat();
    clearError();
    notifyListeners();
  }

  Future<void> _onSpeechResult(SpeechRecognitionResult result) async {
    _partialTranscript = result.recognizedWords;
    notifyListeners();

    if (!result.finalResult || _handlingUtterance) return;

    final text = result.recognizedWords.trim();
    if (text.isEmpty) {
      _phase = VoiceAgentPhase.idle;
      notifyListeners();
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }
    await _processUtterance(text);
  }

  Future<void> _processUtterance(String text) async {
    if (_handlingUtterance) return;
    _handlingUtterance = true;

    _phase = VoiceAgentPhase.thinking;
    _partialTranscript = text;
    _activeTools.clear();
    _soundLevel = 0;
    setLoading(true);
    notifyListeners();

    try {
      final reply = await _agent.handleUtterance(text);
      _lastReply = reply;
      _turns.insert(
        0,
        VoiceTurn(
          userText: text,
          agentText: reply,
          tools: List<ToolCallLog>.from(_activeTools),
        ),
      );
      _phase = VoiceAgentPhase.speaking;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _phase = VoiceAgentPhase.idle;
    } catch (e, stackTrace) {
      log('Voice process failed: $e', stackTrace: stackTrace);
      setError('Agent failed to respond. Please try again.');
      _phase = VoiceAgentPhase.idle;
    } finally {
      _handlingUtterance = false;
      setLoading(false);
      notifyListeners();
    }
  }

  void _onToolStarted(String name, Map<String, Object?> args) {
    _activeTools.add(
      ToolCallLog(name: name, args: args, at: DateTime.now()),
    );
    notifyListeners();
  }

  void _onToolFinished(String name, Map<String, Object?> result) {
    final index = _activeTools.lastIndexWhere(
      (t) => t.name == name && t.result == null,
    );
    if (index >= 0) {
      final existing = _activeTools[index];
      _activeTools[index] = ToolCallLog(
        name: existing.name,
        args: existing.args,
        result: result,
        at: existing.at,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    super.dispose();
  }
}
