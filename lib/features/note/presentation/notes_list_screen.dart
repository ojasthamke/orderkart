import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_note.dart';
import 'note_provider.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/scale_on_tap.dart';
import '../../../core/widgets/liquid_glass_button.dart';
import '../../../core/constants/app_colors.dart';

class NotesListScreen extends ConsumerWidget {
  final bool showBack;
  const NotesListScreen({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(noteListNotifier);

    return AppScaffold(
      title: 'My Notes',
      showBack: showBack,
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
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: showBack ? 0 : 100),
        child: Builder(builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return LiquidGlassButton(
            width: 56,
            height: 56,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.addEditNote);
            },
            child: Icon(Icons.add_rounded, color: isDark ? Colors.white : AppColors.primary, size: 24),
          );
        }),
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
    final isDark = theme.brightness == Brightness.dark;
    
    final List<Color> noteColors = isDark 
        ? [
            theme.colorScheme.primaryContainer.withOpacity(0.20),
            Colors.red.withOpacity(0.12),
            Colors.green.withOpacity(0.12),
            Colors.blue.withOpacity(0.12),
            Colors.amber.withOpacity(0.12),
            Colors.purple.withOpacity(0.12),
          ]
        : [
            theme.colorScheme.primaryContainer.withOpacity(0.50),
            Colors.red.shade100.withOpacity(0.50),
            Colors.green.shade100.withOpacity(0.50),
            Colors.blue.shade100.withOpacity(0.50),
            Colors.yellow.shade100.withOpacity(0.50),
            Colors.purple.shade100.withOpacity(0.50),
          ];
    
    // Fallback to 0 if colorLabel is out of bounds
    final colorIndex = (note.colorLabel >= 0 && note.colorLabel < noteColors.length) 
        ? note.colorLabel 
        : 0;
    final color = noteColors[colorIndex];

    void tapAction() {
      Navigator.pushNamed(
        context,
        AppRoutes.addEditNote,
        arguments: {'note': note},
      );
    }

    void longPressAction() async {
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
    }

    return ScaleOnTap(
      onTap: tapAction,
      onLongPress: longPressAction,
      child: GlassContainer(
        borderRadius: BorderRadius.circular(16),
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
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
      ),
    );
  }
}
