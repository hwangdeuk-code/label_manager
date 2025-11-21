import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef _OutputDebugStringNative = Void Function(Pointer<Utf16>);
typedef _OutputDebugStringDart = void Function(Pointer<Utf16>);

class DebugLogger {
  DebugLogger._();

  static bool _initialized = false;
  static _OutputDebugStringDart? _outputDebugString;
  static IOSink? _sink;
  static void Function(String? message, {int? wrapWidth})? _originalDebugPrint;

  static void outputDebugString(String message) {
    final ptr = message.toNativeUtf16();
    try {
      _outputDebugString?.call(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    _originalDebugPrint = debugPrint;
    _outputDebugString = _loadOutputDebugString();
    await _initApplogAndDebugPrint();
  }

  static _OutputDebugStringDart? _loadOutputDebugString() {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      final lib = DynamicLibrary.open('kernel32.dll');
      return lib.lookupFunction<_OutputDebugStringNative, _OutputDebugStringDart>('OutputDebugStringW');
    } catch (e) {
      _originalDebugPrint?.call('DebugLogger: failed to load OutputDebugStringW -> $e');
      return null;
    }
  }

  static Future<void> _initApplogAndDebugPrint() async {
    try {
      final baseDir = await getApplicationSupportDirectory();
      final logDir = Directory(p.join(baseDir.path, 'log'));

      if (!await logDir.exists()) await logDir.create(recursive: true);
      await _deleteOldLogs(logDir);

      final now = DateTime.now();
      final stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      final logPath = p.join(logDir.path, 'app_$stamp.log');
      final logFile = File(logPath);

      _sink = logFile.openWrite(mode: FileMode.append);
      _originalDebugPrint?.call('LogPath: $logPath');

      debugPrint = (String? message, {int? wrapWidth}) {
        final safeMessage = message ?? '';
        final prefixed = '[LM] $safeMessage';

        if (Platform.isWindows && _outputDebugString != null) {
          final nativeStr = prefixed.toNativeUtf16();
          try {
            _outputDebugString!(nativeStr);
          } finally {
            calloc.free(nativeStr);
          }
        }

        _originalDebugPrint?.call(prefixed, wrapWidth: wrapWidth);
        _sink?.writeln('${DateTime.now().toIso8601String()} $safeMessage');
      };

      FlutterError.onError = (FlutterErrorDetails d) {
        debugPrint('FlutterError: ${d.exceptionAsString()}');
        if (d.stack != null) debugPrint(d.stack.toString());
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught: $error');
        debugPrint(stack.toString());
        return true;
      };
    } catch (e) {
      _originalDebugPrint?.call('DebugLogger: initialization failed -> $e');
    }
  }

  static Future<void> _deleteOldLogs(Directory logDir) async {
    try {
      final now = DateTime.now();
      final oneMonthAgo = now.subtract(const Duration(days: 30));
      final logFileEntities = logDir.listSync();

      for (final entity in logFileEntities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('app_') && fileName.endsWith('.log')) {
            try {
              final match = RegExp(r'^app_(\d{4}-\d{2}-\d{2})(?:_(\d{2}-\d{2}-\d{2}))?\.log$').firstMatch(fileName);
              if (match != null) {
                final datePart = match.group(1)!;
                final timePart = match.group(2);
                final dateTimeString = timePart != null ? '${datePart}_$timePart' : datePart;
                final formatter = DateFormat(timePart != null ? 'yyyy-MM-dd_HH-mm-ss' : 'yyyy-MM-dd');
                final fileDate = formatter.parse(dateTimeString);

                if (fileDate.isBefore(oneMonthAgo)) {
                  await entity.delete();
                  _originalDebugPrint?.call('Deleted old log file: ${entity.path}');
                }
              } else {
                _originalDebugPrint?.call('Could not parse log file name: ${entity.path}');
              }
            } catch (e) {
              _originalDebugPrint?.call('Could not process log file ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      _originalDebugPrint?.call('Failed to delete old logs: $e');
    }
  }
}
