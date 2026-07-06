import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ExportFilenameDialog extends StatefulWidget {
  final String defaultName;
  final String extension;
  final String title;

  const ExportFilenameDialog({
    super.key,
    required this.defaultName,
    this.extension = '.orderkart',
    this.title = 'Name Export Package',
  });

  static Future<String?> show(
    BuildContext context, {
    required String defaultName,
    String extension = '.orderkart',
    String title = 'Name Export Package',
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ExportFilenameDialog(
        defaultName: defaultName,
        extension: extension,
        title: title,
      ),
    );
  }

  @override
  State<ExportFilenameDialog> createState() => _ExportFilenameDialogState();
}

class _ExportFilenameDialogState extends State<ExportFilenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    final cleanName = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final fullName = cleanName.endsWith(widget.extension)
        ? cleanName
        : '$cleanName${widget.extension}';

    Navigator.of(context).pop(fullName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_document, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customize file name before generating and exporting package:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              suffixText: widget.extension,
              suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              labelText: 'Package Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Save & Export'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
