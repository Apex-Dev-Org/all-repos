import 'package:flutter/material.dart';

/// One text field in [showBrandedInputDialog].
class BrandedDialogField {
  const BrandedDialogField({
    required this.labelText,
    this.hintText,
    this.initialValue = '',
    this.prefixIcon = Icons.edit_outlined,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  final String labelText;
  final String? hintText;
  final String initialValue;
  final IconData prefixIcon;
  final TextInputType keyboardType;

  /// Return a localized error string, or null if valid.
  final String? Function(String value)? validator;
}

/// Shows a rounded white card dialog matching [InputDecorationTheme] from the app theme.
///
/// [onSubmit] runs when the user taps the primary button. Return `null` to close
/// the dialog successfully; return a non-empty string to show an inline error
/// and keep the dialog open.
///
/// Returns `true` if the user submitted successfully, `false` if they cancelled,
/// or `null` if the route was popped without a result (e.g. barrier dismiss).
Future<bool?> showBrandedInputDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<BrandedDialogField> fields,
  required String primaryLabel,
  required String cancelLabel,
  required Future<String?> Function(List<String> values) onSubmit,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _BrandedInputDialog(
        title: title,
        subtitle: subtitle,
        fields: fields,
        primaryLabel: primaryLabel,
        cancelLabel: cancelLabel,
        onSubmit: onSubmit,
      );
    },
  );
}

class _BrandedInputDialog extends StatefulWidget {
  const _BrandedInputDialog({
    required this.title,
    this.subtitle,
    required this.fields,
    required this.primaryLabel,
    required this.cancelLabel,
    required this.onSubmit,
  });

  final String title;
  final String? subtitle;
  final List<BrandedDialogField> fields;
  final String primaryLabel;
  final String cancelLabel;
  final Future<String?> Function(List<String> values) onSubmit;

  @override
  State<_BrandedInputDialog> createState() => _BrandedInputDialogState();
}

class _BrandedInputDialogState extends State<_BrandedInputDialog> {
  late final List<TextEditingController> _controllers;
  String? _submitError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controllers = widget.fields
        .map((f) => TextEditingController(text: f.initialValue))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onPrimary() async {
    setState(() {
      _submitError = null;
    });

    for (var i = 0; i < widget.fields.length; i++) {
      final v = widget.fields[i].validator;
      if (v != null) {
        final err = v(_controllers[i].text);
        if (err != null) {
          setState(() => _submitError = err);
          return;
        }
      }
    }

    setState(() => _submitting = true);
    try {
      final values = _controllers.map((c) => c.text).toList();
      final err = await widget.onSubmit(values);
      if (!mounted) return;
      if (err == null || err.isEmpty) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _submitError = err);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                for (var i = 0; i < widget.fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  Text(
                    widget.fields[i].labelText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controllers[i],
                    keyboardType: widget.fields[i].keyboardType,
                    autocorrect: widget.fields[i].keyboardType ==
                        TextInputType.emailAddress
                        ? false
                        : true,
                    decoration: InputDecoration(
                      hintText: widget.fields[i].hintText,
                      prefixIcon: Icon(
                        widget.fields[i].prefixIcon,
                        size: 20,
                      ),
                    ),
                  ),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submitError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(widget.cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed: _submitting ? null : _onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.primaryLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
