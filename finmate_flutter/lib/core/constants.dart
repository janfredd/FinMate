// Central constants: API base, defaults, regex helpers shared with backend.
class AppConstants {
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
  static const List<String> defaultCategories = [
    'Food', 'Transportation', 'Shopping', 'Entertainment',
    'Bills', 'Health', 'Education', 'Others'
  ];
}
