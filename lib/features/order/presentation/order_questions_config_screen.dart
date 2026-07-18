import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../data/order_questions_dao.dart';
import '../../../core/security/app_mode_service.dart';

class OrderQuestionsConfigScreen extends StatefulWidget {
  const OrderQuestionsConfigScreen({super.key});

  @override
  State<OrderQuestionsConfigScreen> createState() => _OrderQuestionsConfigScreenState();
}

class _OrderQuestionsConfigScreenState extends State<OrderQuestionsConfigScreen> {
  List<OrderQuestion> _questions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final mode = await AppModeService.getAppMode();
    if (mode == AppMode.worker) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Access Denied: Only owners can manage order questions.');
        Navigator.of(context).pop();
      }
      return;
    }
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      final list = await OrderQuestionDao.instance.getCommonQuestions();
      setState(() {
        _questions = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to load questions: $e');
      }
    }
  }

  void _showAddEditDialog(OrderQuestion? existing) {
    AppHaptics.buttonClick();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditQuestionDialog(
        existing: existing,
        onSaved: () {
          _loadQuestions();
        },
      ),
    );
  }

  Future<void> _delete(String id) async {
    AppHaptics.buttonClick();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('This will archive the question. It will no longer show in new orders but past orders will preserve it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await OrderQuestionDao.instance.deleteQuestion(id);
        _loadQuestions();
        if (mounted) {
          SnackbarHelper.showSuccess(context, 'Question deleted successfully.');
        }
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Failed to delete question: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Order Notes Questions',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditDialog(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Question', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _questions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    return _buildQuestionCard(q);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.question_answer_outlined,
                size: 64,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Questions Configured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create custom questions and option choices to display as note templates on order checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(OrderQuestion q) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.question,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                  onPressed: () => _showAddEditDialog(q),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _delete(q.id),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'OPTIONS:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: q.options.map((opt) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Text(
                    opt,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class AddEditQuestionDialog extends StatefulWidget {
  final OrderQuestion? existing;
  final VoidCallback onSaved;

  const AddEditQuestionDialog({super.key, this.existing, required this.onSaved});

  @override
  State<AddEditQuestionDialog> createState() => _AddEditQuestionDialogState();
}

class _AddEditQuestionDialogState extends State<AddEditQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionCon = TextEditingController();
  final List<TextEditingController> _optionCons = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _questionCon.text = widget.existing!.question;
      for (final opt in widget.existing!.options) {
        _optionCons.add(TextEditingController(text: opt));
      }
    } else {
      // Start with 2 default option fields
      _optionCons.add(TextEditingController());
      _optionCons.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _questionCon.dispose();
    for (final con in _optionCons) {
      con.dispose();
    }
    super.dispose();
  }

  void _addOptionField() {
    AppHaptics.buttonClick();
    setState(() {
      _optionCons.add(TextEditingController());
    });
  }

  void _removeOptionField(int index) {
    AppHaptics.buttonClick();
    final controller = _optionCons[index];
    setState(() {
      _optionCons.removeAt(index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.success();

    final question = _questionCon.text.trim();
    final options = _optionCons
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (options.isEmpty) {
      SnackbarHelper.showError(context, 'Please add at least 1 option choice');
      return;
    }

    try {
      if (widget.existing != null) {
        await OrderQuestionDao.instance.updateQuestion(widget.existing!.id, question, options);
      } else {
        await OrderQuestionDao.instance.addQuestion(question, options);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        SnackbarHelper.showSuccess(context, 'Question saved successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save question: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Question' : 'Add New Question', style: const TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _questionCon,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Question Text',
                    hintText: 'e.g., how should be the tomato?',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the question';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Option Choices:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('Add Option'),
                      onPressed: _addOptionField,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _optionCons.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _optionCons[index],
                              decoration: InputDecoration(
                                labelText: 'Option ${index + 1}',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Enter option text';
                                }
                                return null;
                              },
                            ),
                          ),
                          if (_optionCons.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () => _removeOptionField(index),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _save,
          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
