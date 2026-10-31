import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class GeminiFunctionCall {
  final String name;
  final Map<String, dynamic> args;
  final Map<String, dynamic> rawPart; // لحفظ thought_signature
  
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

  Future<GeminiResponse> sendMessage(String text) async {
    _history.add({
      'role': 'user',
      'parts': [{'text': text}]
    });
    return await _callApi();
  }

  Future<GeminiResponse> sendFunctionResults(List<Map<String, dynamic>> functionResponses, List<Map<String, dynamic>> originalFunctionCallParts) async {
    final parts = <Map<String, dynamic>>[];
    // 1. نرجع الـ functionCall الأصلي بالـ thought_signature بتاعه
    parts.addAll(originalFunctionCallParts);
    // 2. نضيف نتيجة الأداة
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
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 2048,
      },
      'systemInstruction': {
        'parts': [{'text': 'أنت BIMEX AI، مساعد ذكي. استخدم الأدوات المتاحة.'}]
      }
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

    // إضافة الرد الخام (بالـ thought_signature) للتاريخ
    _history.add(content);

    final parts = content['parts'] as List? ?? [];
    String? text;
    final functionCalls = <GeminiFunctionCall>[];

    for (final part in parts) {
      if (part.containsKey('text')) {
        text = part['text'];
      }
      if (part.containsKey('functionCall')) {
        final fc = part['functionCall'];
        functionCalls.add(GeminiFunctionCall(
          fc['name'],
          Map<String, dynamic>.from(fc['args'] ?? {}),
          Map<String, dynamic>.from(part), // نحفظ الـ part كامل
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
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'directory': {'type': 'STRING', 'description': 'مسار المجلد'}
            }
          }
        },
        {
          'name': 'read_file',
          'description': 'اقرأ محتوى ملف نصي',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'path': {'type': 'STRING', 'description': 'مسار الملف'}
            },
            'required': ['path']
          }
        },
        {
          'name': 'edit_file',
          'description': 'عدل أو اكتب محتوى في ملف',
          'parameters': {
            'type': 'OBJECT',
            'properties': {
              'path': {'type': 'STRING'},
              'content': {'type': 'STRING'}
            },
            'required': ['path', 'content']
          }
        },
        {
          'name': 'get_app_status',
          'description': 'اعرف حالة السيرفر الحالية',
          'parameters': {'type': 'OBJECT', 'properties': {}}
        },
      ]
    };
  }

  void reset() {
    _history.clear();
  }
}
