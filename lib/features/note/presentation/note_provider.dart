import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/note_dao.dart';
import '../domain/app_note.dart';

class NoteListNotifier extends StateNotifier<AsyncValue<List<AppNote>>> {
  final NoteDao _dao;

  NoteListNotifier(this._dao) : super(const AsyncValue.loading()) {
    _loadNotes();
  }

  Future<void> _loadNotes({bool silent = false}) async {
    if (!silent && state.valueOrNull == null) {
      state = const AsyncValue.loading();
    }
    try {
      final notes = await _dao.getNotes();
      state = AsyncValue.data(notes);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addNote(AppNote note) async {
    try {
      await _dao.insert(note);
      await _loadNotes(silent: true);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> updateNote(AppNote note) async {
    try {
      await _dao.update(note);
      await _loadNotes(silent: true);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _dao.delete(id);
      await _loadNotes(silent: true);
    } catch (e, st) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final noteListNotifier = StateNotifierProvider<NoteListNotifier, AsyncValue<List<AppNote>>>((ref) {
  return NoteListNotifier(NoteDao());
});
