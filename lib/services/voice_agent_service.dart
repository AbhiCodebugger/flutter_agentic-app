import 'dart:developer';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_agentic_app/services/agent_tools.dart';

typedef ToolLifecycleCallback =
    void Function(String name, Map<String, Object?> payload);

class VoiceAgentService {
  VoiceAgentService({
    AgentTools? tools,
    this.onToolStarted,
    this.onToolFinished,
  }) : _tools = tools ?? AgentTools() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite',
      systemInstruction: Content.system(
        'You are a futuristic voice agent inside a Flutter app. '
        'Use tools when they help answer the user. '
        'Prefer get_weather for weather questions, get_current_time for time, '
        'and tell_joke for humor requests. '
        'After tools run, reply in a concise, natural spoken style.',
      ),
      tools: [
        Tool.functionDeclarations([
          AutoFunctionDeclaration(
            name: 'get_weather',
            description:
                'Get the current weather for a city using live weather data.',
            parameters: {
              'city': Schema.string(
                description:
                    'City name, optionally with region/country. Example: New York',
              ),
            },
            callable: (args) => _runTool('get_weather', args, _tools.getWeather),
          ),
          AutoFunctionDeclaration(
            name: 'get_current_time',
            description: 'Get the current local time on the user device.',
            parameters: {
              'location_hint': Schema.string(
                description:
                    'Optional place mentioned by the user, for context only.',
              ),
            },
            optionalParameters: const ['location_hint'],
            callable: (args) =>
                _runTool('get_current_time', args, _tools.getCurrentTime),
          ),
          AutoFunctionDeclaration(
            name: 'tell_joke',
            description: 'Tell a short joke, optionally for a topic.',
            parameters: {
              'topic': Schema.string(
                description: 'Joke topic such as tech, weather, or general.',
              ),
            },
            optionalParameters: const ['topic'],
            callable: (args) => _runTool('tell_joke', args, _tools.tellJoke),
          ),
        ]),
      ],
      toolConfig: ToolConfig(
        functionCallingConfig: FunctionCallingConfig.auto(),
      ),
    );
    _chat = _model.startChat();
  }

  final AgentTools _tools;
  final ToolLifecycleCallback? onToolStarted;
  final ToolLifecycleCallback? onToolFinished;

  late final GenerativeModel _model;
  late ChatSession _chat;

  Future<String> handleUtterance(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'I did not catch that. Try again.';
    }

    try {
      final response = await _chat.sendMessage(Content.text(trimmed));
      final reply = response.text?.trim();
      if (reply == null || reply.isEmpty) {
        return 'I ran the tools, but have no spoken reply yet. Ask me again.';
      }
      return reply;
    } catch (e, stackTrace) {
      log('Voice agent failed: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  void resetChat() {
    _chat = _model.startChat();
  }

  Future<Map<String, Object?>> _runTool(
    String name,
    Map<String, Object?> args,
    Future<Map<String, Object?>> Function(Map<String, Object?> args) impl,
  ) async {
    onToolStarted?.call(name, args);
    final result = await impl(args);
    onToolFinished?.call(name, result);
    return result;
  }
}
