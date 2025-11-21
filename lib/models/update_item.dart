// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/database/db_client.dart';
import 'dao.dart';

class UpdateItem {
  static List<UpdateItem>? datas;

	final int updateItemId;
	final int itemId;
	final String itemName;
	final int labelSizeId;
	final String element;
	final String elementRTF;
	final int price;
	final DateTime applyDate;
  final bool isApply;

  const UpdateItem({
    required this.updateItemId,
    required this.itemId,
    required this.itemName,
    required this.labelSizeId,
    required this.element,
    required this.elementRTF,
    required this.price,
    required this.applyDate,
    required this.isApply,
  });

  static void setDatas(List<UpdateItem>? values) {
    datas = values;
  }

  factory UpdateItem.fromMap(Map<String, dynamic> map) {
    String s(String key) => (map[key] ?? '').toString();
    int i(String key) => int.tryParse(s(key)) ?? 0;

    return UpdateItem(
      updateItemId: i('UPDATE_ITEM_ID'),
      itemId:       i('ITEM_ID'),
      itemName:     s('ITEM_NAME'),
      labelSizeId:  i('LABEL_SIZE_ID'),
      element:      s('ELEMENT'),
      elementRTF:   s('ELEMENT_RTF'),
      price:        i('PRICE'),
      applyDate:    DateTime.tryParse(s('APPLY_DATE')) ?? DateTime.now(),
      isApply:      true
    );
  }

  static List<UpdateItem> fromPipeLines(List<dynamic> rows) {
    final List<UpdateItem> updateItems = [];
    for (var row in rows) {
      updateItems.add(UpdateItem.fromMap(row as Map<String, dynamic>));
    }
    return updateItems;
  }

  @override
  String toString() =>
    'UpdateItemId: $updateItemId, ItemId: $itemId, ItemName: $itemName, LabelSizeId: $labelSizeId, Element: $element, ElementRTF: $elementRTF, Price: $price, ApplyDate: $applyDate, IsApply: $isApply';
}

class UpdateItemDAO extends DAO {
  static const String cn = 'UpdateItemDAO';

  static const String SelectSql = '''
    SELECT
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_UPDATE_ITEM_ID), N'') AS UPDATE_ITEM_ID,
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_ITEM_ID), N'') AS ITEM_ID,
      COALESCE(CONVERT(NVARCHAR(100), P2.RICH_ITEM_NAME, COLLATE ${DAO.CP949}), N'') AS ITEM_NAME,
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_LABELSIZE_ID), N'') AS LABEL_SIZE_ID,
      COALESCE(CONVERT(NVARCHAR(MAX), P1.RICH_ELEMENT, COLLATE ${DAO.CP949}), N'') AS ELEMENT,
      COALESCE(CONVERT(NVARCHAR(MAX), P1.RICH_ELEMENT_RTF, COLLATE ${DAO.CP949}), N'') AS ELEMENT_RTF,
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_PRICE), N'') AS PRICE,
      COALESCE(CONVERT(NVARCHAR(8), P1.RICH_APPLY_DATE, 112), N'') AS APPLY_DATE,
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_IS_APPLY), N'') AS IS_APPLY
     FROM BM_UPDATE_ITEM P1
    INNER JOIN BM_RICH_ITEM P2
       ON P1.RICH_ITEM_ID=P2.RICH_ITEM_ID



  ''';

  static const String WhereSqlByLabelSizeId = '''
	  WHERE P1.RICH_LABELSIZE_ID=@labelSizeId
  ''';

  static const String AndSqlByIsApply = '''
	  AND P1.RICH_IS_APPLY=@isApply
  ''';

  static const String AndSqlBeforeTheDate = '''
	  AND CONVERT(VARCHAR,P1.RICH_APPLY_DATE,112)<='%s'
  ''';




  static const String OrderSqlByUpdateItemrder = '''
	  ORDER BY RICH_UpdateItem_ORDER ASC
  ''';

  static Future<List<UpdateItem>?> getByCustomerIdByUpdateItemOrder(
    int customerId,
  ) async {
    const fn = 'getByCustomerIdByUpdateItemOrder';
    debugPrint('$cn.$fn: $START, customerId:$customerId');

    try {
      final res = await DbClient.instance.getDataWithParams(
        '$SelectSql   $OrderSqlByUpdateItemrder',
        { 'customerId': customerId }
      );

      final rows = DAO.getRowsFromResult(res);
      final updateItems = UpdateItem.fromPipeLines(rows);

      debugPrint('$cn.$fn: $END');
      return updateItems;
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
