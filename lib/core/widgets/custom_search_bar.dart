/// CustomSearchBar — Reusable animated search bar
library;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'voice_search_dialog.dart';

import 'glass_container.dart';

class CustomSearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const CustomSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onClear,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(14),
      child: TextField(
        controller: _controller,
        onChanged: (val) {
          setState(() {});
          widget.onChanged(val);
        },
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textPrimaryColor(context)),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.gray500),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.gray500, size: 18),
                  onPressed: _clear,
                ),
              IconButton(
                icon: const Icon(Icons.mic_rounded,
                    color: AppColors.primary, size: 20),
                onPressed: () async {
                  final text = await VoiceSearchDialog.show(context);
                  if (text != null && text.trim().isNotEmpty) {
                    setState(() {
                      _controller.text = text;
                    });
                    widget.onChanged(text);
                  }
                },
              ),
            ],
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
