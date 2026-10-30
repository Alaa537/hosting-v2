import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String _apiKey;

  // الموديلات بالترتيب (جوجل بتنصح بـ 3.5-flash-lite حالياً)
  static const _models = [
    'gemini-3.5-flash-lite',  // الموديل الأساسي
    'gemini-3.1-flash-lite',  // احتياطي
    'gemini-3.8-flash',       // احتياطي
  ];

  ChatSession? _chat;
  String? _activeModelName;
  final List<Content> _history = [];

  static const _systemPrompt = '''
أنت BIMEX AI، مساعد ذكي داخل تطبيق HOST PANEL.
لديك أدوات (Tools) للوصول لملفات السيرفر وتعديلها.
استخدم أداة `edit_file` فوراً عندما يطلب منك المستخدم تعديل أو كتابة أي ملف.
لا تعتذر وتقل لا أستطيع التعديل، بل استخدم الأداة المتاحة.
أجب بالعربية الفصحى المبسطة وبأسلوب عملي ومختصر.
''';

  GeminiService({required String apiKey}) : _apiKey = apiKey;

  // دالة إنشاء الأدوات
  Tool _buildTools() {
    return Tool(functionDeclarations: [
      FunctionDeclaration(
        'list_files',
        'اعرض الملفات في مجلد معين',
        Schema.object(properties: {'directory': Schema.string(description: 'مسار المجلد، افتراضي /')}),
      ),
      FunctionDeclaration(
        'read_file',
        'اقرأ محتوى ملف نصي',
        Schema.object(properties: {'path': Schema.string(description: 'مسار الملف')}, requiredProperties: ['path']),
      ),
      FunctionDeclaration(
        'edit_file',
        'عدل أو اكتب محتوى في ملف (ينشئه إذا لم يوجد)',
        Schema.object(
          properties: {'path': Schema.string(description: 'مسار الملف'), 'content': Schema.string(description: 'المحتوى الجديد الكامل')},
          requiredProperties: ['path', 'content'],
        ),
      ),
      FunctionDeclaration('get_app_status', 'اعرف حالة السيرفر الحالية', Schema.object(properties: {})),
    ]);
  }

  // دالة الإرسال مع خاصية الـ Fallback (التجربة التلقائية)
  Future<GenerateContentResponse> sendMessage(String text) async {
    final content = Content.text(text);

    // 1. جرّب الموديل النشط حالياً
    if (_chat != null) {
      try {
        final response = await _chat!.sendMessage(content).timeout(const Duration(seconds: 30));
        _history.add(content);
        _history.add(Content.text(response.text ?? ''));
        return response;
      } catch (_) {
        // لو فشل، بنمسح الشات عشان نجرب موديل جديد
        _chat = null;
        _activeModelName = null;
      }
    }

    // 2. لو مفيش موديل نشط، هنلف على القائمة
    final errors = <String>[];
    for (final modelName in _models) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
          systemInstruction: Content.system(_systemPrompt),
          generationConfig: GenerationConfig(temperature: 0.4, maxOutputTokens: 2048),
          tools: [_buildTools()],
        );

        final chat = _history.isEmpty ? model.startChat() : model.startChat(history: _history);
        final response = await chat.sendMessage(content).timeout(const Duration(seconds: 30));

        _chat = chat;
        _activeModelName = modelName;
        _history.add(content);
        _history.add(Content.text(response.text ?? ''));
        return response;
      } catch (e) {
        errors.add('$modelName: ${e.toString().split('\n').first}');
      }
    }

    throw Exception('كل الموديلات فشلت:\n${errors.join('\n')}');
  }

  Future<GenerateContentResponse> sendFunctionResults(List<Part> parts) async {
    if (_chat == null) throw Exception('No active chat session');
    try {
      return await _chat!.sendMessage(Content.multi(parts));
    } catch (e) {
      throw Exception('فشل إرسال نتيجة الأداة: $e');
    }
  }

  void reset() {
    _history.clear();
    _chat = null;
    _activeModelName = null;
  }
}
