import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/gemini_service.dart';
import '../utils/constants.dart';
import '../utils/error_utils.dart';
import '../utils/formatters.dart';
import '../utils/api_key_manager.dart';

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
      text: 'أهلاً بك في **BIMEX AI** 🤖\n\n'
          'مساعدك الشامل لإدارة السيرفر.\n\n'
          '**صلاحياتي:**\n'
          '📂 إدارة الملفات (قراءة/تعديل/حذف/بحث)\n'
          '🎮 التحكم بالبوت (تشغيل/إيقاف/إعادة/إيقاف قسري)\n'
          '📊 إحصائيات السيرفر (CPU/RAM/Disk)\n'
          '💻 إرسال أوامر للـ console\n'
          '📋 قراءة وتحليل الـ Live Logs\n\n'
          '**جرب:**\n'
          '• "جيبلي اللوج وحلل الأخطاء"\n'
          '• "شغّل البوت"\n'
          '• "اعرض لي إحصائيات السيرفر"',
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

  // 🔥 دالة سحب الـ Live Logs من WebSocket
  Future<String> _fetchLiveLogs() async {
    final api = context.read<AuthProvider>().api!;
    final wsBase = api.baseUrl.replaceFirst('http', 'ws');
    final url = '$wsBase/ws/events?token=${api.token}';
    final lines = <String>[];
    WebSocket? ws;

    try {
      ws = await WebSocket.connect(url).timeout(const Duration(seconds: 5));
      final completer = Completer<void>();
      final sub = ws.listen(
        (data) {
          try {
            final ev = jsonDecode(data);
            if (ev['type'] == 'log') {
              final line = (ev['data'] ?? '').toString().trimRight();
              if (line.isNotEmpty) lines.add(line);
              if (lines.length >= 50) completer.complete();
            }
          } catch (_) {}
        },
        onDone: () { if (!completer.isCompleted) completer.complete(); },
        onError: (_) { if (!completer.isCompleted) completer.complete(); },
      );
      // ننتظر 3 ثواني كحد أقصى لجمع اللوج
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 3)),
      ]);
      await sub.cancel();
    } catch (_) {
    } finally {
      try { await ws?.close(); } catch (_) {}
    }

    if (lines.isEmpty) return "⚠️ لم يتم التقاط أي سجلات (اللوج فاضي أو السيرفر مش شغال).";
    return lines.join('\n');
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
      // 🔥 لو السؤال فيه "لوج" أو "logs"، نجمع اللوج ونبعته للـ AI
      final lower = text.toLowerCase();
      final wantsLogs = lower.contains('لوج') || lower.contains('log') || lower.contains('سجل') || lower.contains('logs');
      String messageToAI = text;

      if (wantsLogs) {
        final logs = await _fetchLiveLogs();
        messageToAI = "$text\n\n--- Live Logs ---\n$logs\n--- End of Logs ---";
      }

      var response = await _gemini!.sendMessage(messageToAI);

      while (response.functionCalls.isNotEmpty) {
        final functionResponses = <Map<String, dynamic>>[];
        final originalFunctionCalls = <Map<String, dynamic>>[];
        for (final call in response.functionCalls) {
          originalFunctionCalls.add(call.rawPart);
          final result = await _executeFunction(call);
          functionResponses.add({
            'functionResponse': {'name': call.name, 'response': result}
          });
        }
        response = await _gemini!.sendFunctionResults(functionResponses, originalFunctionCalls);
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

  Future<Map<String, dynamic>> _executeFunction(GeminiFunctionCall call) async {
    final api = context.read<AuthProvider>().api!;
    try {
      switch (call.name) {
        // ============ FILE OPERATIONS ============
        case 'list_files':
          final dir = (call.args['directory'] as String?) ?? '/';
          final files = await api.listFiles(directory: dir);
          return {
            'count': files.length,
            'files': files.map((f) => {
              'name': f['name'],
              'is_file': f['is_file'],
              'size': f['is_file'] ? fSize(f['size']) : 'folder',
            }).toList(),
          };

        case 'read_file':
          final path = call.args['path'] as String;
          final r = await api.readFileRaw(path);
          return {'path': path, 'content': r['content'] ?? '', 'bytes': (r['content'] as String? ?? '').length};

        case 'edit_file':
          final path = call.args['path'] as String;
          final content = call.args['content'] as String;
          await api.writeFileRaw(path, content);
          return {'ok': true, 'path': path, 'bytes': content.length,
                  'note': 'يجب إعادة تشغيل البوت لتطبيق التغييرات'};

        case 'delete_files':
          final raw = call.args['paths'];
          final paths = (raw is List) ? raw.map((e) => e.toString()).toList() : <String>[];
          if (paths.isEmpty) return {'error': 'no paths provided'};
          // حذف كل ملف من جذر / (إذا كان المسار كاملاً)
          for (final p in paths) {
            final slash = p.lastIndexOf('/');
            final dir = slash > 0 ? p.substring(0, slash) : '/';
            final name = slash >= 0 ? p.substring(slash + 1) : p;
            await api.deleteFiles(dir, [name]);
          }
          return {'ok': true, 'deleted': paths};

        case 'search_files':
          final query = call.args['query'] as String;
          final dir = (call.args['directory'] as String?) ?? '/';
          final r = await api.searchFiles(query, directory: dir);
          return {
            'query': query,
            'count': (r['results'] as List? ?? []).length,
            'results': (r['results'] as List? ?? [])
                .map((x) => x['path']).toList(),
          };

        // ============ BOT CONTROL ============
        case 'get_app_status':
          final st = await api.appStatus();
          return {
            'state': st.state,
            'name': st.name,
            'uptime': fTime(st.uptimeSeconds),
            'has_app': st.app.exists,
            'has_requirements': st.app.requirements,
          };

        case 'start_bot':
          await api.appStart();
          return {'ok': true, 'action': 'start', 'state': 'starting'};

        case 'stop_bot':
          await api.appStop();
          return {'ok': true, 'action': 'stop', 'state': 'stopping'};

        case 'restart_bot':
          await api.appRestart();
          return {'ok': true, 'action': 'restart', 'state': 'restarting'};

        case 'kill_bot':
          await api.appKill();
          return {'ok': true, 'action': 'kill', 'state': 'killed'};

        // ============ CONSOLE & STATS ============
        case 'send_command':
          final cmd = call.args['command'] as String;
          await api.appCommand(cmd);
          return {'ok': true, 'command': cmd};

        case 'get_server_stats':
          final r = await api.serverResources();
          return {
            'state': r.state,
            'name': r.name,
            'cpu_percent': r.cpu,
            'memory_used': fSize(r.memUsed),
            'memory_limit': fSize(r.memLimit),
            'memory_percent': r.memPercent,
            'disk_used': fSize(r.diskUsed),
            'disk_limit': fSize(r.diskLimit),
            'disk_percent': r.diskPercent,
            'network_rx': fSize(r.netRx),
            'network_tx': fSize(r.netTx),
            'uptime': fTime(r.uptimeSeconds),
          };

        default:
          return {'error': 'unknown_function: ${call.name}'};
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
            const Text('BIMEX AI', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
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
                boxShadow: isUser ? [] : [BoxShadow(color: Colors.black.withValues(alpha: .2), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: isUser
                  ? SelectableText(msg.text, style: const TextStyle(color: C.primary, fontSize: 14.5, height: 1.6, fontWeight: FontWeight.w600))
                  : MarkdownBody(
                      data: msg.text,
                      selectable: true,
                      onTapLink: (text, url, title) async {
                        if (url != null) {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.6),
                        h1: const TextStyle(color: C.primary, fontSize: 20, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: C.primary, fontSize: 18, fontWeight: FontWeight.bold),
                        a: const TextStyle(color: C.accent, decoration: TextDecoration.underline),
                        code: const TextStyle(backgroundColor: Colors.transparent, color: Colors.white, fontFamily: 'monospace'),
                        codeblockDecoration: BoxDecoration(color: const Color(0xFF1A1A24), borderRadius: BorderRadius.circular(8)),
                        blockquoteDecoration: BoxDecoration(color: C.surfaceHi, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: C.primary, width: 4))),
                      ),
                      builders: {'code': _CodeElementBuilder()},
                    ),
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
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: C.primary.withValues(alpha: .3)),
                boxShadow: [BoxShadow(color: C.primary.withValues(alpha: .05), blurRadius: 10)],
              ),
              child: TextField(
                controller: _controller,
                enabled: !_isLoading && _initError == null,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 14.5, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'اسأل BIMEX AI أي شيء...',
                  hintStyle: TextStyle(color: C.muted, fontSize: 13),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.primary, C.accent]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: C.primary.withValues(alpha: .4), blurRadius: 12)],
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _send,
              icon: const Icon(Icons.send_rounded, color: Colors.black),
            ),
          ),
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

class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final lang = element.attributes['class']?.replaceFirst('language-', '') ?? 'dart';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang.toUpperCase(), style: const TextStyle(color: C.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                _CopyCodeButton(code: code),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              code,
              language: lang,
              theme: monokaiSublimeTheme,
              padding: const EdgeInsets.all(12),
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyCodeButton extends StatelessWidget {
  final String code;
  const _CopyCodeButton({required this.code});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ الكود'), duration: Duration(seconds: 1)),
        );
      },
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.copy, color: C.muted, size: 14),
          SizedBox(width: 4),
          Text('نسخ', style: TextStyle(color: C.muted, fontSize: 10)),
        ],
      ),
    );
  }
}

