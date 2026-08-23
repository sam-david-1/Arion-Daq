import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

class AiService {
  static const Duration _timeout = Duration(seconds: 30);

  // GROQ
  static Future<String> askGroq(String apiKey, String systemPrompt, List<Map> history, String userMessage) async {
    const String apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
    
    try {
      final List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': systemPrompt}
      ];
      messages.addAll(history.map((m) => {
        'role': m['role'] == 'ai' || m['role'] == 'assistant' ? 'assistant' : 'user',
        'content': m['content'],
      }));
      messages.add({'role': 'user', 'content': userMessage});

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'max_tokens': 1024,
          'messages': messages,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return "Error: Groq API Code ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Error: Groq request failed - $e";
    }
  }

  // GEMINI (via OpenRouter)
  static Future<String> askGemini(String apiKey, String systemPrompt, List<Map> history, String userMessage) async {
    const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
    
    try {
      final List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': systemPrompt}
      ];
      messages.addAll(history.map((m) => {
        'role': m['role'] == 'ai' || m['role'] == 'assistant' ? 'assistant' : 'user',
        'content': m['content'],
      }));
      messages.add({'role': 'user', 'content': userMessage});

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
    String finalSystemPrompt = "Act as a robotic, trackside pit-lane computer. Analyze data instantly. Never use, filler text.\n\n$systemPrompt";
    
    if (provider == 'gemini') {
      if (settings.geminiApiKey.isEmpty) return "Error: Gemini API key is not set.";
      return await askGemini(settings.geminiApiKey, finalSystemPrompt, history, userMessage);
    } else {
      if (settings.groqApiKey.isEmpty) return "Error: Groq API key is not set.";
      return await askGroq(settings.groqApiKey, finalSystemPrompt, history, userMessage);
    }
  }
}
