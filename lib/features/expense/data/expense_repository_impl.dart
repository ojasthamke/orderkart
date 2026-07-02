import '../domain/expense.dart';
import '../domain/expense_repository.dart';
import 'expense_dao.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseDao _dao;
  ExpenseRepositoryImpl(this._dao);

  @override
  Future<List<Expense>> getAllExpenses({String? searchQuery, String? category, String? month}) =>
      _dao.getAllExpenses(searchQuery: searchQuery, category: category, month: month);

  @override
  Future<Expense?> getExpenseById(String id) => _dao.getExpenseById(id);

  @override
  Future<List<Map<String, dynamic>>> getMonthlySummary() => _dao.getMonthlySummary();

  @override
  Future<String> addExpense(Expense expense) => _dao.insertExpense(expense);

  @override
  Future<void> updateExpense(Expense expense) => _dao.updateExpense(expense);

  @override
  Future<void> deleteExpense(String id) => _dao.deleteExpense(id);
}
