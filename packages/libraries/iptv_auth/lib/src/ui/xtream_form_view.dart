import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/pairing.dart";
import "../riverpods/add_xtream_source_notifier.dart";
import "../riverpods/xtream_form_state.dart";
import "form_issue_text.dart";
import "pairing_sheet.dart";

const double _kFormMaxWidth = 560;

/// Hero card icon size (TV phone-entry affordance).
const double _kPhoneCardIconSize = 28;

/// Form — Xtream (§4.1.4). Fields + inline validation; "Continuer" enabled
/// only when valid. Field state + validation live in the notifier.
///
/// Focus / keyboard behaviour is handled by the dpad package installed at the
/// app root (Dpad.wrap). On TV, D-pad Down at the cursor edge advances to the
/// next field; IME composition owns the keys while a Fire TV keyboard is open.
/// On phone, TextInput.show forces the soft keyboard open after advancing.
class XtreamFormView extends ConsumerStatefulWidget {
  const XtreamFormView({
    required this.onContinue,
    this.onPhoneFilled,
    super.key,
  });

  final VoidCallback onContinue;

  /// Called after the phone submits valid credentials, so the host can skip
  /// the form + summary and jump straight to connecting (the user already
  /// reviewed the values on the TV confirm step). Falls back to [onContinue].
  final VoidCallback? onPhoneFilled;

  @override
  ConsumerState<XtreamFormView> createState() => _XtreamFormViewState();
}

class _XtreamFormViewState extends ConsumerState<XtreamFormView> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _user;
  late final TextEditingController _pass;
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

  void _advance() {
    // dpad's TextField integration moves focus to the next field via D-pad
    // edge navigation on TV. onEditingComplete fires on both TV and phone
    // when the IME action (Next) is received.
    FocusScope.of(context).nextFocus();
    if (!FormFactorScope.isTv(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }

  void _submit() {
    _passFocus.unfocus();
    if (ref.read(addXtreamSourceProvider).canSubmit) widget.onContinue();
  }

  /// Opens the "type on your phone" QR pairing dialog and, once the user
  /// confirms the values on the TV, mirrors them into the fields + notifier.
  Future<void> _typeOnPhone() async {
    final PhoneCredentials? creds = await PairingDialog.show(context);
    if (creds == null || !mounted) return;
    final AddXtreamSourceNotifier notifier =
        ref.read(addXtreamSourceProvider.notifier);
    if (creds.name.isNotEmpty) {
      _name.text = creds.name;
      notifier.setName(creds.name);
    }
    _host.text = creds.host;
    notifier.setHost(creds.host);
    _user.text = creds.username;
    notifier.setUsername(creds.username);
    _pass.text = creds.password;
    notifier.setPassword(creds.password);
    // The user already reviewed these on the TV confirm step, so jump straight
    // to connecting instead of dropping them back on the filled form.
    if (ref.read(addXtreamSourceProvider).canSubmit) {
      (widget.onPhoneFilled ?? widget.onContinue)();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final XtreamFormState state = ref.watch(addXtreamSourceProvider);
    final AddXtreamSourceNotifier notifier =
        ref.read(addXtreamSourceProvider.notifier);
    final bool isTv = FormFactorScope.isTv(context);

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
                // TV only: the phone-entry path is the fastest (no remote
                // typing), so it leads as a hero card and takes initial focus.
                // Hidden on phone/tablet, where the user just types directly.
                if (isTv) ...<Widget>[
                  _PhoneEntryCard(autofocus: true, onTap: _typeOnPhone),
                  SizedBox(height: t.space.x5),
                  _OrDivider(label: l.orEnterManually),
                  SizedBox(height: t.space.x5),
                ],
                AppInput(
                  controller: _name,
                  // On TV dpad handles autofocus per route; phone opens keyboard.
                  autofocus: !isTv,
                  label: l.formSourceName,
                  placeholder: l.onboardingNameOptional,
                  onChanged: notifier.setName,
                  onEditingComplete: _advance,
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _host,
                  label: l.xtreamHost,
                  placeholder: l.onboardingXtreamUrlPlaceholder,
                  keyboardType: TextInputType.url,
                  errorText: state.hostError.text(l),
                  onChanged: notifier.setHost,
                  onEditingComplete: _advance,
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _user,
                  label: l.xtreamUsername,
                  placeholder: l.xtreamUsernameHint,
                  errorText: state.usernameError.text(l),
                  onChanged: notifier.setUsername,
                  onEditingComplete: _advance,
                ),
                SizedBox(height: t.space.x4),
                AppInput(
                  controller: _pass,
                  focusNode: _passFocus,
                  label: l.commonPassword,
                  placeholder: "••••••••",
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  errorText: state.passwordError.text(l),
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
                // Content-width on TV is handled by PrimaryButton itself.
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

/// TV hero affordance for "type on your phone" — styled like the source-type
/// cards so the fastest path reads as the primary choice, not a plain button.
class _PhoneEntryCard extends StatelessWidget {
  const _PhoneEntryCard({required this.onTap, this.autofocus = false});

  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return PressableScale(
      autofocus: autofocus,
      onTap: onTap,
      focusBorderRadius: t.radius.lgAll,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(t.space.x5),
        decoration: BoxDecoration(
          color: t.colors.bgSurface,
          borderRadius: t.radius.lgAll,
          border: Border.all(color: t.colors.borderSubtle),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.qr_code_2,
              size: _kPhoneCardIconSize,
              color: t.colors.accent,
            ),
            SizedBox(width: t.space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l.typeOnPhone,
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.textPrimary),
                  ),
                  SizedBox(height: t.space.x1),
                  Text(
                    l.typeOnPhoneHint,
                    style: t.typography.caption
                        .copyWith(color: t.colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Labelled separator between the phone-entry hero and the manual fields.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Row(
      children: <Widget>[
        Expanded(child: Divider(color: t.colors.borderSubtle)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.x3),
          child: Text(
            label,
            style: t.typography.caption.copyWith(color: t.colors.textTertiary),
          ),
        ),
        Expanded(child: Divider(color: t.colors.borderSubtle)),
      ],
    );
  }
}
