import 'property.dart';

class PropertyFilters {
  final Set<String> districts;
  final double? maxPrice;
  final String? finishing;
  final String? payment;

  const PropertyFilters({
    this.districts = const {},
    this.maxPrice,
    this.finishing,
    this.payment,
  });

  int get activeCount =>
      (districts.isNotEmpty ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      (finishing != null ? 1 : 0) +
      (payment != null ? 1 : 0);

  PropertyFilters withoutPrice() => PropertyFilters(
        districts: districts,
        finishing: finishing,
        payment: payment,
      );

  bool matches(Property p) {
    if (districts.isNotEmpty && !districts.contains(p.district)) return false;
    if (maxPrice != null && p.price > maxPrice!) return false;
    if (finishing != null && p.finishing != finishing) return false;
    if (payment != null && !p.paymentMethods.contains(payment)) return false;
    return true;
  }
}
