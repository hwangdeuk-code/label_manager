import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'package:label_manager/utils/debugview_logger.dart';

import '../drivers/db_driver.dart';
import 'odbc_bindings.dart';
import 'odbc_error.dart';
import 'odbc_handles.dart';
import 'odbc_param_utils.dart';

class OdbcMssqlDriver implements DbDriver {
  OdbcMssqlDriver({void Function(String message)? logger}) : _logger = logger;

  OdbcEnvironment? _environment;
  OdbcConnection? _connection;
  bool _connected = false;
  final void Function(String message)? _logger;

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  }) async {
    if (!Platform.isWindows) {
      throw StateError('ODBC 드라이버는 Windows 환경에서만 동작합니다.');
    }
    return Future<bool>(() {
      _environment ??= OdbcEnvironment.allocate();
      _connection?.dispose();
      _connection = OdbcConnection.allocate(_environment!);
      final connStringCandidates = _buildConnectionStrings(
        ip: ip,
        port: port,
        databaseName: databaseName,
        username: username,
        password: password,
        timeoutInSeconds: timeoutInSeconds,
      );
      OdbcException? lastError;
      for (final connStr in connStringCandidates) {
        try {
          final masked = _maskConnectionString(connStr);
          _log('[OdbcMssqlDriver] connect try: $masked');
          _connection!.connect(connStr);
          _connected = true;
          return true;
        } on OdbcException catch (e) {
          final state = e.sqlState ?? 'unknown';
          _log('[OdbcMssqlDriver] connect failed ($state): ${e.message}');
          lastError = e;
        }
      }
      if (lastError != null) throw lastError;
      return false;
    });
  }

  @override
  Future<String> getData(String sql) => _execute(sql);

  @override
  Future<String> writeData(String sql) => _execute(sql);

  @override
  Future<String> getDataWithParams(String sql, Map<String, dynamic> params) =>
      _execute(sql, params: params);

  @override
  Future<String> writeDataWithParams(String sql, Map<String, dynamic> params) =>
      _execute(sql, params: params);

  @override
  Future<bool> disconnect() async {
    return Future<bool>(() {
      try {
        if (_connection != null && _connection!.isValid) {
          try {
            _connection!.disconnect();
          } catch (_) {}
          _connection!.dispose();
        }
        _environment?.dispose();
        _environment = null;
        _connected = false;
        return true;
      } finally {
        _connection = null;
      }
    });
  }

  Future<String> _execute(String sql, {Map<String, dynamic>? params}) async {
    if (!_connected || _connection == null || !_connection!.isValid) {
      throw StateError('ODBC 세션이 초기화되지 않았습니다. connect()를 먼저 호출하세요.');
    }
    return Future<String>(() {
      final stmt = OdbcStatement.allocate(_connection!);
      final bindings = OdbcBindings.instance;
      Pointer<Utf16>? sqlPtr;
      final paramBindings = <_BoundParameter>[];
      try {
        if (params == null || params.isEmpty) {
          _log('[OdbcMssqlDriver] sql: $sql');
          sqlPtr = sql.toNativeUtf16();
          final rc = bindings.sqlExecDirectW(
            stmt.handle,
            sqlPtr,
            OdbcConst.sqlNts,
          );
          if (!_isSuccess(rc)) {
            throw buildOdbcError(
              OdbcConst.sqlHandleStmt,
              stmt.handle,
              fallback: 'SQLExecDirectW failed: $rc',
            );
          }
        } else {
          final prepared = prepareStatement(sql, params);
          _log(
            '[OdbcMssqlDriver] sql: ${_formatSqlWithParams(prepared.sql, prepared.entries)}',
          );
          sqlPtr = prepared.sql.toNativeUtf16();
          final prepareRc = bindings.sqlPrepareW(
            stmt.handle,
            sqlPtr,
            OdbcConst.sqlNts,
          );
          if (!_isSuccess(prepareRc)) {
            throw buildOdbcError(
              OdbcConst.sqlHandleStmt,
              stmt.handle,
              fallback: 'SQLPrepareW failed: $prepareRc',
            );
          }
          for (var i = 0; i < prepared.entries.length; i++) {
            final entry = prepared.entries[i];
            final bound = _BoundParameter.fromValue(entry.value);
            paramBindings.add(bound);
            _bindParameter(stmt, position: i + 1, parameter: bound);
          }
          final execRc = bindings.sqlExecute(stmt.handle);
          if (!_isSuccess(execRc)) {
            throw buildOdbcError(
              OdbcConst.sqlHandleStmt,
              stmt.handle,
              fallback: 'SQLExecute failed: $execRc',
            );
          }
        }
        return _collectResults(stmt);
      } finally {
        for (final p in paramBindings) {
          p.dispose();
        }
        if (sqlPtr != null) calloc.free(sqlPtr);
        stmt.dispose();
      }
    });
  }

  void _bindParameter(
    OdbcStatement stmt, {
    required int position,
    required _BoundParameter parameter,
  }) {
    final bindings = OdbcBindings.instance;
    // _log(
    //   '[OdbcMssqlDriver] bind param pos=$position type=${parameter.parameterType} '
    //   'valueType=${parameter.valueType} size=${parameter.columnSize} '
    //   'buffer=${parameter.bufferLength} lenPtr=${parameter.lengthPtr.value}',
    // );
    final rc = bindings.sqlBindParameter(
      stmt.handle,
      position,
      OdbcConst.sqlParamInput,
      parameter.valueType,
      parameter.parameterType,
      parameter.columnSize,
      0,
      parameter.pointer.cast(),
      parameter.bufferLength,
      parameter.lengthPtr,
    );
    if (!_isSuccess(rc)) {
      throw buildOdbcError(
        OdbcConst.sqlHandleStmt,
        stmt.handle,
        fallback: 'SQLBindParameter failed: $rc (position=$position)',
      );
    }
  }

  bool _isSuccess(int rc) =>
      rc == OdbcConst.sqlSuccess || rc == OdbcConst.sqlSuccessWithInfo;

  String _collectResults(OdbcStatement stmt) {
    final bindings = OdbcBindings.instance;
    final rows = <Map<String, dynamic>>[];
    final columns = <String>[];
    final types = <int>[];
    var capturedSchema = false;
    var affected = 0;

    while (true) {
      final colCountPtr = calloc<Int16>();
      try {
        final rcNum = bindings.sqlNumResultCols(stmt.handle, colCountPtr);
        if (!_isSuccess(rcNum)) {
          throw buildOdbcError(
            OdbcConst.sqlHandleStmt,
            stmt.handle,
            fallback: 'SQLNumResultCols failed: $rcNum',
          );
        }
        final colCount = colCountPtr.value;
        if (colCount > 0 && !capturedSchema) {
          for (var col = 1; col <= colCount; col++) {
            columns.add(_describeColumn(stmt, col, types));
          }
          capturedSchema = true;
        }

        if (colCount > 0 && capturedSchema) {
          while (true) {
            final fetchRc = bindings.sqlFetch(stmt.handle);
            if (fetchRc == OdbcConst.sqlNoData) break;
            if (!_isSuccess(fetchRc)) {
              throw buildOdbcError(
                OdbcConst.sqlHandleStmt,
                stmt.handle,
                fallback: 'SQLFetch failed: $fetchRc',
              );
            }
            if (columns.isEmpty) continue;
            final row = <String, dynamic>{};
            for (var col = 1; col <= columns.length; col++) {
              final name = columns[col - 1];
              final type = types[col - 1];
              row[name] = _readCell(stmt, col, type);
            }
            rows.add(row);
          }
        } else if (colCount > 0) {
          while (true) {
            final fetchRc = bindings.sqlFetch(stmt.handle);
            if (fetchRc == OdbcConst.sqlNoData) break;
            if (!_isSuccess(fetchRc)) break;
          }
        }
      } finally {
        calloc.free(colCountPtr);
      }

      final countPtr = calloc<IntPtr>();
      try {
        final rcRowCount = bindings.sqlRowCount(stmt.handle, countPtr);
        if (_isSuccess(rcRowCount) && countPtr.value >= 0) {
          affected += countPtr.value;
        }
      } finally {
        calloc.free(countPtr);
      }

      final moreRc = bindings.sqlMoreResults(stmt.handle);
      if (moreRc == OdbcConst.sqlNoData) break;
      if (!_isSuccess(moreRc)) {
        throw buildOdbcError(
          OdbcConst.sqlHandleStmt,
          stmt.handle,
          fallback: 'SQLMoreResults failed: $moreRc',
        );
      }
    }

    final result = <String, dynamic>{
      'columns': columns,
      'rows': rows,
      'affected': affected,
    };
    return jsonEncode(result);
  }

  String _describeColumn(OdbcStatement stmt, int index, List<int> types) {
    final bindings = OdbcBindings.instance;
    var bufferLength = 6000;
    Pointer<Uint16>? rawBuffer;
    late Pointer<Utf16> nameBuffer;
    final nameLength = calloc<Int16>();
    final dataType = calloc<Int16>();
    final columnSize = calloc<IntPtr>();
    final decimalDigits = calloc<Int16>();
    final nullable = calloc<Int16>();
    try {
      while (true) {
        final buffer = calloc<Uint16>(bufferLength);
        rawBuffer = buffer;
        nameBuffer = buffer.cast<Utf16>();
        final rc = bindings.sqlDescribeColW(
          stmt.handle,
          index,
          nameBuffer,
          bufferLength,
          nameLength,
          dataType,
          columnSize,
          decimalDigits,
          nullable,
        );
        if (rc == OdbcConst.sqlSuccess) break;
        if (rc == OdbcConst.sqlSuccessWithInfo &&
            nameLength.value >= bufferLength - 1) {
          calloc.free(buffer);
          rawBuffer = null;
          bufferLength = nameLength.value + 1;
          continue;
        }
        throw buildOdbcError(
          OdbcConst.sqlHandleStmt,
          stmt.handle,
          fallback: 'SQLDescribeColW failed: $rc',
        );
      }
      var name = nameBuffer.toDartStringWithLength(nameLength.value);
      if (name.isEmpty) {
        name = _columnLabel(stmt, index);
      }
      if (name.isEmpty) {
        name = 'col$index';
      }
      types.add(dataType.value);
      return name;
    } finally {
      final remaining = rawBuffer;
      if (remaining != null) {
        calloc.free(remaining);
      }
      calloc.free(nameLength);
      calloc.free(dataType);
      calloc.free(columnSize);
      calloc.free(decimalDigits);
      calloc.free(nullable);
    }
  }

  dynamic _readCell(OdbcStatement stmt, int columnIndex, int sqlType) {
    final bindings = OdbcBindings.instance;
    final indicator = calloc<IntPtr>();
    try {
      final indicatorValue = () {
        bindings.sqlGetData(
          stmt.handle,
          columnIndex,
          _isBinaryType(sqlType) ? OdbcConst.sqlCBinary : OdbcConst.sqlCWChar,
          nullptr,
          0,
          indicator,
        );
        return indicator.value;
      }();
      if (indicatorValue == OdbcConst.sqlNullData) {
        return null;
      }
      const fallbackBytes = 262144;
      var requestedBytes = indicatorValue > 0 ? indicatorValue : 0;
      if (requestedBytes == 0 && indicatorValue < 0) {
        requestedBytes = fallbackBytes;
      }
      if (_isBinaryType(sqlType)) {
        final capacity = requestedBytes > 0 ? requestedBytes : fallbackBytes;
        final bytes = calloc<Uint8>(capacity);
        try {
          final rc = bindings.sqlGetData(
            stmt.handle,
            columnIndex,
            OdbcConst.sqlCBinary,
            bytes.cast(),
            capacity,
            indicator,
          );
          if (!_isSuccess(rc) && rc != OdbcConst.sqlNoData) {
            throw buildOdbcError(
              OdbcConst.sqlHandleStmt,
              stmt.handle,
              fallback: 'SQLGetData (binary) failed: $rc',
            );
          }
          final rawLength = indicator.value;
          final safeLength = rawLength <= 0
              ? 0
              : rawLength > capacity
                  ? capacity
                  : rawLength;
          final data = bytes.asTypedList(safeLength);
          return base64Encode(data);
        } finally {
          calloc.free(bytes);
        }
      } else {
        final capacity = requestedBytes > 0 ? requestedBytes : fallbackBytes;
        final adjustedCapacity = capacity > 0 ? capacity + 2 : fallbackBytes + 2;
        final evenCapacity =
            (adjustedCapacity & 1) == 0 ? adjustedCapacity : adjustedCapacity + 1;
        final charCount = evenCapacity ~/ 2;
        final raw = calloc<Uint16>(charCount > 0 ? charCount : 1);
        final buffer = raw.cast<Utf16>();
        try {
          final rc = bindings.sqlGetData(
            stmt.handle,
            columnIndex,
            OdbcConst.sqlCWChar,
            raw.cast(),
            evenCapacity,
            indicator,
          );
          if (!_isSuccess(rc) && rc != OdbcConst.sqlNoData) {
            throw buildOdbcError(
              OdbcConst.sqlHandleStmt,
              stmt.handle,
              fallback: 'SQLGetData failed: $rc',
            );
          }
          final lengthChars = indicator.value > 0 ? indicator.value ~/ 2 : 0;
          final value = buffer.toDartStringWithLength(lengthChars);
          return _convertValue(sqlType, value);
        } finally {
          calloc.free(raw);
        }
      }
    } finally {
      calloc.free(indicator);
    }
  }

  dynamic _convertValue(int sqlType, String value) {
    if (value.isEmpty) return '';
    if (_isNumericType(sqlType)) {
      return num.tryParse(value) ?? value;
    }
    if (_isBitType(sqlType)) {
      return value == '1';
    }
    return value;
  }

  bool _isBinaryType(int sqlType) {
    switch (sqlType) {
      case OdbcConst.sqlTypeBinary:
      case OdbcConst.sqlTypeVarbinary:
      case OdbcConst.sqlTypeLongvarbinary:
        return true;
    }
    return false;
  }

  bool _isNumericType(int sqlType) {
    switch (sqlType) {
      case OdbcConst.sqlTypeTinyint:
      case OdbcConst.sqlTypeSmallint:
      case OdbcConst.sqlTypeInteger:
      case OdbcConst.sqlTypeBigint:
      case OdbcConst.sqlTypeDecimal:
      case OdbcConst.sqlTypeNumeric:
      case OdbcConst.sqlTypeFloat:
      case OdbcConst.sqlTypeReal:
      case OdbcConst.sqlTypeDouble:
        return true;
    }
    return false;
  }

  bool _isBitType(int sqlType) => sqlType == OdbcConst.sqlTypeBit;

  String _columnLabel(OdbcStatement stmt, int index) {
    final bindings = OdbcBindings.instance;
    const bufferLength = 256;
    final raw = calloc<Uint16>(bufferLength);
    final label = raw.cast<Utf16>();
    final lengthPtr = calloc<Int16>();
    final numericPtr = calloc<IntPtr>();
    try {
      final rc = bindings.sqlColAttributeW(
        stmt.handle,
        index,
        OdbcConst.sqlDescLabel,
        label.cast(),
        bufferLength,
        lengthPtr,
        numericPtr,
      );
      if (rc == OdbcConst.sqlSuccess || rc == OdbcConst.sqlSuccessWithInfo) {
        final length = lengthPtr.value;
        if (length > 0) {
          return label.toDartStringWithLength(length);
        }
        return label.toDartString();
      }
    } catch (_) {
      // ignore attribute errors and fall back to describe result
    } finally {
      calloc.free(raw);
      calloc.free(lengthPtr);
      calloc.free(numericPtr);
    }
    return '';
  }

  String _formatSqlWithParams(
    String sql,
    List<OdbcParamEntry> entries,
  ) {
    if (entries.isEmpty) return sql;
    final parts = sql.split('?');
    final buffer = StringBuffer();
    final max = entries.length;
    for (var i = 0; i < max; i++) {
      buffer.write(parts[i]);
      buffer.write(_toSqlLiteral(entries[i].value));
    }
    if (parts.length > max) {
      buffer.write(parts.sublist(max).join('?'));
    }
    return buffer.toString();
  }

  String _toSqlLiteral(dynamic value) {
    if (value == null) return 'NULL';
    if (value is num) return value.toString();
    if (value is bool) return value ? '1' : '0';
    if (value is DateTime) {
      final escaped = value.toIso8601String().replaceAll("'", "''");
      return "'$escaped'";
    }
    if (value is Uint8List) {
      if (value.isEmpty) return '0x';
      final maxPreview = value.length > 32 ? 32 : value.length;
      final sb = StringBuffer('0x');
      for (var i = 0; i < maxPreview; i++) {
        sb.write(value[i].toRadixString(16).padLeft(2, '0'));
      }
      if (value.length > maxPreview) {
        sb.write('...');
      }
      return sb.toString();
    }
    if (value is Iterable) {
      final joined = value.map(_toSqlLiteral).join(', ');
      return '($joined)';
    }
    final text = value.toString().replaceAll("'", "''");
    return "'$text'";
  }

  void _log(String message) {
    if (_logger != null) {
      _logger!(message);
    }
    if (Platform.isWindows) {
      try {
        dv(message);
      } catch (_) {}
    }
    try {
      stdout.writeln(message);
    } catch (_) {}
    try {
      debugPrintSynchronously(message);
    } catch (_) {
      try {
        debugPrint(message);
      } catch (_) {}
    }
  }

  String _maskConnectionString(String connStr) {
    final parts = connStr.split(';');
    final masked = parts
        .map((segment) {
          final idx = segment.indexOf('=');
          if (idx <= 0) return segment;
          final key = segment.substring(0, idx).trim().toLowerCase();
          if (key == 'pwd' || key == 'password') {
            return '${segment.substring(0, idx + 1)}******';
          }
          return segment;
        })
        .where((segment) => segment.isNotEmpty)
        .join(';');
    return '$masked;';
  }

  List<String> _buildConnectionStrings({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    required int timeoutInSeconds,
  }) {
    final base =
        'Server=$ip,$port;Database=$databaseName;UID=$username;PWD=$password;Encrypt=No;Login Timeout=$timeoutInSeconds;';
    final drivers = <String>[
      '{ODBC Driver 18 for SQL Server}',
    ];
    return drivers.map((driver) => 'Driver=$driver;$base').toList();
  }
}

class _BoundParameter {
  static const int _defaultColumnSize = 4000;

  _BoundParameter._({
    required this.pointer,
    required this.lengthPtr,
    required this.bufferLength,
    required this.columnSize,
    required this.valueType,
    required this.parameterType,
  });

  final Pointer<Utf16> pointer;
  final Pointer<IntPtr> lengthPtr;
  final int bufferLength;
  final int columnSize;
  final int valueType;
  final int parameterType;

  factory _BoundParameter.fromText(String text) {
    final ptr = text.toNativeUtf16();
    final lenPtr = calloc<IntPtr>();
    final lengthChars = text.length;
    final bytes = (lengthChars + 1) * 2;
    lenPtr.value = lengthChars * 2;
    final columnSize = lengthChars > 0 ? lengthChars : 1;
    return _BoundParameter._(
      pointer: ptr,
      lengthPtr: lenPtr,
      bufferLength: bytes,
      columnSize: columnSize,
      valueType: OdbcConst.sqlCWChar,
      parameterType: OdbcConst.sqlTypeWvarchar,
    );
  }

  factory _BoundParameter.fromValue(dynamic value) {
    if (value == null) {
      final ptr = ''.toNativeUtf16();
      final lenPtr = calloc<IntPtr>()..value = OdbcConst.sqlNullData;
      return _BoundParameter._(
        pointer: ptr,
        lengthPtr: lenPtr,
        bufferLength: 0,
        columnSize: _defaultColumnSize,
        valueType: OdbcConst.sqlCWChar,
        parameterType: OdbcConst.sqlTypeWvarchar,
      );
    }
    if (value is bool) {
      final text = value ? '1' : '0';
      return _BoundParameter.fromText(text);
    }
    if (value is DateTime) {
      final text = value.toIso8601String();
      return _BoundParameter.fromText(text);
    }
    return _BoundParameter.fromText(value.toString());
  }

  void dispose() {
    calloc.free(pointer);
    calloc.free(lengthPtr);
  }
}



















