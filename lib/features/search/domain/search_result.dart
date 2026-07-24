/// SearchResult — unified search result across all entities
library;

enum SearchResultType {
  area,
  street,
  customer,
  order,
  item,
  expense,
}

class SearchResult {
  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String? tertiary;

  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.tertiary,
  });

  String get typeLabel {
    switch (type) {
      case SearchResultType.area:
        return 'Area';
      case SearchResultType.street:
        return 'Street';
      case SearchResultType.customer:
        return 'Customer';
      case SearchResultType.order:
        return 'Order';
      case SearchResultType.item:
        return 'Item';
      case SearchResultType.expense:
        return 'Expense';
    }
  }
}
