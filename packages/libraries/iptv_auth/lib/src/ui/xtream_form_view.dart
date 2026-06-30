import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../riverpods/add_xtream_source_notifier.dart";
import "../riverpods/xtream_form_state.dart";

const double _kFormMaxWidth = 560;

/// Form — Xtream (§4.1.4). Fields + inline validation; "Continuer" enabled
/// only when valid. Field state + validation live in the notifier.
class XtreamFormView extends ConsumerStatefulWidget {
  const XtreamFormView({required this.onContinue, super.key});

  /// Called when the user proceeds to the summary with a valid form.
  final VoidCallback onContinue;

  @override
  ConsumerState<XtreamFormView> createState() => _XtreamFormViewState();
}

class _XtreamFormViewState extends ConsumerState<XtreamFormView> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _user;
  late final TextEditingController _pass;

  // Only the last field needs an explicit FocusNode (to unfocus on submit).
  // Intermediate fields use FocusScope.nextFocus() which correctly handles
  // both the IME "Next" button and D-pad navigation on Android TV.
  late final FocusNode _passFocus;

  @override
  void initState() {
    super.initState();
    final XtreamFormState s = ref.read(addXtreamSourceProvider);
    _name = TextEditingController(text: s.name);
    _host = TextEditingController(text: s.host);
    _user = TextEditingController(text: s.username);
    _pass = TextEditingController(text: s.password);
    _passFocus = FocusNode();
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit() {
    _passFocus.unfocus();
    if (ref.read(addXtreamSourceProvider).canSubmit) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final XtreamFormState state = ref.watch(addXtreamSourceProvider);
    final AddXtreamSourceNotifier notifier =
        ref.read(addXtreamSourceProvider.notifier);

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.sourceTypeXtream, style: t.typography.h3),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.x6,
                vertical: t.space.x4,
              ),
              children: <Widget>[
                AppInput(
                  controller: _name,
                  autofocus: true,
                  label: l.formSourceName,
                  placeholder: l.xtreamNameHint,
                  errorText: state.nameError,
                  onChanged: notifier.setName,
                  // nextFocus() advances focus AND keeps the keyboard open on
                  // the new field — correct for both IME and TV D-pad.
                  onEditingComplete: FocusScope.of(context).nextFocus,
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _host,
                  label: l.xtreamHost,
                  placeholder: "http://monportail.tv:8080",
                  keyboardType: TextInputType.url,
                  errorText: state.hostError,
                  onChanged: notifier.setHost,
                  onEditingComplete: FocusScope.of(context).nextFocus,
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _user,
                  label: l.xtreamUsername,
                  placeholder: l.xtreamUsernameHint,
                  errorText: state.usernameError,
                  onChanged: notifier.setUsername,
                  onEditingComplete: FocusScope.of(context).nextFocus,
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _pass,
                  focusNode: _passFocus,
                  label: l.commonPassword,
                  placeholder: "••••••••",
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  errorText: state.passwordError,
                  onChanged: notifier.setPassword,
                  onEditingComplete: _submit,
                ),
                SizedBox(height: t.space.x3),
                Text(
                  l.xtreamHint,
                  style: t.typography.caption
                      .copyWith(color: t.colors.textTertiary),
                ),
                SizedBox(height: t.space.x6),
                PrimaryButton(
                  label: l.commonContinue,
                  onPressed: state.canSubmit ? widget.onContinue : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
