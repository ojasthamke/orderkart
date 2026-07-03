import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_note.dart';
import 'note_provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(noteListNotifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        centerTitle: true,
      ),
      body: notesState.when(
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Text(
                'No notes yet. Tap + to create one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _NoteCard(note: note);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading notes: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.addEditNote);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final AppNote note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    final List<Color> noteColors = [
      theme.colorScheme.primaryContainer,
      Colors.red.shade100,
      Colors.green.shade100,
      Colors.blue.shade100,
      Colors.yellow.shade100,
      Colors.purple.shade100,
    ];
    
    // Fallback to 0 if colorLabel is out of bounds
    final colorIndex = (note.colorLabel >= 0 && note.colorLabel < noteColors.length) 
        ? note.colorLabel 
        : 0;
    final color = noteColors[colorIndex];

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.addEditNote,
          arguments: {'note': note},
        );
      },
      onLongPress: () async {
        final ok = await ConfirmDeleteDialog.show(
          context,
          title: 'Delete Note',
          message: 'Are you sure you want to delete this note?',
        );
        if (ok && context.mounted) {
          await ref.read(noteListNotifier.notifier).deleteNote(note.id);
          if (context.mounted) {
            SnackbarHelper.showWithUndo(
              context, 
              message: 'Note deleted',
              undoLabel: 'Undo',
            ).then((undone) async {
              if (undone) {
                await ref.read(noteListNotifier.notifier).addNote(note);
              }
            });
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.title.isNotEmpty) ...[
              Text(
                note.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: Text(
                note.content,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.fade,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (note.remindAt.isNotEmpty)
                  Icon(
                    Icons.alarm,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                const Spacer(),
                if (note.isPinned)
                  Icon(
                    Icons.push_pin,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
