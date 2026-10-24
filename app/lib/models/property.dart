String formatNumber(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

class Property {
  final String id;
  final String title;
  final String district;
  final String type; // شقة / فيلا / محل / مكتب / أرض
  final String listingType; // بيع / إيجار
  final int price;
  final int area;
  final int beds;
  final int baths;
  final String finishing;
  final List<String> paymentMethods;
  final String imageUrl;
  final bool isFeatured;
  final bool isVerified;
  final int viewsCount;
  final List<String> features;
  final List<String> images;
  final String description;
  final String ownerName;
  final String ownerType; // مكتب / مطور / فرد

  const Property({
    required this.id,
    required this.title,
    required this.district,
    required this.type,
    required this.listingType,
    required this.price,
    required this.area,
    required this.beds,
    required this.baths,
    required this.finishing,
    required this.paymentMethods,
    required this.imageUrl,
    required this.ownerName,
    required this.ownerType,
    this.isFeatured = false,
    this.isVerified = false,
    this.viewsCount = 0,
    this.features = const [],
    this.images = const [],
    this.description = '',
  });

  bool get isRent => listingType == 'إيجار';

  String get priceLabel =>
      '${formatNumber(price)} ج.م${isRent ? ' / شهرياً' : ''}';
}

class Developer {
  final String project;
  final String developer;
  final int units;
  final String delivery;

  const Developer({
    required this.project,
    required this.developer,
    required this.units,
    required this.delivery,
  });
}
