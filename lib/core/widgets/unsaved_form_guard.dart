import 'package:flutter/cupertino.dart';

/// Wraps a form screen/sheet and prompts Save / Discard when popping with dirty fields.
class UnsavedFormGuard extends StatelessWidget {
  final bool isDirty;
  final Future<bool> Function()? onSave;
  final VoidCallback onDiscard;
  final Widget child;

  const UnsavedFormGuard({
    super.key,
    required this.isDirty,
    required this.onDiscard,
    required this.child,
    this.onSave,
  });

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. What would you like to do?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          if (onSave != null)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Save'),
            ),
        ],
      ),
    );
    if (result == 'discard') {
      onDiscard();
      return true;
    }
    if (result == 'save' && onSave != null) {
      final ok = await onSave!();
      return ok;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!isDirty) {
          if (context.mounted) Navigator.of(context).pop();
          return;
        }
        final leave = await _confirmDiscard(context);
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
