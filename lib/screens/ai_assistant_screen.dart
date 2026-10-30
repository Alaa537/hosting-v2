import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/gemini_service.dart';
import '../utils/constants.dart';
import '../utils/error_utils.dart';
import '../utils/formatters.dart';
import '../utils/api_key_manager.dart';
import '../widgets/dialogs.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});
  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [];
  
  GeminiService? _gemini;
  bool _isLoading = false;
  String? _initError;

  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    try {
      final key = ApiKeyManager.apiKey;
      if (key.isEmpty) throw Exception('API Key is empty');
      _gemini = GeminiService(apiKey: key);
    } catch (e) {
      _initError = e.toString();
    }
    _messages.add(_Message(
      text: 'مرحباً بك في BIMEX AI 🤖\n\n'
          'يمكنني الآن قراءة وتعديل ملفاتك مباشرة. جرب:\n'
          '• "اعرض لي ملفات المجلد الرئيسي"\n'
          '• "اقرأ ملف requirements.txt"\n'
          '• "عدل ملف requirements.txt وأضف requests"',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _gemini == null) return;

    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      var response = await _gemini!.sendMessage(text);

      while (response.functionCalls.isNotEmpty) {
        final parts = <Part>[];
        for (final call in response.functionCalls) {
          final result = await _executeFunction(call);
          parts.add(FunctionResponse(call.name, result));
        }
        response = await _gemini!.sendFunctionResults(parts);
      }

      final reply = response.text ?? 'لم أفهم طلبك.';
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(text: reply, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(text: '❌ خطأ: ${friendlyError(e)}', isUser: false));
        _isLoading = false;
      });
    }
  }

  Future<Map<String, Object?>> _executeFunction(FunctionCall call) async {
    final api = context.read<AuthProvider>().api!;
    try {
      switch (call.name) {
        case 'list_files':
          final dir = (call.args['directory'] as String?) ?? '/';
          final files = await api.listFiles(directory: dir);
          return {
            'count': files.length,
            'files': files.map((f) => '${f['name']} (${f['is_file'] ? fSize(f['size']) : 'مجلد'})').toList(),
          };
        case 'read_file':
          final path = call.args['path'] as String;
          final r = await api.readFileRaw(path);
          return {'path': path, 'content': r['content'] ?? ''};
        case 'edit_file':
          final path = call.args['path'] as String;
          final content = call.args['content'] as String;
          await api.writeFileRaw(path, content);
          return {'ok': true, 'path': path, 'bytes': content.length};
        case 'get_app_status':
          final st = await api.appStatus();
          return {'state': st.state, 'uptime': fTime(st.uptimeSeconds), 'has_app': st.app.exists};
        default:
          return {'error': 'unknown_function'};
      }
    } catch (e) {
      return {'error': friendlyError(e)};
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070710),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.primary, C.accent]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: C.primary.withValues(alpha: .4), blurRadius: 10)]),
              child: const Icon(Icons.auto_awesome, color: Colors.black, size: 16),
            ),
            const SizedBox(width: 12),
            const Text('BIMEX AI', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: _initError != null
          ? Center(child: Text(_initError!, style: const TextStyle(color: C.danger)))
          : Stack(
              children: [
                AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) {
                    final t = _bgCtrl.value * 2 * math.pi;
                    return Stack(children: [
                      _buildBlob(0.3 + 0.2 * math.cos(t), 0.2 + 0.1 * math.sin(t), 300, C.primary.withValues(alpha: .1)),
                      _buildBlob(0.7 + 0.2 * math.sin(t), 0.8 + 0.1 * math.cos(t), 280, C.accent.withValues(alpha: .1)),
                    ]);
                  },
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(child: _buildMessages()),
                      _buildInput(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBlob(double cx, double cy, double r, Color color) {
    return Positioned(
      left: MediaQuery.of(context).size.width * cx - r,
      top: MediaQuery.of(context).size.height * cy - r,
      child: Container(
        width: r * 2, height: r * 2,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: .05), Colors.transparent], stops: const [0, .5, 1])),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _messages.length && _isLoading) return _buildTyping();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(_Message msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.primary, C.accent]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.auto_awesome, color: Colors.black, size: 16)),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? C.primary.withValues(alpha: .15) : C.surface.withValues(alpha: .85),
                borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(isUser ? 20 : 4), bottomRight: Radius.circular(isUser ? 4 : 20)),
                border: Border.all(color: isUser ? C.primary.withValues(alpha: .4) : C.border),
              ),
              child: SelectableText(msg.text, style: TextStyle(color: isUser ? C.primary : Colors.white, fontSize: 14.5, height: 1.6)),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: C.surfaceHi, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)), child: const Icon(Icons.person, color: C.primary, size: 16)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: .1, end: 0);
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.primary, C.accent]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.auto_awesome, color: Colors.black, size: 16)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), decoration: BoxDecoration(color: C.surface.withValues(alpha: .85), borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(0), _dot(150), _dot(300)])),
        ],
      ),
    );
  }

  Widget _dot(int delay) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 8, height: 8, decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(begin: .6, end: 1.4, duration: 500.ms, delay: delay.ms);

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Color(0xFF0D0D1A), border: Border(top: BorderSide(color: C.border))),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.primary.withValues(alpha: .3))),
              child: TextField(
                controller: _controller,
                enabled: !_isLoading && _initError == null,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(hintText: 'اطلب من BIMEX AI قراءة أو تعديل ملف...', hintStyle: TextStyle(color: C.muted), isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.primary, C.accent]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.primary.withValues(alpha: .4), blurRadius: 12)]), child: IconButton(onPressed: _isLoading ? null : _send, icon: const Icon(Icons.send_rounded, color: Colors.black))),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}
