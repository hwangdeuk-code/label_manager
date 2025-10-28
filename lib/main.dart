import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app.dart';
import 'core/bootstrap.dart';
import 'core/lifecycle.dart';
import 'database/db_reconnect_overlay.dart';
import 'package:intl/intl.dart';
import 'package:label_manager/utils/debugview_logger.dart';
import 'home_page.dart';

typedef DebugPrintCallback = void Function(String? message, {int? wrapWidth});
DebugPrintCallback gDebugPrint = debugPrint;
IOSink? gSink;

Future<void> main(List<String> args) async {
  // Widgets 초기화는 모든 플랫폼 공통으로 필요하다.
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 시작 시 라이프사이클 옵저버를 1회 등록
  LifecycleManager.instance.ensureInitialized();

  // 한국어 로케일용 날짜/시간 포맷터 초기화
  await initializeDateFormatting('ko_KR');

  // 데스크톱 환경에서는 지정한 디스플레이로 이동 후 최대화.
  if (Platform.isWindows || Platform.isMacOS) {
    //final requestedDisplay = resolveDisplayIndex(args);
    await initDesktopWindow(targetIndex: 0); //requestedDisplay ?? 0);
    
    // 창 닫기(X) 시 우리 정리 로직을 먼저 수행할 수 있도록 보장
    await windowManager.setPreventClose(true);
    windowManager.addListener(_AppWindowListener());

    isDesktop = true;
  }

  // 앱 정보를 조회해 전역에 보관한다.
  final info = await PackageInfo.fromPlatform();
  appPackageName = info.packageName;
  appVersion = info.version;

	// 로그 파일 및 debugPrint 초기화
	await initApplogAndDebugPrint();

  // 공통 StartUp 페이지를 표시한다.
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => DbReconnectOverlay(child: child),
      home: const HomePage(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    ),
  );
}

// 로그 파일 처리 및 debugPrint 재정의
Future<void> initApplogAndDebugPrint() async {
  final dir = await getApplicationSupportDirectory();
  await _deleteOldLogs(dir); // 오래된 로그 삭제 함수 호출

  // 오늘 날짜로 로그 파일을 열거나 생성 (예: app_2023-10-27.log)
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final logPath = p.join(dir.path, 'app_$today.log');
  final logFile = File(logPath);
  gSink = logFile.openWrite(mode: FileMode.append); // 덮어쓰지 않고 이어쓰기
  gDebugPrint = debugPrint;
  gDebugPrint('LogPath: $logPath');

  // debugPrint를 파일로도 복사
  debugPrint = (String? message, {int? wrapWidth}) {
    final prefixed = '[LM] $message'; // 필터용 접두어
		if (Platform.isWindows) dv(prefixed);
    gDebugPrint(prefixed, wrapWidth: wrapWidth);
    gSink!.writeln('${DateTime.now().toIso8601String()} $message');
  };

	// Flutter 프레임워크 에러
  FlutterError.onError = (FlutterErrorDetails d) {
    debugPrint('FlutterError: ${d.exceptionAsString()}');
    if (d.stack != null) debugPrint(d.stack.toString());
  };

  // Zone 밖/Isolate 경계 에러
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error');
    debugPrint(stack.toString());
    return true; // 처리됨
  };
}

// 1개월 이전 로그 파일 삭제
Future<void> _deleteOldLogs(Directory logDir) async {
  try {
    final now = DateTime.now();
    // 1개월(30일) 이전 시점 계산
    final oneMonthAgo = now.subtract(const Duration(days: 30));
    
    // 로그 디렉토리의 파일 목록을 동기적으로 가져옴
    final logFileEntities = logDir.listSync();

    for (final entity in logFileEntities) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        // 'app_'로 시작하고 '.log'로 끝나는 파일 이름 필터링
        if (fileName.startsWith('app_') && fileName.endsWith('.log')) {
          try {
            // 파일 이름에서 날짜 부분 추출 (예: app_2023-10-27.log)
            final dateString = fileName.substring(4, 14);
            final fileDate = DateFormat('yyyy-MM-dd').parse(dateString);
            
            // 파일 날짜가 1개월 이전이면 삭제
            if (fileDate.isBefore(oneMonthAgo)) {
              await entity.delete();
              // 삭제 사실을 로그로 남기려 하지만, 이 시점엔 아직 로그 파일이 열리지 않았을 수 있으므로 gDebugPrint 사용
              gDebugPrint('Deleted old log file: ${entity.path}');
            }
          } catch (e) {
            // 날짜 파싱 실패 등 예외 발생 시 로그 기록
            gDebugPrint('Could not process log file ${entity.path}: $e');
          }
        }
      }
    }
  } catch (e) {
    // 디렉토리 접근 등에서 예외 발생 시 로그 기록
    gDebugPrint('Failed to delete old logs: $e');
  }
}

class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    final isPrevent = await windowManager.isPreventClose();
    if (isPrevent) {
      // 앱 전역 종료 요청 브로드캐스트(비동기 정리 작업이 있다면 여기서 시작)
      LifecycleManager.instance.notifyExitRequested();
      // 짧은 딜레이로 즉시 종료로 인한 정리 누락을 완화(필요시 조정)
      await Future.delayed(const Duration(milliseconds: 120));
      await windowManager.destroy();
    }
  }
}
