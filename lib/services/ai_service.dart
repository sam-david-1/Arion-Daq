import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

class AiService {
  static const Duration _timeout = Duration(seconds: 30);

  // GROQ — tries primary model, falls back to alternatives if decommissioned
  static const List<String> _groqModels = [
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  ];

  static List<Map<String, dynamic>> _buildMessages(String systemPrompt, List<Map> history, String userMessage) {
    final List<Map<String, dynamic>> messages = [
      {'role': 'system', 'content': systemPrompt}
    ];
    for (final m in history) {
      messages.add({
        'role': (m['role'] == 'ai' || m['role'] == 'assistant') ? 'assistant' : 'user',
        'content': m['content'] ?? '',
      });
    }
    messages.add({'role': 'user', 'content': userMessage});
    return messages;
  }

  static Future<String> askGroq(String apiKey, String systemPrompt, List<Map> history, String userMessage) async {
    const String apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
    
    final messages = _buildMessages(systemPrompt, history, userMessage);

    for (final model in _groqModels) {
      try {
        debugPrint('Groq: trying model $model...');
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 1024,
            'messages': messages,
          }),
        ).timeout(_timeout);

        debugPrint('Groq: model $model responded with ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            return data['choices'][0]['message']['content'] ?? 'Empty response from Groq.';
          }
          return "Error: Unexpected Groq response format.";
        } else if (response.statusCode == 404 || response.statusCode == 400) {
          // Model not found or decommissioned — try next model
          debugPrint('Groq model $model unavailable (${response.statusCode}), trying next...');
          continue;
        } else {
          // For other errors (401 auth, 429 rate limit, etc.), return immediately
          return "Error: Groq API Code ${response.statusCode} - ${response.body}";
        }
      } catch (e) {
        debugPrint('Groq model $model failed: $e');
        continue;
      }
    }
    return "Error: All Groq models unavailable. Check your API key or try Gemini.";
  }

  // GEMINI (via OpenRouter)
  static Future<String> askGemini(String apiKey, String systemPrompt, List<Map> history, String userMessage) async {
    const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
    
    try {
      final messages = _buildMessages(systemPrompt, history, userMessage);

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'google/gemini-2.5-flash',
          'max_tokens': 2048,
          'messages': messages,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
           return data['choices'][0]['message']['content'];
        }
        return "Error: Unexpected OpenRouter response format.";
      } else {
        return "Error: OpenRouter API Code ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: OpenRouter request failed - $e";
    }
  }

  // UNIFIED CALL
  static Future<String> ask(String providerOverride, String systemPrompt, List<Map> history, String userMessage) async {
    final settings = SettingsService();
    String provider = providerOverride.isNotEmpty ? providerOverride : settings.aiProvider;
    
    // Inject the No-Yap System Instruction explicitly
    String finalSystemPrompt = "Act as a robotic, trackside pit-lane computer. Analyze data instantly. Never use filler text.\n\n$systemPrompt";
    
    if (provider == 'gemini') {
      if (settings.geminiApiKey.isEmpty) return "Error: Gemini API key is not set.";
      return await askGemini(settings.geminiApiKey, finalSystemPrompt, history, userMessage);
    } else {
      if (settings.groqApiKey.isEmpty) return "Error: Groq API key is not set.";
      return await askGroq(settings.groqApiKey, finalSystemPrompt, history, userMessage);
    }
  }
}
