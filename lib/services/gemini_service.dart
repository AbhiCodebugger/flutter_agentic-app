import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_agentic_app/example.dart';

class GeminiService {
  // A more robust singleton pattern
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._internal();

  // Initialize the model once and reuse it.
  final GenerativeModel _model;

  // Private constructor
  GeminiService._internal()
    : _model = FirebaseAI.googleAI().generativeModel(
        // Using a valid and recent model
        model: "gemini-3.1-flash-lite",
      );

  static const String defaultVisionPrompt =
      'Explain this image clearly and thoroughly. Describe the main subjects, '
      'setting, notable details, colors, and any visible text. Keep the tone '
      'helpful and concise.';

  String buildGeminiPrompt({
    required List<String> topics,
    required int currentPage,
    required int limit,
  }) {
    final topicsString = topics.join(', ');
    final jsonSchema = '''
{
  "total": "int (total number of jokes available for the topic)",
  "current_page": "int (the current page number)",
  "jokes": [
    {
      "joke": "string (the joke content)",
      "author": "string (the author's name, can be fictional)",
      "date": "string (formatted as DD-MMM-YYYY)"
    }
  ],
  "topic": ["string (the topic of the jokes)"]
}
''';

    return '''
You are a creative and witty comedian AI. Your task is to generate a list of unique jokes based on specific topics.

### Instructions:
1.  Generate **$limit** unique jokes for the following topic(s): **$topicsString**.
2.  The response must be paginated. This is for page **$currentPage**.
3.  You MUST return the output in a valid JSON format. Do not include any text, explanation, or markdown formatting before or after the JSON object.
4.  The JSON object must strictly adhere to the following schema.

### JSON Schema:
```json
$jsonSchema
```

### Example Output:
```json
${jokeStruct.toString()}
```

Now, generate the jokes for the topic(s): "$topicsString".
''';
  }

  Future<Map<String, dynamic>?> generateJokes({
    required List<String> topics,
    required int page,
    required int limit,
  }) async {
    // Input validation
    if (topics.isEmpty) {
      log("Error: Topics list cannot be empty.");
      return null;
    }

    try {
      // FIX: Use the method parameters instead of hardcoded values.
      final prompt = buildGeminiPrompt(
        topics: topics,
        currentPage: page,
        limit: limit,
      );

      final res = await _model.generateContent([Content.text(prompt)]);
      log("Received response: ${res.text}");

      if (res.text == null || res.text!.isEmpty) {
        log("Error: Received empty response from the model.");
        return null;
      }

      final cleanedJson = cleanLLMJson(res.text!);
      return jsonDecode(cleanedJson) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      log(
        "An error occurred in generateJokes: ${e.toString()}",
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Multimodal (text + image) request for vision explanation.
  Future<String?> explainImage({
    required Uint8List imageBytes,
    String mimeType = 'image/jpeg',
    String? prompt,
  }) async {
    if (imageBytes.isEmpty) {
      log('Error: Image bytes cannot be empty.');
      return null;
    }

    final textPrompt = (prompt == null || prompt.trim().isEmpty)
        ? defaultVisionPrompt
        : prompt.trim();

    try {
      final content = Content.multi([
        TextPart(textPrompt),
        InlineDataPart(mimeType, imageBytes),
      ]);

      final res = await _model.generateContent([content]);
      log('Vision response: ${res.text}');

      if (res.text == null || res.text!.isEmpty) {
        log('Error: Received empty vision response from the model.');
        return null;
      }

      return res.text!.trim();
    } catch (e, stackTrace) {
      log(
        'An error occurred in explainImage: ${e.toString()}',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  String cleanLLMJson(String raw) {
    return raw.replaceAll(RegExp(r'```json|```'), '').trim();
  }
}
