import '../domain/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getAllExpenses({String? searchQuery, String? category, String? month});
  Future<Expense?> getExpenseById(String id);
  Future<List<Map<String, dynamic>>> getMonthlySummary();
  Future<String> addExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String id);
}
