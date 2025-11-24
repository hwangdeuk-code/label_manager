// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

class Item {
	final int itemId;
	final int labelSizeId;
	final String itemName;
	final String labelSizeName;
	final String element;
	final String elementRTF;
	final int price;
	final int order;

  const Item({
    required this.itemId,
    required this.labelSizeId,
    required this.itemName,
    required this.labelSizeName,
    required this.element,
    required this.elementRTF,
    required this.price,
    required this.order
  });

  @override
  String toString() =>
    'itemId: $itemId, labelSizeId: $labelSizeId, itemName: $itemName, labelSizeName: $labelSizeName, '
    'element: $element, elementRTF: $elementRTF, price: $price, order: $order';
}
