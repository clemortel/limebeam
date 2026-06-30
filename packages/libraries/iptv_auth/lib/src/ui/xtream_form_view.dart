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

  late final FocusNode _nameFocus;
  late final FocusNode _hostFocus;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;

  @override
  void initState() {
    super.initState();
    final XtreamFormState s = ref.read(addXtreamSourceProvider);
    _name = TextEditingController(text: s.name);
    _host = TextEditingController(text: s.host);
    _user = TextEditingController(text: s.username);
    _pass = TextEditingController(text: s.password);

    _nameFocus = FocusNode();
    _hostFocus = FocusNode();
    _userFocus = FocusNode();
    _passFocus = FocusNode();
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _user.dispose();
    _pass.dispose();
    _nameFocus.dispose();
    _hostFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _moveFocus(FocusNode next) =>
      FocusScope.of(context).requestFocus(next);

  void _submit() {
    if (ref.read(addXtreamSourceProvider).canSubmit) {
      widget.onContinue();
    }
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
                  focusNode: _nameFocus,
                  label: l.formSourceName,
                  placeholder: l.xtreamNameHint,
                  errorText: state.nameError,
                  onChanged: notifier.setName,
                  onEditingComplete: () => _moveFocus(_hostFocus),
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _host,
                  focusNode: _hostFocus,
                  label: l.xtreamHost,
                  placeholder: "http://monportail.tv:8080",
                  keyboardType: TextInputType.url,
                  errorText: state.hostError,
                  onChanged: notifier.setHost,
                  onEditingComplete: () => _moveFocus(_userFocus),
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _user,
                  focusNode: _userFocus,
                  label: l.xtreamUsername,
                  placeholder: l.xtreamUsernameHint,
                  errorText: state.usernameError,
                  onChanged: notifier.setUsername,
                  onEditingComplete: () => _moveFocus(_passFocus),
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
