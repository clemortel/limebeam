import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../riverpods/add_m3u_source_notifier.dart";
import "../riverpods/m3u_form_state.dart";
import "form_issue_text.dart";

/// Form — M3U playlist. Name + playlist URL (+ optional EPG URL); "Continuer"
/// enabled only when valid. Field state + validation live in the notifier.
class M3uFormView extends ConsumerStatefulWidget {
  const M3uFormView({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  ConsumerState<M3uFormView> createState() => _M3uFormViewState();
}

class _M3uFormViewState extends ConsumerState<M3uFormView> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _epg;

  @override
  void initState() {
    super.initState();
    final M3uFormState s = ref.read(addM3uSourceProvider);
    _name = TextEditingController(text: s.name);
    _url = TextEditingController(text: s.url);
    _epg = TextEditingController(text: s.epgUrl);
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _epg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final M3uFormState state = ref.watch(addM3uSourceProvider);
    final AddM3uSourceNotifier notifier =
        ref.read(addM3uSourceProvider.notifier);

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.sourceTypeM3u, style: t.typography.h3),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(t.space.x4),
          children: <Widget>[
            AppInput(
              controller: _name,
              label: l.formSourceName,
              placeholder: l.onboardingNameOptional,
              onChanged: notifier.setName,
            ),
            SizedBox(height: t.space.x4),
            AppInput(
              controller: _url,
              label: l.m3uUrl,
              placeholder: l.onboardingM3uUrlPlaceholder,
              helperText: l.m3uUrlHint,
              keyboardType: TextInputType.url,
              errorText: state.urlError.text(l),
              onChanged: notifier.setUrl,
            ),
            SizedBox(height: t.space.x4),
            AppInput(
              controller: _epg,
              label: l.m3uEpgUrl,
              placeholder: l.onboardingEpgUrlPlaceholder,
              keyboardType: TextInputType.url,
              onChanged: notifier.setEpgUrl,
            ),
            SizedBox(height: t.space.x3),
            Text(
              l.m3uHint,
              style: t.typography.caption.copyWith(color: t.colors.textTertiary),
            ),
            SizedBox(height: t.space.x6),
            PrimaryButton(
              label: l.commonContinue,
              onPressed: state.canSubmit ? widget.onContinue : null,
            ),
          ],
        ),
      ),
    );
  }
}
