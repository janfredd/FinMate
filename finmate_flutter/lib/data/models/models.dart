class Txn {
  final String id, userId, type;
  final double amount;
  final String? categoryId, categoryName, merchant, note, source, date, createdAt;
  Txn({required this.id, required this.userId, required this.type,
    required this.amount, this.categoryId, this.categoryName,
    this.merchant, this.note, this.source, this.date, this.createdAt});
  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
    id: j['id'] ?? '', userId: j['user_id'] ?? '', type: j['type'] ?? 'expense',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    categoryId: j['category_id'], categoryName: j['category_name'],
    merchant: j['merchant'], note: j['note'], source: j['source'],
    date: j['date']?.toString(), createdAt: j['created_at']?.toString());
}

class Category {
  final String id, name;
  final String? userId;
  final bool isDefault;
  Category({required this.id, required this.name, this.userId, this.isDefault = false});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'], name: j['name'], userId: j['user_id'],
    isDefault: j['is_default'] == true);
}

class Budget {
  final String id, categoryId;
  final double amount, spent, pct;
  final String period, startDate, endDate;
  final String? categoryName;
  Budget({required this.id, required this.categoryId, required this.amount,
    this.spent = 0, this.pct = 0, required this.period,
    required this.startDate, required this.endDate, this.categoryName});
  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
    id: j['id'], categoryId: j['category_id'],
    amount: (j['amount'] as num).toDouble(),
    spent: (j['spent'] as num?)?.toDouble() ?? 0,
    pct: (j['pct'] as num?)?.toDouble() ?? 0,
    period: j['period'], startDate: j['start_date'], endDate: j['end_date'],
    categoryName: j['category_name']);
}

class Summary {
  final double income, expense, balance, savings;
  Summary({required this.income, required this.expense,
    required this.balance, required this.savings});
  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
    income: (j['total_income'] as num).toDouble(),
    expense: (j['total_expense'] as num).toDouble(),
    balance: (j['balance'] as num).toDouble(),
    savings: (j['savings'] as num).toDouble());
}
