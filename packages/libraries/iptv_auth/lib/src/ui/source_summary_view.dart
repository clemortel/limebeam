import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../riverpods/add_xtream_source_notifier.dart";
import "../riverpods/xtream_form_state.dart";

/// Résumé avant validation (§4.1.5). Read-only review with the password
/// masked. "Valider" starts the connection flow.
class SourceSummaryView extends ConsumerWidget {
  const SourceSummaryView({
    required this.onEdit,
    required this.onValidate,
    super.key,
  });

  final VoidCallback onEdit;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final XtreamFormState s = ref.watch(addXtreamSourceNotifierProvider);

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.summaryTitle, style: t.typography.h3),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(t.space.x4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(t.space.x4),
                        decoration: BoxDecoration(
                          color: t.colors.bgSurface,
                          borderRadius: t.radius.mdAll,
                        ),
                        child: Column(
                          children: <Widget>[
                            _Row(label: l.summaryName, value: s.name),
                            _Row(label: l.summaryHost, value: s.host),
                            _Row(label: l.summaryUser, value: s.username),
                            _Row(
                              label: l.commonPassword,
                              value: "•" * s.password.length,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      PrimaryButton(label: l.commonValidate, onPressed: onValidate),
                      SizedBox(height: t.space.x2),
                      SecondaryButton(label: l.commonEdit, onPressed: onEdit),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.x2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: t.typography.caption.copyWith(
            color: t.colors.textSecondary,
          ),),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
