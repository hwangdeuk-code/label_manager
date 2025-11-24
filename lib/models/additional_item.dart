// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

class AdditionalItem {
	final int AdditionalItemId;
	final int itemId;
	final String element;
	final String elementRTF;
	final int price;

  const AdditionalItem({
    required this.AdditionalItemId,
    required this.itemId,
    required this.element,
    required this.elementRTF,
    required this.price,
  });

  @override
  String toString() =>
    'AdditionalItemId: $AdditionalItemId, itemId: $itemId, element: $element, elementRTF: $elementRTF, price: $price';
}
