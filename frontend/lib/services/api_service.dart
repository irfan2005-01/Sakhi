import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/api_models.dart';

class ApiService {
  // Defaulting to http://127.0.0.1:8001 per hackathon MVP spec
  static const String defaultUrl = 'http://127.0.0.1:8001';

  static final ValueNotifier<String> baseUrlNotifier = ValueNotifier<String>(defaultUrl);

  String get baseUrl => baseUrlNotifier.value;

  set baseUrl(String newUrl) {
    if (newUrl.trim().isNotEmpty) {
      String trimmed = newUrl.trim();
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      baseUrlNotifier.value = trimmed;
    }
  }

  // Health Check
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {
        'status': 'error',
        'http_status': res.statusCode,
        'message': 'HTTP ${res.statusCode}: ${res.body}',
      };
    } catch (e) {
      return {
        'status': 'offline',
        'error': e.toString(),
        'url': baseUrl,
      };
    }
  }

  // Clinical Knowledge
  Future<List<KnowledgeReference>> getKnowledge([String? query]) async {
    try {
      String url = '$baseUrl/api/v1/knowledge';
      if (query != null && query.trim().isNotEmpty) {
        url += '?q=${Uri.encodeComponent(query.trim())}';
      }
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => KnowledgeReference.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching knowledge from $baseUrl: $e');
    }
    return [];
  }

  // Symptom Analysis Workflow
  Future<SymptomAnalysisResponse> analyzeSymptom({
    required String description,
    required String sessionId,
    String language = 'auto',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/symptoms/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': description,
          'session_id': sessionId,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return SymptomAnalysisResponse.fromJson(jsonDecode(res.body));
      } else {
        throw Exception('Server returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('Analyze symptom error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeVoice({
    required Uint8List audioBytes,
    required String filename,
    required String mimeType,
    required String sessionId,
    String language = 'auto',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/voice/analyze'),
    )
      ..fields['session_id'] = sessionId
      ..fields['language'] = language
      ..files.add(http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ));

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 75));
      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> payload = jsonDecode(response.body);
      if (response.statusCode == 200) return payload;
      throw Exception(payload['detail'] ?? 'Voice analysis failed (HTTP ${response.statusCode}).');
    } catch (e) {
      debugPrint('Voice analysis request failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> synthesizeSpeech({
    required String text,
    required String languageCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/voice/synthesize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'language_code': languageCode}),
      ).timeout(const Duration(seconds: 60));
      final Map<String, dynamic> payload = jsonDecode(response.body);
      if (response.statusCode == 200) return payload;
      throw Exception(payload['detail'] ?? 'Speech synthesis failed (HTTP ${response.statusCode}).');
    } catch (e) {
      debugPrint('Speech synthesis request failed: $e');
      rethrow;
    }
  }

  // Save Symptoms with explicit User Consent
  Future<bool> saveSymptomConsent({
    required String sessionId,
    required String originalDescription,
    required List<String> confirmedSymptoms,
    int? reportedCycleGapDays,
    String? durationAndContext,
    String? notes,
    required bool consentGiven,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/symptoms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'original_description': originalDescription,
        'confirmed_symptoms': confirmedSymptoms,
        'reported_cycle_gap_days': reportedCycleGapDays,
        'duration_and_context': durationAndContext,
        'notes': notes,
        'consent_given': consentGiven,
      }),
    ).timeout(const Duration(seconds: 8));

    return res.statusCode == 200;
  }

  // Symptom History
  Future<List<Map<String, dynamic>>> getSymptomHistory(String sessionId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/symptoms/history?session_id=${Uri.encodeComponent(sessionId)}'),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['records'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
    return [];
  }

  // Cycle Recording
  Future<bool> recordCycleStart({
    required String sessionId,
    required String periodStartDate,
    String flowIntensity = 'medium',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/cycles'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'period_start_date': periodStartDate,
        'flow_intensity': flowIntensity,
      }),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      return true;
    } else {
      final data = jsonDecode(res.body);
      throw Exception(data['detail'] ?? 'Failed to log cycle entry');
    }
  }

  // Cycle Analytics
  Future<CycleAnalyticsResult> getCycleAnalytics(String sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v1/cycles/analytics?session_id=${Uri.encodeComponent(sessionId)}'),
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode == 200) {
      return CycleAnalyticsResult.fromJson(jsonDecode(res.body));
    } else {
      throw Exception('Failed to load cycle analytics: HTTP ${res.statusCode}');
    }
  }

  // Generate PDF and return bytes
  Future<Uint8List> generateDoctorReportPdf({
    required String sessionId,
    List<String>? confirmedSymptoms,
    String? patientNotes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/reports/clinical-summary'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'confirmed_symptoms': confirmedSymptoms,
        'patient_notes': patientNotes,
      }),
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode == 200) {
      return res.bodyBytes;
    } else {
      throw Exception('Failed to generate report PDF: HTTP ${res.statusCode}');
    }
  }

  // Safety Audit Logs
  Future<List<Map<String, dynamic>>> getSafetyAuditLogs({int limit = 50}) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/safety/audit?limit=$limit'),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
    }
    return [];
  }

  // Open or download PDF in browser
  static Future<void> openOrDownloadPdf(Uint8List bytes, String filename) async {
    final base64String = base64Encode(bytes);
    final dataUri = Uri.parse('data:application/pdf;base64,$base64String');
    if (await canLaunchUrl(dataUri)) {
      await launchUrl(dataUri);
    }
  }

  // Open external web URL
  static Future<void> openWebUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
