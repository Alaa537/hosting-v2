import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiFunctionCall {
  final String name;
  final Map<String, dynamic> args;
  final Map<String, dynamic> rawPart;
  GeminiFunctionCall(this.name, this.args, this.rawPart);
}

class GeminiResponse {
  final String? text;
  final List<GeminiFunctionCall> functionCalls;
  final Map<String, dynamic> rawContent;
  GeminiResponse(this.text, this.functionCalls, this.rawContent);
}

class GeminiService {
  final String _apiKey;
  final String _model = 'gemini-3.5-flash-lite';
  final List<Map<String, dynamic>> _history = [];

  GeminiService({required String apiKey}) : _apiKey = apiKey;

  static const _systemPrompt = '''
أنت BIMEX AI، مساعد ذكي داخل تطبيق HOST PANEL.
مطورك هو "علاء رفيق" (Alaa Rafeek).
إذا سألك أحد عن مطورك، قل إن المطور هو "علاء رفيق"، وضع له رابط التليجرام الخاص به: https://t.me/AR_Bou ورابط قناة التليجرام: https://t.me/ahrgq.
لديك أدوات (Tools) للوصول لملفات السيرفر وتعديلها. استخدم أداة `edit_file` عندما يطلب منك المستخدم تعديل ملف.
أجب باللغة العربية بأسلوب احترافي ومختصر.
إذا كتبت كود برمجي، ضعه دائماً بين علامات الماركداون (```).
''';

  Future<GeminiResponse> sendMessage(String text) async {
    _history.add({
      'role': 'user',
      'parts': [{'text': text}]
    });
    return await _callApi();
  }

  Future<GeminiResponse> sendFunctionResults(List<Map<String, dynamic>> functionResponses, List<Map<String, dynamic>> originalFunctionCallParts) async {
    final parts = <Map<String, dynamic>>[];
    parts.addAll(originalFunctionCallParts);
    parts.addAll(functionResponses);
    _history.add({
      'role': 'user',
      'parts': parts
    });
    return await _callApi();
  }

  Future<GeminiResponse> _callApi() async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey'\;
    final body = {
      'contents': _history,
      'tools': [_buildTools()],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 2048},
      'systemInstruction': {'parts': [{'text': _systemPrompt}]}
    };

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('API error (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
      throw Exception('No candidates returned');
    }

    final candidate = data['candidates'][0];
    final content = candidate['content'];
    if (content == null) throw Exception('No content in response');

    _history.add(content);

    final parts = content['parts'] as List? ?? [];
    String? text;
    final functionCalls = <GeminiFunctionCall>[];

    for (final part in parts) {
      if (part.containsKey('text')) text = part['text'];
      if (part.containsKey('functionCall')) {
        final fc = part['functionCall'];
        functionCalls.add(GeminiFunctionCall(
          fc['name'],
          Map<String, dynamic>.from(fc['args'] ?? {}),
          Map<String, dynamic>.from(part),
        ));
      }
    }
    return GeminiResponse(text, functionCalls, Map<String, dynamic>.from(content));
  }

  Map<String, dynamic> _buildTools() {
    return {
      'functionDeclarations': [
        {
          'name': 'list_files',
          'description': 'اعرض الملفات في مجلد معين',
          'parameters': {'type': 'OBJECT', 'properties': {'directory': {'type': 'STRING', 'description': 'مسار المجلد'}}}
        },
        {
          'name': 'read_file',
          'description': 'اقرأ محتوى ملف نصي',
          'parameters': {'type': 'OBJECT', 'properties': {'path': {'type': 'STRING', 'description': 'مسار الملف'}}, 'required': ['path']}
        },
        {
          'name': 'edit_file',
          'description': 'عدل أو اكتب محتوى في ملف',
          'parameters': {'type': 'OBJECT', 'properties': {'path': {'type': 'STRING'}, 'content': {'type': 'STRING'}}, 'required': ['path', 'content']}
        },
        {
          'name': 'get_app_status',
          'description': 'اعرف حالة السيرفر الحالية',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },
      ]
    };
  }

  void reset() => _history.clear();
}
