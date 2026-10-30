import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  final String _apiKey;

  // قائمة الموديلات (بالترتيب — يحاول الأول فالثاني...)
  static const _models = [
    'gemini-2.5-flash',       // الأحدث
    'gemini-2.0-flash',       // مستقر وسريع
    'gemini-2.0-flash-lite',  // أخف وأسرع
    'gemini-1.5-flash-latest',// احتياطي
    'gemini-1.5-pro-latest',  // احتياطي أبطأ
  ];

  ChatSession? _chat;
  String? _activeModelName;
  final List<Content> _history = [];

  static const _systemPrompt =
      'أنت مساعد ذكي داخل تطبيق HOST PANEL. '
      'تساعد المستخدم في إدارة السيرفر، أكواد Python، البوتات، أو أي استفسار تقني. '
      'أجب بالعربية الفصحى المبسطة وبأسلوب عملي ومختصر.';

  GeminiService({required String apiKey}) : _apiKey = apiKey;

  Future<String> sendMessage(String message) async {
    final content = Content.text(message);

    // 1) جرّب الموديل النشط (لو موجود)
    if (_chat != null) {
      try {
        final response = await _chat!
            .sendMessage(content)
            .timeout(const Duration(seconds: 30));
        final reply = response.text ?? 'لم أفهم طلبك.';
        _history.add(content);
        _history.add(Content.text(reply));
        return reply;
      } catch (_) {
        // الموديل الحالي فشل (ربما انتهت حصته أو تم إيقافه)
        _chat = null;
        _activeModelName = null;
      }
    }

    // 2) جرّب كل الموديلات بالترتيب
    final errors = <String>[];
    for (final modelName in _models) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
          systemInstruction: Content.system(_systemPrompt),
          generationConfig: GenerationConfig(
            temperature: 0.7,
            maxOutputTokens: 2048,
          ),
        );

        // استئناف المحادثة إن كان فيها تاريخ
        final chat = _history.isEmpty
            ? model.startChat()
            : model.startChat(history: _history);

        final response = await chat
            .sendMessage(content)
            .timeout(const Duration(seconds: 30));
        final reply = response.text ?? 'لم أفهم طلبك.';

        // حفظ الموديل النشط
        _chat = chat;
        _activeModelName = modelName;
        _history.add(content);
        _history.add(Content.text(reply));

        return reply;
      } catch (e) {
        final msg = e.toString().split('\n').first;
        errors.add('$modelName: $msg');
      }
    }

    // 3) كل الموديلات فشلت
    return '❌ تعذّر الاتصال بالمساعد.\n'
        'تحقق من الإنترنت وحاول مجدداً.\n\n'
        'تفاصيل: ${errors.take(2).join('\n')}';
  }

  void reset() {
    _history.clear();
    _chat = null;
    _activeModelName = null;
  }
}
