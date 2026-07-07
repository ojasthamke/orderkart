import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../data/worker_dao.dart';
import '../domain/worker.dart';

final workerDaoProvider = Provider<WorkerDao>((ref) => WorkerDao());

class WorkerListNotifier extends StateNotifier<AsyncValue<List<Worker>>> {
  final WorkerDao _dao;

  WorkerListNotifier(this._dao) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final workers = await _dao.getAllWorkers();
      state = AsyncValue.data(workers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(Worker worker) async {
    await _dao.insertWorker(worker);
    await load();
  }

  Future<void> update(Worker worker) async {
    await _dao.updateWorker(worker);
    await load();
  }

  Future<void> delete(String id) async {
    await _dao.deleteWorker(id);
    await load();
  }
}

final workerListProvider =
    StateNotifierProvider<WorkerListNotifier, AsyncValue<List<Worker>>>(
        (ref) => WorkerListNotifier(ref.watch(workerDaoProvider)));

final workerCommissionProvider =
    FutureProvider.family<Map<String, double>, String>((ref, workerId) {
  return ref.watch(workerDaoProvider).getWorkerCommissionSummary(workerId);
});

final activeWorkersListProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.query('workers', columns: ['id', 'name'], orderBy: 'name ASC');
  return rows.map((r) => {
    'id': r['id']?.toString() ?? '',
    'name': r['name']?.toString() ?? '',
  }).toList();
});
