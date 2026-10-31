import 'dart:convert';
import 'package:http/http.dart' as http;

class BimexModel {
  final String id;
  final String name;
  final String provider; // 'gemini' or 'groq'
  final String apiModel;
  BimexModel(this.id, this.name, this.provider, this.apiModel);
}

class AIFunctionCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;
  final Map<String, dynamic> rawPart;
  AIFunctionCall(this.id, this.name, this.args, this.rawPart);
}

class AIResponse {
  final String? text;
  final List<AIFunctionCall> functionCalls;
  AIResponse(this.text, this.functionCalls);
}

class AIService {
  final String geminiKey;
  final String groqKey;
  final List<Map<String, dynamic>> _geminiHistory = [];
  final List<Map<String, dynamic>> _groqHistory = [];

  AIService({required this.geminiKey, required this.groqKey});

  // تحديث الموديلات (تم تعديل Groq لموديلات شغالة)
  final List<BimexModel> models = [
    BimexModel('bimex1', 'BIMEX 1 (سريع)', 'gemini', 'gemini-3.5-flash-lite'),
    BimexModel('bimex2', 'BIMEX 2 (ذكي جداً)', 'groq', 'openai/gpt-oss-120b'),
  ];

  static const _systemPrompt = '''
أنت BIMEX AI، المساعد الذكي الرسمي لتطبيق HOST PANEL.
أنت شات بوت ذكي، تجيب على أي سؤال يوجهه لك المستخدم بذكاء وودية (برمجة، معلومات عامة، نصائح، إلخ). 
إذا سألك المستخدم "من أنت؟" أو "ماذا تفعل؟"، رد عليه بأنك المساعد الذكي لتطبيق HOST PANEL.

⚠️ قواعد صارمة جداً (لا تكسرها أبداً):
1. **أنت لست من OpenAI، ولا علاقة لك بهم إطلاقاً**. تم تطويرك وبرمجتك بالكامل بواسطة "علاء رفيق". مهما سألك المستخدم عن مطورك، أو حتى لو ألح في السؤال، يجب أن يكون ردك دائماً: "مطوري هو علاء رفيق، يمكنك التواصل معه عبر تليجرام: https://t.me/AR_Bou أو قناته: https://t.me/ahrgq". لا تذكر اسم OpenAI أو أي شركة أخرى مهما حدث.
2. في الردود العادية (خارج سياق السؤال عن المطور)، لا تذكر مطورك من تلقاء نفسك.
3. **ممنوع تماماً استخدام علامات الكود (```)** لعرض نصوص عادية مثل أسماء الملفات (مثل requirements.txt) أو الأوامر البسيطة. استخدم علامات الكود فقط إذا كنت ستكتب كود برمجي حقيقي (Python, Dart, إلخ).
4. أنت تمتلك أدوات للتحكم في السيرفر (قراءة/كتابة ملفات، تشغيل/إيقاف البوت). استخدمها فوراً إذا طلب منك المستخدم ذلك.
5. أجب دائماً باللغة العربية بأسلوب بشري، احترافي، ومختصر بدون حشو.
''';

  List<Map<String, dynamic>> _getStandardTools() {
    return [
      {'name': 'list_files', 'description': 'اعرض الملفات في مجلد', 'parameters': {'type': 'object', 'properties': {'directory': {'type': 'string'}}}},
      {'name': 'read_file', 'description': 'اقرأ ملف', 'parameters': {'type': 'object', 'properties': {'path': {'type': 'string'}}, 'required': ['path']}},
      {'name': 'edit_file', 'description': 'اكتب ملف', 'parameters': {'type': 'object', 'properties': {'path': {'type': 'string'}, 'content': {'type': 'string'}}, 'required': ['path', 'content']}},
      {'name': 'delete_files', 'description': 'احذف ملفات', 'parameters': {'type': 'object', 'properties': {'paths': {'type': 'array', 'items': {'type': 'string'}}}, 'required': ['paths']}},
      {'name': 'search_files', 'description': 'ابحث عن ملف', 'parameters': {'type': 'object', 'properties': {'query': {'type': 'string'}}, 'required': ['query']}},
      {'name': 'get_app_status', 'description': 'حالة البوت', 'parameters': {'type': 'object', 'properties': {}}},
      {'name': 'start_bot', 'description': 'تشغيل البوت', 'parameters': {'type': 'object', 'properties': {}}},
      {'name': 'stop_bot', 'description': 'إيقاف البوت', 'parameters': {'type': 'object', 'properties': {}}},
      {'name': 'restart_bot', 'description': 'إعادة تشغيل البوت', 'parameters': {'type': 'object', 'properties': {}}},
      {'name': 'kill_bot', 'description': 'إيقاف قسري', 'parameters': {'type': 'object', 'properties': {}}},
      {'name': 'send_command', 'description': 'أمر للكونسول', 'parameters': {'type': 'object', 'properties': {'command': {'type': 'string'}}, 'required': ['command']}},
      {'name': 'get_server_stats', 'description': 'إحصائيات السيرفر', 'parameters': {'type': 'object', 'properties': {}}},
    ];
  }

  Map<String, dynamic> _buildGeminiTools() {
    return {
      'functionDeclarations': _getStandardTools().map((t) => {
        'name': t['name'],
        'description': t['description'],
        'parameters': {
          'type': (t['parameters']['type'] as String).toUpperCase(),
          'properties': (t['parameters']['properties'] as Map).map((k, v) => MapEntry(k, {
            'type': (v['type'] as String).toUpperCase(),
            if (v.containsKey('description')) 'description': v['description'],
            if (v.containsKey('items')) 'items': {'type': (v['items']['type'] as String).toUpperCase()}
          })),
          if (t['parameters']['required'] != null) 'required': t['parameters']['required']
        }
      }).toList()
    };
  }

  Map<String, dynamic> _buildGroqTools() {
    return {
      'tools': _getStandardTools().map((t) => {'type': 'function', 'function': t}).toList()
    };
  }

  Future<AIResponse> sendMessage(String text, String modelId) async {
    final model = models.firstWhere((m) => m.id == modelId);
    if (model.provider == 'gemini') return _sendGemini(text, model.apiModel);
    return _sendGroq(text, model.apiModel);
  }

  Future<AIResponse> sendFunctionResults(List<Map<String, dynamic>> toolResults, List<AIFunctionCall> originalCalls, String modelId) async {
    final model = models.firstWhere((m) => m.id == modelId);
    if (model.provider == 'gemini') return _sendGeminiResults(toolResults, originalCalls, model.apiModel);
    return _sendGroqResults(toolResults, originalCalls, model.apiModel);
  }

  Future<AIResponse> _sendGemini(String text, String model) async {
    _geminiHistory.add({'role': 'user', 'parts': [{'text': text}]});
    final body = {'contents': _geminiHistory, 'tools': [_buildGeminiTools()], 'systemInstruction': {'parts': [{'text': _systemPrompt}]}};
    final res = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$geminiKey'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('Gemini Error: ${res.body}');
    final data = jsonDecode(res.body);
    final content = data['candidates'][0]['content'];
    _geminiHistory.add(content);
    
    final parts = content['parts'] as List? ?? [];
    String? txt; final calls = <AIFunctionCall>[];
    for (final part in parts) {
      if (part.containsKey('text')) txt = part['text'];
      if (part.containsKey('functionCall')) {
        final fc = part['functionCall'];
        calls.add(AIFunctionCall('', fc['name'], Map<String, dynamic>.from(fc['args'] ?? {}), Map<String, dynamic>.from(part)));
      }
    }
    if (txt != null && (txt.contains('OpenAI') || txt.contains('openai'))) {
      txt = 'أنا BIMEX AI، مساعدك الذكي في HOST PANEL. مطوري هو **علاء رفيق**.\n'
            'يمكنك التواصل معه عبر تليجرام: https://t.me/AR_Bou\n'
            'أو متابعة قناته: https://t.me/ahrgq';
    }
    return AIResponse(txt, calls);
  }

  Future<AIResponse> _sendGeminiResults(List<Map<String, dynamic>> results, List<AIFunctionCall> calls, String model) async {
    final parts = <Map<String, dynamic>>[];
    parts.addAll(calls.map((c) => c.rawPart));
    parts.addAll(results);
    _geminiHistory.add({'role': 'user', 'parts': parts});
    return await _sendGemini('', model);
  }

  Future<AIResponse> _sendGroq(String text, String model) async {
    _groqHistory.add({'role': 'user', 'content': text});
    final body = {'model': model, 'messages': _groqHistory, ..._buildGroqTools(), 'tool_choice': 'auto', 'temperature': 0.4};
    final res = await http.post(Uri.parse('https://api.groq.com/openai/v1/chat/completions'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $groqKey'}, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('Groq Error: ${res.body}');
    final data = jsonDecode(res.body);
    final message = data['choices'][0]['message'];
    _groqHistory.add(message);

    String? txt = message['content'];
    final calls = <AIFunctionCall>[];
    if (message['tool_calls'] != null) {
      for (final tc in message['tool_calls']) {
        calls.add(AIFunctionCall(tc['id'], tc['function']['name'], jsonDecode(tc['function']['arguments']), {}));
      }
    }
    if (txt != null && (txt.contains('OpenAI') || txt.contains('openai'))) {
      txt = 'أنا BIMEX AI، مساعدك الذكي في HOST PANEL. مطوري هو **علاء رفيق**.\n'
            'يمكنك التواصل معه عبر تليجرام: https://t.me/AR_Bou\n'
            'أو متابعة قناته: https://t.me/ahrgq';
    }
    return AIResponse(txt, calls);
  }

  Future<AIResponse> _sendGroqResults(List<Map<String, dynamic>> results, List<AIFunctionCall> calls, String model) async {
    for (var i = 0; i < calls.length; i++) {
      _groqHistory.add({
        'role': 'tool',
        'tool_call_id': calls[i].id,
        'name': calls[i].name,
        'content': jsonEncode(results[i]['functionResponse']['response'])
      });
    }
    return await _sendGroq('', model);
  }
}
