// lib/debugview_logger.dart
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

typedef _OutputDebugStringWC = ffi.Void Function(ffi.Pointer<Utf16>);
typedef _OutputDebugStringWDart = void Function(ffi.Pointer<Utf16>);

final _kernel32 = ffi.DynamicLibrary.open('kernel32.dll');
final _ods = _kernel32.lookupFunction<_OutputDebugStringWC, _OutputDebugStringWDart>(
  'OutputDebugStringW',
);

/// DebugView로 문자열을 출력합니다.
/// 권장: 1줄은 4KB 미만으로 (짤림 방지), 개행 포함.
void dv(String message) {
  final ptr = message.toNativeUtf16();
  _ods(ptr);
  calloc.free(ptr);
}
