import "package:dartz/dartz.dart" hide IList, IMap, ISet, State;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/source.dart";
import "../models/source_action_failure.dart";
import "../riverpods/sources_notifier.dart";
import "source_action_failure_text.dart";

/// Opens the per-source action sheet: refresh (active source only), rename,
/// delete. Delete always goes through a confirmation sheet.
///
/// Reads [ref] only here, synchronously: the row that opened the sheet can
/// be unmounted by the time an action finishes, and a [WidgetRef] must not
/// be touched after that. Each action works on the notifier captured now.
Future<void> showSourceActions(
  BuildContext context,
  WidgetRef ref, {
  required Source source,
  required bool isActive,
  required bool isOnlySource,
  required bool canRefresh,
  required VoidCallback onNoSourceLeft,
}) {
  final AppLocalizations l = AppLocalizations.of(context);
  final SourcesNotifier notifier = ref.read(sourcesProvider.notifier);
  return AppBottomSheet.show<void>(
    context,
    title: source.name,
    child: _SourceActions(
      isActive: isActive,
      canRefresh: canRefresh,
      onRefresh: () {
        Navigator.of(context).pop();
        notifier.refreshCatalog();
      },
      onRename: () {
        Navigator.of(context).pop();
        AppBottomSheet.show<void>(
          context,
          title: l.sourcesRenameTitle,
          child: _RenameSheet(
            initialName: source.name,
            onSave: (String name) => _rename(context, notifier, source, name),
          ),
        );
      },
      onDelete: () {
        Navigator.of(context).pop();
        AppBottomSheet.show<void>(
          context,
          title: l.sourcesDeleteTitle,
          child: _DeleteConfirm(
            message: switch ((isActive, isOnlySource)) {
              (_, true) => l.sourcesDeleteLastMessage(source.name),
              (true, false) => l.sourcesDeleteActiveMessage(source.name),
              (false, false) => l.sourcesDeleteMessage(source.name),
            },
            onConfirm: () => _delete(context, notifier, source, onNoSourceLeft),
          ),
        );
      },
    ),
  );
}

/// Renames [source]; a refused or failed rename is surfaced, not dropped.
Future<void> _rename(
  BuildContext context,
  SourcesNotifier notifier,
  Source source,
  String name,
) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final Either<SourceActionFailure, Unit> result =
      await notifier.rename(source.id, name);
  if (!context.mounted) return;
  _toastFailure(context, l, result);
}

/// Deletes [source]; surfaces a failure instead of letting the row silently
/// come back, and hands over to [onNoSourceLeft] when nothing remains.
///
/// Nothing is read from a [WidgetRef] after the await: the notifier returns
/// the outcome, and only [BuildContext.mounted]-guarded UI follows.
Future<void> _delete(
  BuildContext context,
  SourcesNotifier notifier,
  Source source,
  VoidCallback onNoSourceLeft,
) async {
  final AppLocalizations l = AppLocalizations.of(context);
  final Either<SourceActionFailure, DeleteOutcome> result =
      await notifier.delete(source.id);
  // The host guards its own context: this row is gone once it succeeded.
  final bool noSourceLeft = result.fold(
    (SourceActionFailure _) => false,
    (DeleteOutcome o) => o == DeleteOutcome.noSourceLeft,
  );
  if (noSourceLeft) {
    onNoSourceLeft();
    return;
  }
  if (!context.mounted) return;
  _toastFailure(context, l, result);
}

void _toastFailure<T>(
  BuildContext context,
  AppLocalizations l,
  Either<SourceActionFailure, T> result,
) {
  result.fold(
    (SourceActionFailure f) =>
        AppToast.show(context, message: f.text(l), kind: ToastKind.error),
    (T _) {},
  );
}

class _SourceActions extends StatelessWidget {
  const _SourceActions({
    required this.isActive,
    required this.canRefresh,
    required this.onRefresh,
    required this.onRename,
    required this.onDelete,
  });

  final bool isActive;
  final bool canRefresh;
  final VoidCallback onRefresh;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isActive)
          ListTile(
            leading: Icon(Icons.refresh, color: t.colors.textSecondary),
            title: Text(
              l.sourcesRefresh,
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
            enabled: canRefresh,
            onTap: onRefresh,
          ),
        ListTile(
          leading: Icon(Icons.edit_outlined, color: t.colors.textSecondary),
          title: Text(
            l.sourcesRename,
            style: t.typography.body.copyWith(color: t.colors.textPrimary),
          ),
          onTap: onRename,
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: t.colors.error),
          title: Text(
            l.sourcesDelete,
            style: t.typography.body.copyWith(color: t.colors.error),
          ),
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm({required this.message, required this.onConfirm});

  final String message;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          message,
          style: t.typography.body.copyWith(color: t.colors.textSecondary),
        ),
        SizedBox(height: t.space.x4),
        DestructiveButton(
          label: l.sourcesDelete,
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
        ),
        SizedBox(height: t.space.x2),
        // Cancel takes initial focus: a stray click must not delete.
        SecondaryButton(
          label: l.commonCancel,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initialName, required this.onSave});

  final String initialName;
  final ValueChanged<String> onSave;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_controller.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppInput(
            controller: _controller,
            autofocus: true,
            label: l.formSourceName,
            placeholder: l.formSourceName,
            textInputAction: TextInputAction.done,
            onEditingComplete: _save,
          ),
          SizedBox(height: t.space.x4),
          PrimaryButton(label: l.sourcesRenameSave, onPressed: _save),
        ],
      ),
    );
  }
}
