import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'odbc_bindings.dart';

class OdbcException implements Exception {
  OdbcException(this.message, {this.sqlState, this.nativeCode});

  final String message;
  final String? sqlState;
  final int? nativeCode;

  @override
  String toString() =>
      'OdbcException(message: $message, state: $sqlState, native: $nativeCode)';
}

/// 지정 핸들의 진단 메시지를 수집한다.
OdbcException buildOdbcError(int handleType, Pointer<Void> handle,
    {String? fallback}) {
  final bindings = OdbcBindings.instance;
  final rawState = calloc<Uint16>(6);
  final sqlState = rawState.cast<Utf16>();
  final nativeError = calloc<Int32>();
  final rawMessage =
      calloc<Uint16>(OdbcConst.sqlMaxMessageLength);
  final messageBuffer = rawMessage.cast<Utf16>();
  final textLength = calloc<Int16>();
  try {
    final rc = bindings.sqlGetDiagRecW(
      handleType,
      handle,
      1,
      sqlState,
      nativeError,
      messageBuffer,
      OdbcConst.sqlMaxMessageLength,
      textLength,
    );
    if (rc == OdbcConst.sqlSuccess || rc == OdbcConst.sqlSuccessWithInfo) {
      final msg = messageBuffer
          .toDartStringWithLength(textLength.value >= 0 ? textLength.value : 0);
      final state =
          sqlState.toDartStringWithLength(5); // 5 chars + null terminator
      return OdbcException(
        msg.isEmpty ? (fallback ?? 'ODBC error') : msg,
        sqlState: state,
        nativeCode: nativeError.value,
      );
    }
    return OdbcException(fallback ?? 'ODBC error');
  } finally {
    calloc.free(rawState);
    calloc.free(nativeError);
    calloc.free(rawMessage);
    calloc.free(textLength);
  }
}
