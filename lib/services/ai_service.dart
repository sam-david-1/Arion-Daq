import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

class AiService {
  static const Duration _timeout = Duration(seconds: 20);

  // Preferred Groq models in order — but if none match, we use whatever is available
  static const List<String> _preferredGroqModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  ];

  // Gemini direct API models
  static const List<String> _geminiDirectModels = [
    'gemini-3.5-flash',
    'gemini-2.5-flash',
  ];

  // Gemini via OpenRouter
  static const List<String> _geminiOpenRouterModels = [
    'google/gemini-2.5-flash',
    'google/gemini-2.5-flash-lite',
  ];

  static bool _isGoogleKey(String key) => key.startsWith('AIza');
  static bool _isOpenRouterKey(String key) => key.startsWith('sk-or-');

  // ───────── MESSAGE BUILDERS ─────────

  static List<Map<String, dynamic>> _buildOpenAiMessages(
      String systemPrompt, List<Map> history, String userMessage) {
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

  static Map<String, dynamic> _buildGeminiDirectBody(
      String systemPrompt, List<Map> history, String userMessage) {
    final List<Map<String, dynamic>> contents = [];
    for (final m in history) {
      contents.add({
        'role': (m['role'] == 'ai' || m['role'] == 'assistant') ? 'model' : 'user',
        'parts': [{'text': m['content'] ?? ''}],
      });
    }
    contents.add({'role': 'user', 'parts': [{'text': userMessage}]});
    return {
      'system_instruction': {'parts': [{'text': systemPrompt}]},
      'contents': contents,
      'generationConfig': {'maxOutputTokens': 2048},
    };
  }

  static bool _isAuthError(int code) => code == 401 || code == 403;

  // ───────── GROQ (DYNAMIC MODEL DISCOVERY) ─────────

  /// Fetches the actual list of available model IDs from Groq's API.
  /// Returns preferred models first if they exist, then any other chat models.
  static Future<List<String>> _discoverGroqModels(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<dynamic> models = data['data'] ?? [];

      // Extract all model IDs
      final allIds = models
          .map((m) => m['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      debugPrint('Groq: discovered ${allIds.length} models: $allIds');

      // Build ordered list: preferred models first, then others
      final List<String> ordered = [];

      // Add preferred models that exist
      for (final pref in _preferredGroqModels) {
        if (allIds.contains(pref)) ordered.add(pref);
      }

      // Add any other models that look like chat models (not whisper, not guard, not embedding)
      for (final id in allIds) {
        if (!ordered.contains(id) &&
            !id.contains('whisper') &&
            !id.contains('guard') &&
            !id.contains('embed') &&
            !id.contains('tts') &&
            !id.contains('transcri')) {
          ordered.add(id);
        }
      }

      return ordered;
    } catch (e) {
      debugPrint('Groq model discovery failed: $e');
      return [];
    }
  }

  static Future<String> askGroq(String apiKey, String systemPrompt,
      List<Map> history, String userMessage) async {
    const apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
    final messages = _buildOpenAiMessages(systemPrompt, history, userMessage);

    // Dynamically discover available models
    final models = await _discoverGroqModels(apiKey);
    if (models.isEmpty) {
      return "Error: Groq API key is invalid or expired. Get a new key at console.groq.com";
    }

    debugPrint('Groq: will try models in order: $models');
    String lastError = '';

    for (final model in models) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          debugPrint('Groq: $model attempt ${attempt + 1}');
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

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['choices'] != null && data['choices'].isNotEmpty) {
              return data['choices'][0]['message']['content'] ??
                  'Empty response from Groq.';
            }
            lastError = 'Unexpected response';
            break;
          }

          if (_isAuthError(response.statusCode)) {
            return "Error: Groq auth failed (${response.statusCode}). Check API key.";
          }

          if (response.statusCode == 429 && attempt == 0) {
            debugPrint('Groq: rate limited on $model, waiting 6s...');
            lastError = 'Rate limited';
            await Future.delayed(const Duration(seconds: 6));
            continue;
          }

          if ((response.statusCode == 503 || response.statusCode == 502 ||
               response.statusCode == 500) && attempt == 0) {
            debugPrint('Groq: $model server error, retrying in 3s...');
            lastError = 'Server error ${response.statusCode}';
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }

          lastError = '$model: ${response.statusCode}';
          debugPrint('Groq: $lastError');
          break;
        } catch (e) {
          lastError = '$model: $e';
          debugPrint('Groq: $lastError');
          break;
        }
      }
    }
    return "Error: All Groq models failed ($lastError).";
  }

  // ───────── GEMINI DIRECT ─────────

  static Future<String> _askGeminiDirect(String apiKey, String systemPrompt,
      List<Map> history, String userMessage) async {
    final body = _buildGeminiDirectBody(systemPrompt, history, userMessage);
    String lastError = '';

    for (final model in _geminiDirectModels) {
      try {
        debugPrint('Gemini Direct: $model');
        final response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final parts = data['candidates'][0]['content']?['parts'];
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] ?? 'Empty response from Gemini.';
            }
          }
          lastError = 'Unexpected response';
          continue;
        }
        if (_isAuthError(response.statusCode)) {
          return "Error: Gemini auth failed (${response.statusCode}). Check API key.";
        }
        lastError = '$model: ${response.statusCode}';
        continue;
      } catch (e) {
        lastError = '$model: $e';
        continue;
      }
    }
    return "Error: Gemini direct failed ($lastError).";
  }

  // ───────── GEMINI OPENROUTER ─────────

  static Future<String> _askGeminiOpenRouter(String apiKey, String systemPrompt,
      List<Map> history, String userMessage) async {
    final messages = _buildOpenAiMessages(systemPrompt, history, userMessage);
    String lastError = '';

    for (final model in _geminiOpenRouterModels) {
      try {
        debugPrint('Gemini OpenRouter: $model');
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'model': model, 'max_tokens': 2048, 'messages': messages}),
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final content = data['choices'][0]['message']?['content'];
            if (content != null && content.toString().isNotEmpty) return content;
          }
          lastError = 'Unexpected response';
          continue;
        }
        if (_isAuthError(response.statusCode)) {
          return "Error: OpenRouter auth failed (${response.statusCode}). Check API key.";
        }
        lastError = '$model: ${response.statusCode}';
        continue;
      } catch (e) {
        lastError = '$model: $e';
        continue;
      }
    }
    return "Error: Gemini OpenRouter failed ($lastError).";
  }

  // ───────── GEMINI UNIFIED ─────────

  static Future<String> askGemini(String apiKey, String systemPrompt,
      List<Map> history, String userMessage) async {
    if (_isGoogleKey(apiKey)) {
      return _askGeminiDirect(apiKey, systemPrompt, history, userMessage);
    }
    if (_isOpenRouterKey(apiKey)) {
      return _askGeminiOpenRouter(apiKey, systemPrompt, history, userMessage);
    }
    // Unknown key — try OpenRouter first, then direct
    final orResult = await _askGeminiOpenRouter(apiKey, systemPrompt, history, userMessage);
    if (!orResult.startsWith('Error:')) return orResult;
    final directResult = await _askGeminiDirect(apiKey, systemPrompt, history, userMessage);
    if (!directResult.startsWith('Error:')) return directResult;
    return "Error: Gemini failed. OpenRouter: ${_strip(orResult)}, Direct: ${_strip(directResult)}";
  }

  // ───────── UNIFIED ENTRY POINT WITH FAILOVER ─────────

  static Future<String> ask(String providerOverride, String systemPrompt,
      List<Map> history, String userMessage) async {
    final settings = SettingsService();
    String provider = providerOverride.isNotEmpty ? providerOverride : settings.aiProvider;

    String finalSystemPrompt =
        "Act as a robotic, trackside pit-lane computer. Analyze data instantly. Never use filler text.\n\n$systemPrompt";

    // Try primary provider
    String result = await _callProvider(provider, settings, finalSystemPrompt, history, userMessage);
    if (!result.startsWith('Error:')) return result;

    // Failover to other provider
    final fallback = (provider == 'gemini') ? 'groq' : 'gemini';
    final hasKey = fallback == 'gemini'
        ? settings.geminiApiKey.isNotEmpty
        : settings.groqApiKey.isNotEmpty;

    if (hasKey) {
      debugPrint('AI Failover: $provider → $fallback');
      final fbResult = await _callProvider(fallback, settings, finalSystemPrompt, history, userMessage);
      if (!fbResult.startsWith('Error:')) return fbResult;

      return "Error: Both providers failed.\n"
          "• ${_label(provider)}: ${_strip(result)}\n"
          "• ${_label(fallback)}: ${_strip(fbResult)}";
    }
    return result;
  }

  static Future<String> _callProvider(String provider, SettingsService settings,
      String systemPrompt, List<Map> history, String userMessage) async {
    if (provider == 'gemini') {
      if (settings.geminiApiKey.isEmpty) return "Error: Gemini API key not set.";
      return askGemini(settings.geminiApiKey, systemPrompt, history, userMessage);
    } else {
      if (settings.groqApiKey.isEmpty) return "Error: Groq API key not set.";
      return askGroq(settings.groqApiKey, systemPrompt, history, userMessage);
    }
  }

  static String _label(String p) => p == 'gemini' ? 'Gemini' : 'Groq';
  static String _strip(String s) => s.startsWith('Error: ') ? s.substring(7) : s;
}
