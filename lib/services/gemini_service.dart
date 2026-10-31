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
أنت BIMEX AI، مساعد ذكي متقدم داخل تطبيق HOST PANEL.
مطورك هو "علاء رفيق" (Alaa Rafeef).
إذا سُئلت عن مطورك، قل "علاء رفيق" وضع هذه الروابط:
- Telegram: https://t.me/AR_Bou
- Channel: https://t.me/ahrgq

لديك 12 أداة لإدارة السيرفر بالكامل:
- قراءة/كتابة/حذف/بحث الملفات
- تشغيل/إيقاف/إعادة تشغيل/إيقاف قسري للبوت
- إرسال أوامر للـ console
- قراءة حالة السيرفر والإحصائيات

قواعدك:
1. استخدم الأدوات فوراً عندما يطلب المستخدم أي عملية.
2. قبل عمليات الحذف أو الإيقاف القسري (kill)، اشرح للمستخدم ماذا ستفعل.
3. إذا لاحظت خطأ في اللوج، اقرأ الملف ذي الصلة، حلل الخطأ، ثم عدل الملف.
4. بعد تعديل ملف، اطلب من المستخدم إعادة التشغيل.
5. أجب بالعربية بأسلوب احترافي ومختصر.
6. ضع أي كود بين علامات ``` (code blocks).
''';

  Future<GeminiResponse> sendMessage(String text) async {
    _history.add({'role': 'user', 'parts': [{'text': text}]});
    return await _callApi();
  }

  Future<GeminiResponse> sendFunctionResults(
      List<Map<String, dynamic>> functionResponses,
      List<Map<String, dynamic>> originalFunctionCallParts) async {
    final parts = <Map<String, dynamic>>[];
    parts.addAll(originalFunctionCallParts);
    parts.addAll(functionResponses);
    _history.add({'role': 'user', 'parts': parts});
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
    ).timeout(const Duration(seconds: 60));

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
        // ============ FILE OPERATIONS ============
        {
          'name': 'list_files',
          'description': 'اعرض الملفات والمجلدات في مسار معين',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'directory': {'type': 'STRING', 'description': 'المسار، افتراضي /'}
            }
          }
        },
        {
          'name': 'read_file',
          'description': 'اقرأ محتوى ملف نصي كامل',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'path': {'type': 'STRING', 'description': 'المسار الكامل للملف'}
            },
            'required': ['path']
          }
        },
        {
          'name': 'edit_file',
          'description': 'عدل أو اكتب محتوى كامل في ملف',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'path': {'type': 'STRING'},
              'content': {'type': 'STRING', 'description': 'المحتوى الجديد الكامل'}
            },
            'required': ['path', 'content']
          }
        },
        {
          'name': 'delete_files',
          'description': 'احذف ملف أو عدة ملفات',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'paths': {
                'type': 'ARRAY',
                'items': {'type': 'STRING'},
                'description': 'قائمة بمسارات الملفات'
              }
            },
            'required': ['paths']
          }
        },
        {
          'name': 'search_files',
          'description': 'ابحث عن ملف بالاسم في مجلد',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'query': {'type': 'STRING', 'description': 'نص البحث'},
              'directory': {'type': 'STRING', 'description': 'المجلد، افتراضي /'}
            },
            'required': ['query']
          }
        },

        // ============ BOT CONTROL ============
        {
          'name': 'get_app_status',
          'description': 'اعرف حالة البوت (يعمل/متوقف/انهار) + وقت التشغيل',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },
        {
          'name': 'start_bot',
          'description': 'شغّل البوت (app.py)',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },
        {
          'name': 'stop_bot',
          'description': 'أوقف البوت بشكل آمن',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },
        {
          'name': 'restart_bot',
          'description': 'أعد تشغيل البوت',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },
        {
          'name': 'kill_bot',
          'description': 'إيقاف قسري فوري للبوت (Kill) - استخدمه فقط لو البوت علق',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },

        // ============ CONSOLE & STATS ============
        {
          'name': 'send_command',
          'description': 'أرسل أمر للـ console الخاص بالبوت (مثل: print, input)',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'command': {'type': 'STRING', 'description': 'الأمر'}
            },
            'required': ['command']
          }
        },
        {
          'name': 'get_server_stats',
          'description': 'اعرف إحصائيات السيرفر: CPU, RAM, Disk, Network, Uptime',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },
      ]
    };
  }

  void reset() => _history.clear();
}
