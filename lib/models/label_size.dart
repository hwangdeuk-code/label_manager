// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/database/db_client.dart';
import 'dao.dart';
import 'date_manager.dart';

class LabelSizeCommon {
  final int width;
  final int height;
  final String rtf;

  const LabelSizeCommon({
    required this.width,
    required this.height,
    required this.rtf,
  });

  @override
  String toString() => 'Width: $width, Height: $height, RTF: $rtf';
}

class LabelSizeSetup {
	final bool readOnly;
	final bool useMakeDate;
	final bool useMakeTime;
	final bool useValidDate;
	final bool useValidTime;
	final PrintDateFormat makingDateFormat;
	final PrintTimeFormat makingTimeFormat;
	final PrintDateFormat validDateFormat;
	final PrintTimeFormat validTimeFormat;
	final String strMakeDate;
	final String strMakeTime;
	final String strValidDate;
	final String strValidTime;

	// 저울
	final bool useScale;

  const LabelSizeSetup({
    required this.readOnly,
    required this.useMakeDate,
    required this.useMakeTime,
    required this.useValidDate,
    required this.useValidTime,
    required this.makingDateFormat,
    required this.makingTimeFormat,
    required this.validDateFormat,
    required this.validTimeFormat,
    required this.strMakeDate,
    required this.strMakeTime,
    required this.strValidDate,
    required this.strValidTime,
    required this.useScale,
  });

  @override
  String toString() => 'ReadOnly: $readOnly, '
    'UseMakeDate: $useMakeDate, UseMakeTime: $useMakeTime, '
    'UseValidDate: $useValidDate, UseValidTime: $useValidTime, '
    'MakingDateFormat: $makingDateFormat, MakingTimeFormat: $makingTimeFormat, '
    'ValidDateFormat: $validDateFormat, ValidTimeFormat: $validTimeFormat, '
    'StrMakeDate: $strMakeDate, StrMakeTime: $strMakeTime, '
    'StrValidDate: $strValidDate, StrValidTime: $strValidTime, UseScale: $useScale';
}

class LabelSize {
  static const String cn = 'LabelSize';
  static List<LabelSize>? datas;

  final int labelSizeId;
  final int brandId;
  final String labelSizeName;
  final LabelSizeCommon? labelSizeCommon;
  final LabelSizeSetup? labelSizeSetup;

  const LabelSize({
    required this.labelSizeId,
    required this.brandId,
    required this.labelSizeName,
    this.labelSizeCommon,
    this.labelSizeSetup,
  });

  static void setDatas(List<LabelSize>? values) {
    datas = values;
  }

  factory LabelSize.fromMap(Map<String, dynamic> map) {
    String s(String key) => (map[key] ?? '').toString();
    int i(String key) => int.tryParse(s(key)) ?? 0;

    final labelSizeId = i('LABELSIZE_ID');
    final brandId = i('BRAND_ID');
    final labelSizeName = s('LABELSIZE_NAME');

    final labelSizeCommon = LabelSizeCommon(
      width: i('FORM_WIDTH'),
      height: i('FORM_HEIGHT'),
      rtf: s('FORM_DATA'),
    );  

    final labelSizeSetup = LabelSizeSetup(
      readOnly: i('SETUP_READONLY') != 0,
      useMakeDate: i('SETUP_USE_MAKEDATE') != 0,
      useMakeTime: i('SETUP_USE_MAKETIME') != 0,
      useValidDate: i('SETUP_USE_VALIDDATE') != 0,
      useValidTime: i('SETUP_USE_VALIDTIME') != 0,
      makingDateFormat: PrintDateFormat.values[i('SETUP_MAKEDATE_TYPE')],
      makingTimeFormat: PrintTimeFormat.values[i('SETUP_MAKETIME_TYPE')],
      validDateFormat: PrintDateFormat.values[i('SETUP_VALIDDATE_TYPE')],
      validTimeFormat: PrintTimeFormat.values[i('SETUP_VALIDTIME_TYPE')],
      strMakeDate: s('USER_MAKEDATE'),
      strMakeTime: s('USER_MAKETIME'),
      strValidDate: s('USER_VALIDDATE'),
      strValidTime: s('USER_VALIDTIME'),
      useScale: i('SETUP_USE_SCALE') != 0,
    );

    return LabelSize(
      labelSizeId: labelSizeId,
      brandId: brandId,
      labelSizeName: labelSizeName,
      labelSizeCommon: labelSizeCommon,
      labelSizeSetup: labelSizeSetup,
    );
  }

  static List<LabelSize> fromPipeLines(List<dynamic> rows) {
    final List<LabelSize> labelSize = [];
    for (var row in rows) {
      labelSize.add(LabelSize.fromMap(row as Map<String, dynamic>));
    }
    return labelSize;
  }

  @override
  String toString() =>
    'LabelSizeId: $labelSizeId, BrandId: $brandId, LabelSizeName: $labelSizeName';
}

class LabelSizeDAO extends DAO {
  static const String cn = 'LabelSizeDAO';

  static const String SelectSql = '''
    SELECT
      COALESCE(CONVERT(NVARCHAR(50), RICH_LABELSIZE_ID), N'') AS LABELSIZE_ID,
      COALESCE(CONVERT(NVARCHAR(50), RICH_BRAND_ID), N'') AS BRAND_ID,
      COALESCE(CONVERT(NVARCHAR(50), RICH_LABELSIZE_NAME COLLATE ${DAO.CP949}), N'') AS LABELSIZE_NAME,
      COALESCE(CONVERT(NVARCHAR(50), RICH_FORM_WIDTH), N'') AS FORM_WIDTH,
      COALESCE(CONVERT(NVARCHAR(50), RICH_FORM_HEIGHT), N'') AS FORM_HEIGHT,
      COALESCE(CONVERT(NVARCHAR(MAX), RICH_FORM_DATA COLLATE ${DAO.CP949}), N'') AS FORM_DATA,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_READONLY), N'') AS SETUP_READONLY,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_MAKEDATE), N'') AS SETUP_USE_MAKEDATE,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_MAKETIME), N'') AS SETUP_USE_MAKETIME,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_VALIDDATE), N'') AS SETUP_USE_VALIDDATE,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_VALIDTIME), N'') AS SETUP_USE_VALIDTIME,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_MAKEDATE_TYPE), N'') AS SETUP_MAKEDATE_TYPE,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_MAKETIME_TYPE), N'') AS SETUP_MAKETIME_TYPE,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_VALIDDATE_TYPE), N'') AS SETUP_VALIDDATE_TYPE,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_VALIDTIME_TYPE), N'') AS SETUP_VALIDTIME_TYPE,
      COALESCE(CONVERT(NVARCHAR(50), RICH_USER_MAKEDATE COLLATE ${DAO.CP949}), N'') AS USER_MAKEDATE,
      COALESCE(CONVERT(NVARCHAR(50), RICH_USER_MAKETIME COLLATE ${DAO.CP949}), N'') AS USER_MAKETIME,
      COALESCE(CONVERT(NVARCHAR(50), RICH_USER_VALIDDATE COLLATE ${DAO.CP949}), N'') AS USER_VALIDDATE,
      COALESCE(CONVERT(NVARCHAR(50), RICH_USER_VALIDTIME COLLATE ${DAO.CP949}), N'') AS USER_VALIDTIME,
      COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_SCALE), N'') AS SETUP_USE_SCALE
    FROM BM_RICH_LABELSIZE_FORM
  ''';

  // WHERE 절: Brand ID로 조회 (Integer)
  static const String WhereSqlBrandId = '''
	  WHERE RICH_BRAND_ID=@brandId
  ''';

  static const String OrderSqlByLabelSize = '''
	  ORDER BY RICH_LABELSIZE_ORDER ASC
  ''';

  static Future<List<LabelSize>?> getByBrandIdByLabelSizeOrder(int brandId) async {
    const fn = 'getByBrandIdByLabelSizeOrder';
    debugPrint('$cn.$fn: $START, brandId:$brandId');

    try {
      final res = await DbClient.instance.getDataWithParams(
        '$SelectSql $WhereSqlBrandId $OrderSqlByLabelSize',
        { 'brandId': brandId }
      );

      final rows = DAO.getRowsFromResult(res);
      final labelSizes = LabelSize.fromPipeLines(rows);

      debugPrint('$cn.$fn: $END');
      return labelSizes;
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
