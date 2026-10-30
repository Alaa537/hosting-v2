import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String _apiKey;

  static const _models = [
    'gemini-2.5-flash-lite',  // أفضل دعم للأدوات حالياً
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
  ];

  late final GenerativeModel _model;
  late final ChatSession _chat;

  static const _systemPrompt = '''
أنت BIMEX AI، مساعد ذكي داخل تطبيق HOST PANEL.
لديك أدوات (Tools) للوصول لملفات السيرفر وتعديلها.
استخدم أداة `edit_file` فوراً عندما يطلب منك المستخدم تعديل أو كتابة أي ملف.
لا تعتذر وتقل لا أستطيع التعديل، بل استخدم الأداة المتاحة.
أجب بالعربية الفصحى المبسطة وبأسلوب عملي ومختصر.
''';

  GeminiService({required String apiKey}) : _apiKey = apiKey {
    _model = GenerativeModel(
      model: _models.first,
      apiKey: _apiKey,
      systemInstruction: Content.system(_systemPrompt),
      // تعطيل التفكير لحل مشكلة thought_signature
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 2048,
      ),
      tools: [_buildTools()],
    );
    _chat = _model.startChat();
  }

  Tool _buildTools() {
    return Tool(functionDeclarations: [
      FunctionDeclaration(
        'list_files',
        'اعرض الملفات في مجلد معين',
        Schema.object(properties: {
          'directory': Schema.string(description: 'مسار المجلد، افتراضي /'),
        }),
      ),
      FunctionDeclaration(
        'read_file',
        'اقرأ محتوى ملف نصي',
        Schema.object(
          properties: {
            'path': Schema.string(description: 'مسار الملف'),
          },
          requiredProperties: ['path'],
        ),
      ),
      FunctionDeclaration(
        'edit_file',
        'عدل أو اكتب محتوى في ملف (ينشئه إذا لم يوجد)',
        Schema.object(
          properties: {
            'path': Schema.string(description: 'مسار الملف'),
            'content': Schema.string(description: 'المحتوى الجديد الكامل'),
          },
          requiredProperties: ['path', 'content'],
        ),
      ),
      FunctionDeclaration(
        'get_app_status',
        'اعرف حالة السيرفر والبوت الحالية (يعمل / متوقف)',
        Schema.object(properties: {}),
      ),
    ]);
  }

  Future<GenerateContentResponse> sendMessage(String text) async {
    return await _chat.sendMessage(Content.text(text));
  }

  Future<GenerateContentResponse> sendFunctionResults(List<Part> parts) async {
    return await _chat.sendMessage(Content.multi(parts));
  }

  void reset() {
    _chat = _model.startChat();
  }
}
