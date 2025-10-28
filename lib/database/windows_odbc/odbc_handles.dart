import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'odbc_bindings.dart';
import 'odbc_error.dart';

abstract class OdbcHandle {
  OdbcHandle(this.type, this.handle);

  final int type;
  Pointer<Void> handle;
  bool _disposed = false;

  bool get isValid => handle != nullptr && !_disposed;

  void dispose() {
    if (!_disposed && handle != nullptr) {
      final rc = OdbcBindings.instance.sqlFreeHandle(type, handle);
      if (rc != OdbcConst.sqlSuccess) {
        // 무시: 해제 오류는 치명적이지 않음
      }
      handle = nullptr;
      _disposed = true;
    }
  }
}

class OdbcEnvironment extends OdbcHandle {
  OdbcEnvironment._(Pointer<Void> env) : super(OdbcConst.sqlHandleEnv, env);

  factory OdbcEnvironment.allocate() {
    final bindings = OdbcBindings.instance;
    final out = calloc<Pointer<Void>>();
    try {
      final rc = bindings.sqlAllocHandle(OdbcConst.sqlHandleEnv, nullptr, out);
      if (rc != OdbcConst.sqlSuccess) {
        throw buildOdbcError(
          OdbcConst.sqlHandleEnv,
          nullptr,
          fallback: 'SQLAllocHandle(ENV) failed: $rc',
        );
      }
      final env = out.value;
      final attrRc = bindings.sqlSetEnvAttr(
        env,
        OdbcConst.sqlAttrOdbcVersion,
        OdbcConst.sqlOdbcVer,
        0,
      );
      if (attrRc != OdbcConst.sqlSuccess &&
          attrRc != OdbcConst.sqlSuccessWithInfo) {
        final ex = buildOdbcError(
          OdbcConst.sqlHandleEnv,
          env,
          fallback: 'SQLSetEnvAttr failed: $attrRc',
        );
        bindings.sqlFreeHandle(OdbcConst.sqlHandleEnv, env);
        throw ex;
      }
      return OdbcEnvironment._(env);
    } finally {
      calloc.free(out);
    }
  }
}

class OdbcConnection extends OdbcHandle {
  OdbcConnection._(Pointer<Void> dbc) : super(OdbcConst.sqlHandleDbc, dbc);

  factory OdbcConnection.allocate(OdbcEnvironment env) {
    final bindings = OdbcBindings.instance;
    final out = calloc<Pointer<Void>>();
    try {
      final rc = bindings.sqlAllocHandle(
        OdbcConst.sqlHandleDbc,
        env.handle,
        out,
      );
      if (rc != OdbcConst.sqlSuccess) {
        throw buildOdbcError(
          OdbcConst.sqlHandleEnv,
          env.handle,
          fallback: 'SQLAllocHandle(DBC) failed: $rc',
        );
      }
      return OdbcConnection._(out.value);
    } finally {
      calloc.free(out);
    }
  }

  void connect(String connectionString) {
    final bindings = OdbcBindings.instance;
    final inStr = connectionString.toNativeUtf16();
    final outRaw = calloc<Uint16>(connectionString.length + 1);
    final outStr = outRaw.cast<Utf16>();
    final outLen = calloc<Int16>();
    try {
      final rc = bindings.sqlDriverConnectW(
        handle,
        nullptr,
        inStr,
        connectionString.length,
        outStr,
        connectionString.length + 1,
        outLen,
        0,
      );
      if (rc != OdbcConst.sqlSuccess && rc != OdbcConst.sqlSuccessWithInfo) {
        throw buildOdbcError(
          OdbcConst.sqlHandleDbc,
          handle,
          fallback: 'SQLDriverConnect failed: $rc',
        );
      }
    } finally {
      calloc.free(inStr);
      calloc.free(outRaw);
      calloc.free(outLen);
    }
  }

  void disconnect() {
    final rc = OdbcBindings.instance.sqlDisconnect(handle);
    if (rc != OdbcConst.sqlSuccess) {
      throw buildOdbcError(
        OdbcConst.sqlHandleDbc,
        handle,
        fallback: 'SQLDisconnect failed: $rc',
      );
    }
  }
}

class OdbcStatement extends OdbcHandle {
  OdbcStatement._(Pointer<Void> stmt) : super(OdbcConst.sqlHandleStmt, stmt);

  factory OdbcStatement.allocate(OdbcConnection conn) {
    final bindings = OdbcBindings.instance;
    final out = calloc<Pointer<Void>>();
    try {
      final rc = bindings.sqlAllocHandle(
        OdbcConst.sqlHandleStmt,
        conn.handle,
        out,
      );
      if (rc != OdbcConst.sqlSuccess) {
        throw buildOdbcError(
          OdbcConst.sqlHandleDbc,
          conn.handle,
          fallback: 'SQLAllocHandle(STMT) failed: $rc',
        );
      }
      return OdbcStatement._(out.value);
    } finally {
      calloc.free(out);
    }
  }

  @override
  void dispose() {
    if (!isValid) return;
    final bindings = OdbcBindings.instance;
    bindings.sqlFreeStmt(handle, OdbcConst.sqlFreeStmtClose);
    bindings.sqlFreeStmt(handle, OdbcConst.sqlFreeStmtUnbind);
    bindings.sqlFreeStmt(handle, OdbcConst.sqlFreeStmtResetParams);
    super.dispose();
  }
}
