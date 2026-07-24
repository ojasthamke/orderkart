import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../domain/app_note.dart';
import 'note_provider.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/snackbar_helper.dart';

class AddEditNoteScreen extends ConsumerStatefulWidget {
  final AppNote? existingNote;

  const AddEditNoteScreen({super.key, this.existingNote});

  @override
  ConsumerState<AddEditNoteScreen> createState() => _AddEditNoteScreenState();
}

class _AddEditNoteScreenState extends ConsumerState<AddEditNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  bool _isPinned = false;
  int _colorLabel = 0;
  DateTime? _remindAt;

  final List<Color> _availableColors = [
    Colors.transparent,
    Colors.red.shade100,
    Colors.green.shade100,
    Colors.blue.shade100,
    Colors.yellow.shade100,
    Colors.purple.shade100,
  ];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingNote?.title ?? '');
    _contentController =
        TextEditingController(text: widget.existingNote?.content ?? '');
    _isPinned = widget.existingNote?.isPinned ?? false;
    _colorLabel = widget.existingNote?.colorLabel ?? 0;

    if (widget.existingNote?.remindAt.isNotEmpty == true) {
      _remindAt = DateTime.tryParse(widget.existingNote!.remindAt);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _remindAt ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_remindAt ?? DateTime.now()),
      );
      if (time != null && mounted) {
        setState(() {
          _remindAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final note = AppNote(
      id: widget.existingNote?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      remindAt: _remindAt?.toIso8601String() ?? '',
      colorLabel: _colorLabel,
      isPinned: _isPinned,
      createdAt: widget.existingNote?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.existingNote == null) {
      ref.read(noteListNotifier.notifier).addNote(note);
    } else {
      ref.read(noteListNotifier.notifier).updateNote(note);
    }

    if (_remindAt != null && _remindAt!.isAfter(DateTime.now())) {
      NotificationService.instance.scheduleNotification(
        id: note.id.hashCode,
        title: 'Note Reminder: $title',
        body:
            content.isNotEmpty ? content : 'You have a reminder for this note.',
        scheduledDate: _remindAt!,
        payload: 'note_${note.id}',
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = _colorLabel == 0
        ? theme.scaffoldBackgroundColor
        : _availableColors[_colorLabel];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.existingNote != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final ok = await ConfirmDeleteDialog.show(
                  context,
                  title: 'Delete Note',
                  message: 'Are you sure you want to delete this note?',
                );
                if (ok && context.mounted) {
                  final note = widget.existingNote!;
                  await ref.read(noteListNotifier.notifier).deleteNote(note.id);
                  if (context.mounted) {
                    Navigator.pop(context);
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
              tooltip: 'Delete Note',
            ),
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: () {
              setState(() {
                _isPinned = !_isPinned;
              });
            },
            tooltip: _isPinned ? 'Unpin' : 'Pin',
          ),
          IconButton(
            icon: const Icon(Icons.notification_add_outlined),
            onPressed: _pickReminder,
            tooltip: 'Add reminder',
          ),
          IconButton(
            icon: const Icon(Icons.color_lens_outlined),
            onPressed: _showColorPicker,
            tooltip: 'Change color',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveNote,
            tooltip: 'Save Note',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              if (_remindAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.alarm,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Reminder: ${_remindAt!.year}-${_remindAt!.month.toString().padLeft(2, '0')}-${_remindAt!.day.toString().padLeft(2, '0')} ${_remindAt!.hour.toString().padLeft(2, '0')}:${_remindAt!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _remindAt = null),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _titleController,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Note',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final color = _availableColors[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _colorLabel = index;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color == Colors.transparent
                        ? Theme.of(context).colorScheme.primaryContainer
                        : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _colorLabel == index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: _colorLabel == index ? 3 : 1,
                    ),
                  ),
                  child: color == Colors.transparent
                      ? const Icon(Icons.format_color_reset, color: Colors.grey)
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
