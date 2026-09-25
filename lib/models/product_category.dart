class ProductCategory {
  final String id;
  final String name;
  final DateTime createdAt;

  ProductCategory({
    required this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    if (map['created_at'] != null) {
      if (map['created_at'] is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int);
      } else if (map['created_at'] is String) {
        parsedDate = DateTime.tryParse(map['created_at'] as String) ?? DateTime.now();
      }
    }
    return ProductCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: parsedDate,
    );
  }
}

class ProductBrand {
  final String id;
  final String name;
  final String? categoryId; // can link to category id or category name
  final DateTime createdAt;

  ProductBrand({
    required this.id,
    required this.name,
    this.categoryId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category_id': categoryId,
    'created_at': createdAt.toIso8601String(),
  };

  factory ProductBrand.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate = DateTime.now();
    if (map['created_at'] != null) {
      if (map['created_at'] is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int);
      } else if (map['created_at'] is String) {
        parsedDate = DateTime.tryParse(map['created_at'] as String) ?? DateTime.now();
      }
    }
    return ProductBrand(
      id: map['id'] as String,
      name: map['name'] as String,
      categoryId: map['category_id'] as String?,
      createdAt: parsedDate,
    );
  }
}

const List<String> kDefaultCategories = [
  'Standard',
  'Premium',
  'Informatique',
  'Bureautique',
  'Alimentation',
  'Électronique',
  'Outillage',
  'Mobilier',
  'Services',
  'Divers',
];

const Map<String, List<String>> kDefaultCategoryBrands = {
  'Informatique': ['Dell', 'HP', 'Apple', 'Lenovo', 'Asus', 'Logitech'],
  'Électronique': ['Samsung', 'Sony', 'Xiaomi', 'Apple', 'Canon'],
  'Bureautique': ['Canon', 'HP', 'Epson', 'Brother', 'Logitech'],
  'Mobilier': ['Ikea', 'Steelcase', 'Herman Miller', 'Autre'],
  'Outillage': ['Bosch', 'Makita', 'DeWalt', 'Stanley'],
  'Alimentation': ['Nestlé', 'Danone', 'Coca-Cola', 'Autre'],
  'Standard': ['Samsung', 'Apple', 'Dell', 'HP', 'Logitech', 'Autre'],
  'Premium': ['Apple', 'Sony', 'Dell', 'Bose', 'Autre'],
  'Services': ['Interne', 'Externe', 'Autre'],
  'Divers': ['Générique', 'Autre'],
};
