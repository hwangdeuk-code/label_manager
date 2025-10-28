import 'dart:async';
import 'dart:convert';
import 'package:label_manager/database/db_client.dart';

/// MSSQL 연결 상태를 주기적으로 점검하는 간단한 모니터.
/// - 기본은 SELECT 1 핑으로 연결 끊김을 감지
/// - 실패/성공 전환 시 콜백 알림 및 스트림 이벤트 발행
class DbConnectionMonitor {
  final Duration interval;
  final Future<bool> Function()? customPing; // true면 정상, false면 실패
  final void Function()? onLost; // 정상 -> 끊김 전환 시 1회 호출
  final void Function()? onRestored; // 끊김 -> 정상 전환 시 1회 호출

  Timer? _timer;
  bool? _isUp;
  final StreamController<bool> _statusCtrl = StreamController<bool>.broadcast();
  bool _checking = false;
  bool _disposed = false;

  Stream<bool> get statusStream => _statusCtrl.stream; // true: up, false: down
  bool? get lastStatus => _isUp;

  DbConnectionMonitor({
    this.interval = const Duration(seconds: 30),
    this.customPing,
    this.onLost,
    this.onRestored,
  });

  void start({bool immediate = true}) {
    if (_disposed) return;
    _timer?.cancel();
    // 옵션에 따라 즉시 1회 점검 후 주기 시작
    if (immediate) {
      _check();
    }
    _timer = Timer.periodic(interval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_checking || _disposed) return; // ������ ����
    _checking = true;
    try {
      final ok = await _pingSafe();
      if (_disposed) return;

      if (_isUp == null) {
        _isUp = ok;
        _emitStatus(ok);
        return;
      }
      if (_isUp != ok) {
        _isUp = ok;
        _emitStatus(ok);
        if (ok) {
          onRestored?.call();
        } else {
          onLost?.call();
        }
      }
    } finally {
      _checking = false;
    }
  }

  Future<bool> _pingSafe() async {
    try {
      if (customPing != null) {
        return await customPing!();
      }
      // �⺻ ��: SELECT 1
      final s = await DbClient.instance.getData('SELECT 1');
      try {
        final j = jsonDecode(s);
        if (j is Map && j['error'] != null) return false;
        return true;
      } catch (_) {
        // ����ġ ���� ���� �����̸� �ϴ� �������� ����(��Ʈ��ũ������ ������ ���ܷ� �������� ��)
        return true;
      }
    } catch (_) {
      return false; // ���� = ���� ���з� �Ǵ�
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    stop();
    await _statusCtrl.close();
  }

  void _emitStatus(bool value) {
    if (_disposed) return;
    try {
      _statusCtrl.add(value);
    } on StateError {
      // controller already closed
    }
  }
}




