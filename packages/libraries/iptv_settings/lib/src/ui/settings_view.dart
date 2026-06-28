import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/app_preferences.dart";
import "../riverpods/app_preferences_notifier.dart";
import "../riverpods/parental_session.dart";

const int _kPinLength = 4;
const double _kActionIconSize = 20;

/// Réglages sections (§4.6): Interface, Lecture, Contrôle parental. Embeddable
/// (no Scaffold) so the app shell can host it alongside the Sources section.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _InterfaceSection(),
        SizedBox(height: t.space.x4),
        const _LectureSection(),
        SizedBox(height: t.space.x4),
        const _SubtitlesSection(),
        SizedBox(height: t.space.x4),
        const _ParentalSection(),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: t.space.x4),
      padding: EdgeInsets.all(t.space.x4),
      decoration: BoxDecoration(
        color: t.colors.bgSurface,
        borderRadius: t.radius.lgAll,
        border: Border.all(color: t.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: t.typography.h3.copyWith(color: t.colors.textPrimary),
          ),
          SizedBox(height: t.space.x3),
          ...children,
        ],
      ),
    );
  }
}

class _InterfaceSection extends ConsumerWidget {
  const _InterfaceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final AppPreferences prefs = ref.watch(appPreferencesNotifierProvider);
    final AppPreferencesNotifier notifier =
        ref.read(appPreferencesNotifierProvider.notifier);
    return _SectionCard(
      title: l.settingsInterface,
      children: <Widget>[
        _ChoiceRow<AppLanguage>(
          label: l.settingsLanguage,
          value: prefs.language,
          options: <(AppLanguage, String)>[
            (AppLanguage.system, l.languageSystem),
            (AppLanguage.fr, l.languageFrench),
            (AppLanguage.en, l.languageEnglish),
          ],
          onSelected: notifier.setLanguage,
        ),
        SizedBox(height: t.space.x3),
        _ChoiceRow<AppThemeMode>(
          label: l.settingsTheme,
          value: prefs.themeMode,
          options: <(AppThemeMode, String)>[
            (AppThemeMode.system, l.themeSystem),
            (AppThemeMode.light, l.themeLight),
            (AppThemeMode.dark, l.themeDark),
          ],
          onSelected: notifier.setThemeMode,
        ),
        SizedBox(height: t.space.x3),
        _ChoiceRow<FontScaleOption>(
          label: l.settingsFontSize,
          value: prefs.fontScale,
          options: <(FontScaleOption, String)>[
            (FontScaleOption.normal, l.fontNormal),
            (FontScaleOption.large, l.fontLarge),
          ],
          onSelected: notifier.setFontScale,
        ),
        // Glass is already force-disabled on TV, so the toggle is a no-op there.
        if (!FormFactorScope.isTv(context)) ...<Widget>[
          SizedBox(height: t.space.x2),
          _SwitchRow(
            label: l.settingsReduceTransparency,
            value: prefs.reduceTransparency,
            onChanged: notifier.setReduceTransparency,
          ),
          Text(
            l.settingsReduceTransparencyHint,
            style: t.typography.caption.copyWith(color: t.colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

class _LectureSection extends ConsumerWidget {
  const _LectureSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppPreferences prefs = ref.watch(appPreferencesNotifierProvider);
    final AppPreferencesNotifier notifier =
        ref.read(appPreferencesNotifierProvider.notifier);
    return _SectionCard(
      title: l.settingsPlayback,
      children: <Widget>[
        _SwitchRow(
          label: l.playbackAutoplayNext,
          value: prefs.autoplayNext,
          onChanged: notifier.setAutoplayNext,
        ),
        // Touch gestures are disabled on TV (the remote drives the player), so
        // the gesture toggle is meaningless there.
        if (!FormFactorScope.isTv(context))
          _SwitchRow(
            label: l.playbackVolumeGesture,
            value: prefs.playerGestures,
            onChanged: notifier.setPlayerGestures,
          ),
      ],
    );
  }
}

class _SubtitlesSection extends ConsumerWidget {
  const _SubtitlesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final AppPreferences prefs = ref.watch(appPreferencesNotifierProvider);
    final AppPreferencesNotifier notifier =
        ref.read(appPreferencesNotifierProvider.notifier);
    // Language names stay as endonyms (universal); only "none" is localized.
    final List<(String?, String)> languages = <(String?, String)>[
      (null, l.langNone),
      ("fra", "Français"),
      ("eng", "English"),
      ("spa", "Español"),
      ("deu", "Deutsch"),
      ("ita", "Italiano"),
      ("ara", "العربية"),
      ("por", "Português"),
    ];
    final List<(double, String)> scales = <(double, String)>[
      (0.75, l.subSizeSmall),
      (1.0, l.subSizeNormal),
      (1.25, l.subSizeLarge),
      (1.5, l.subSizeXLarge),
    ];
    final List<(int, String)> colors = <(int, String)>[
      (0xFFFFFFFF, l.colorWhite),
      (0xFFFFEB3B, l.colorYellow),
      (0xFF00E5FF, l.colorCyan),
      (0xFF00E676, l.colorGreen),
    ];
    final List<(double, String)> backgrounds = <(double, String)>[
      (0.0, l.bgNone),
      (0.5, l.bgMedium),
      (1.0, l.bgOpaque),
    ];
    return _SectionCard(
      title: l.settingsSubtitlesAudio,
      children: <Widget>[
        _ChoiceRow<String?>(
          label: l.audioPreferredLanguage,
          value: prefs.preferredAudioLanguage,
          options: languages,
          onSelected: notifier.setPreferredAudioLanguage,
        ),
        SizedBox(height: t.space.x3),
        _ChoiceRow<String?>(
          label: l.subtitlePreferredLanguage,
          value: prefs.preferredSubtitleLanguage,
          options: languages,
          onSelected: notifier.setPreferredSubtitleLanguage,
        ),
        SizedBox(height: t.space.x2),
        _SwitchRow(
          label: l.subtitlesEnableDefault,
          value: prefs.subtitlesEnabledByDefault,
          onChanged: notifier.setSubtitlesEnabledByDefault,
        ),
        SizedBox(height: t.space.x3),
        _ChoiceRow<double>(
          label: l.subtitleSize,
          value: prefs.subtitleFontScale,
          options: scales,
          onSelected: notifier.setSubtitleFontScale,
        ),
        SizedBox(height: t.space.x3),
        _ChoiceRow<int>(
          label: l.subtitleTextColor,
          value: prefs.subtitleTextColorArgb,
          options: colors,
          onSelected: notifier.setSubtitleTextColorArgb,
        ),
        SizedBox(height: t.space.x3),
        _ChoiceRow<double>(
          label: l.subtitleBackground,
          value: prefs.subtitleBackgroundOpacity,
          options: backgrounds,
          onSelected: notifier.setSubtitleBackgroundOpacity,
        ),
        SizedBox(height: t.space.x2),
        Text(
          l.subtitlesHint,
          style: t.typography.caption.copyWith(color: t.colors.textTertiary),
        ),
      ],
    );
  }
}

class _ParentalSection extends ConsumerWidget {
  const _ParentalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final AppPreferences prefs = ref.watch(appPreferencesNotifierProvider);
    final bool unlocked = ref.watch(parentalSessionProvider);
    return _SectionCard(
      title: l.settingsParental,
      children: <Widget>[
        _SwitchRow(
          label: l.parentalHideAdult,
          value: prefs.parentalEnabled,
          onChanged: (bool value) => _onToggle(context, ref, value),
        ),
        if (prefs.parentalEnabled) ...<Widget>[
          SizedBox(height: t.space.x2),
          _ActionRow(
            label: unlocked ? l.parentalLock : l.parentalUnlock,
            icon: unlocked ? Icons.lock_outline : Icons.lock_open_outlined,
            onTap: () => _toggleLock(context, ref, unlocked),
          ),
          _ActionRow(
            label: l.parentalChangePin,
            icon: Icons.password_outlined,
            onTap: () => _changePin(context, ref),
          ),
        ],
        SizedBox(height: t.space.x2),
        Text(
          l.parentalHint(_kPinLength),
          style: t.typography.caption.copyWith(color: t.colors.textTertiary),
        ),
      ],
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppPreferencesNotifier notifier =
        ref.read(appPreferencesNotifierProvider.notifier);
    final String? pin = await _PinDialog.show(
      context,
      title: enable ? l.parentalSetPin : l.parentalEnterPin,
    );
    if (pin == null) return;
    if (enable) {
      await notifier.enableParental(pin);
      if (context.mounted) {
        AppToast.show(context, message: l.parentalEnabledToast);
      }
      return;
    }
    final bool ok = await notifier.disableParental(pin);
    if (!context.mounted) return;
    if (ok) {
      ref.read(parentalSessionProvider.notifier).lock();
    } else {
      AppToast.show(context, message: l.parentalWrongPin, kind: ToastKind.error);
    }
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool unlocked,
  ) async {
    final AppLocalizations l = AppLocalizations.of(context);
    if (unlocked) {
      ref.read(parentalSessionProvider.notifier).lock();
      return;
    }
    final String? pin =
        await _PinDialog.show(context, title: l.parentalEnterPin);
    if (pin == null) return;
    final bool ok =
        await ref.read(appPreferencesNotifierProvider.notifier).verifyPin(pin);
    if (!context.mounted) return;
    if (ok) {
      ref.read(parentalSessionProvider.notifier).unlock();
      AppToast.show(context, message: l.parentalUnlockedToast);
    } else {
      AppToast.show(context, message: l.parentalWrongPin, kind: ToastKind.error);
    }
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final AppPreferencesNotifier notifier =
        ref.read(appPreferencesNotifierProvider.notifier);
    final String? current = await _PinDialog.show(
      context,
      title: l.parentalCurrentPin,
    );
    if (current == null) return;
    if (!await notifier.verifyPin(current)) {
      if (context.mounted) {
        AppToast.show(context, message: l.parentalWrongPin, kind: ToastKind.error);
      }
      return;
    }
    if (!context.mounted) return;
    final String? next = await _PinDialog.show(context, title: l.parentalNewPin);
    if (next == null) return;
    await notifier.enableParental(next);
    if (context.mounted) {
      AppToast.show(context, message: l.parentalChangedToast);
    }
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: t.space.x2),
        child: Row(
          children: <Widget>[
            Icon(icon, size: _kActionIconSize, color: t.colors.textSecondary),
            SizedBox(width: t.space.x3),
            Expanded(
              child: Text(
                label,
                style: t.typography.body.copyWith(color: t.colors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, color: t.colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final void Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: t.typography.body.copyWith(color: t.colors.textSecondary),
        ),
        SizedBox(height: t.space.x2),
        Wrap(
          spacing: t.space.x2,
          children: <Widget>[
            for (final (T, String) option in options)
              FilterChipX(
                label: option.$2,
                selected: option.$1 == value,
                onTap: () => onSelected(option.$1),
              ),
          ],
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final void Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.x1),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: t.colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  static Future<String?> show(BuildContext context, {required String title}) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => _PinDialog(title: title),
    );
  }

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    // Glass dialog, but the PIN field stays on a solid fill so the digits keep
    // AA contrast regardless of what's blurred behind the dialog.
    return Dialog(
      backgroundColor: const Color(0x00000000),
      elevation: 0,
      insetPadding: EdgeInsets.all(t.space.x6),
      child: GlassSurface(
        kind: GlassKind.dialog,
        radius: t.radius.lgAll,
        padding: EdgeInsets.all(t.space.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.title,
              style: t.typography.h3.copyWith(color: t.colors.textPrimary),
            ),
            SizedBox(height: t.space.x4),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: _kPinLength,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: t.typography.h2.copyWith(color: t.colors.textPrimary),
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: t.colors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: t.radius.smAll,
                  borderSide: BorderSide(color: t.colors.borderDefault),
                ),
              ),
            ),
            SizedBox(height: t.space.x4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l.commonCancel,
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.textSecondary),
                  ),
                ),
                SizedBox(width: t.space.x2),
                TextButton(
                  onPressed: () {
                    if (_controller.text.length == _kPinLength) {
                      Navigator.of(context).pop(_controller.text);
                    }
                  },
                  child: Text(
                    l.commonValidate,
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.accentTextOnDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
