import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late final GenerativeModel _model;
  late final ChatSession _chat;

  GeminiService({required String apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'أنت مساعد ذكي داخل تطبيق HOST PANEL. '
        'تساعد المستخدم في إدارة السيرفر، أكواد Python، البوتات، أو أي استفسار تقني. '
        'أجب بالعربية الفصحى المبسطة وبأسلوب عملي ومختصر.',
      ),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
    );
    _chat = _model.startChat();
  }

  Future<String> sendMessage(String message) async {
    try {
      final response = await _chat.sendMessage(Content.text(message));
      return response.text ?? 'لم أفهم طلبك.';
    } catch (e) {
      return '⚠️ خطأ في الاتصال بالمساعد: ${e.toString().split('\n').first}';
    }
  }

  void reset() {
    _chat = _model.startChat();
  }
}
