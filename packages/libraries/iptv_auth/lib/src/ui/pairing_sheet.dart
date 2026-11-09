import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:pretty_qr_code/pretty_qr_code.dart";

import "../models/pairing.dart";
import "../riverpods/pairing_controller.dart";

/// Size of the rendered QR code (logical px). Large enough for a phone camera
/// to lock on from couch distance, but small enough to fit the dialog height
/// once TV token scaling (1.3x) inflates the surrounding text/spacing.
const double _kQrSize = 200;

/// Max width of the pairing dialog card.
const double _kDialogMaxWidth = 420;

/// Status-row icon size.
const double _kIconSizeSmall = 18;

/// "Unavailable" state icon size.
const double _kIconSizeLarge = 40;

/// AppLocalizations.of(context).onboardingPairingTitle dialog. Starts an on-device pairing server, shows a QR
/// the phone scans, then — once the phone submits — asks the user to confirm on
/// the TV before returning the [PhoneCredentials]. Returns null if dismissed.
///
/// The server is torn down automatically when this closes (the autoDispose
/// [pairingControllerProvider] disposes once unwatched).
class PairingDialog extends ConsumerStatefulWidget {
  const PairingDialog({super.key});

  static Future<PhoneCredentials?> show(BuildContext context) {
    return showDialog<PhoneCredentials>(
      context: context,
      builder: (BuildContext _) => const PairingDialog(),
    );
  }

  @override
  ConsumerState<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends ConsumerState<PairingDialog> {
  @override
  void initState() {
    super.initState();
    // Mutating the provider during build is disallowed; start after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pairingControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AsyncState<PairingSession> state =
        ref.watch(pairingControllerProvider);

    final Widget body = switch (state) {
      AsyncIdle<PairingSession>() ||
      AsyncLoading<PairingSession>() =>
        const _Starting(),
      AsyncSuccess<PairingSession>(:final PairingSession data) =>
        data.received != null
            ? _ConfirmReceived(
                credentials: data.received!,
                onApply: () => Navigator.of(context).pop(data.received),
                onCancel: () => Navigator.of(context).pop(),
              )
            : _ShowQr(session: data),
      AsyncError<PairingSession>() => _Unavailable(
          onClose: () => Navigator.of(context).pop(),
        ),
    };

    return Dialog(
      backgroundColor: t.colors.bgSurface,
      insetPadding: EdgeInsets.all(t.space.x6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kDialogMaxWidth),
        // Scrollable so a short TV screen (amplified by the 1.3x token scale)
        // never overflows — the content shrinks to fit or scrolls with the D-pad.
        child: SingleChildScrollView(
          child: Padding(padding: EdgeInsets.all(t.space.x6), child: body),
        ),
      ),
    );
  }
}

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircularProgressIndicator(color: t.colors.accent),
        SizedBox(height: t.space.x4),
        Text(
          AppLocalizations.of(context).onboardingPairingStarting,
          style: t.typography.body.copyWith(color: t.colors.textSecondary),
        ),
      ],
    );
  }
}

class _ShowQr extends StatelessWidget {
  const _ShowQr({required this.session});

  final PairingSession session;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppLocalizations.of(context).onboardingPairingTitle,
          textAlign: TextAlign.center,
          style: t.typography.h3.copyWith(color: t.colors.textPrimary),
        ),
        SizedBox(height: t.space.x2),
        Text(
          AppLocalizations.of(context).onboardingPairingScan,
          textAlign: TextAlign.center,
          style: t.typography.caption.copyWith(color: t.colors.textSecondary),
        ),
        SizedBox(height: t.space.x5),
        Center(
          child: Container(
            padding: EdgeInsets.all(t.space.x4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: t.radius.mdAll,
            ),
            child: SizedBox(
              width: _kQrSize,
              height: _kQrSize,
              child: PrettyQrView.data(
                data: session.url,
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(
                    color: Color(0xFF000000),
                    roundFactor: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: t.space.x5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              session.phoneConnected
                  ? Icons.smartphone
                  : Icons.qr_code_scanner,
              size: _kIconSizeSmall,
              color: session.phoneConnected
                  ? t.colors.accent
                  : t.colors.textTertiary,
            ),
            SizedBox(width: t.space.x2),
            Text(
              session.phoneConnected
                  ? AppLocalizations.of(context).onboardingPairingConnected
                  : AppLocalizations.of(context).onboardingPairingWaiting,
              style: t.typography.caption.copyWith(
                color: session.phoneConnected
                    ? t.colors.accent
                    : t.colors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmReceived extends StatelessWidget {
  const _ConfirmReceived({
    required this.credentials,
    required this.onApply,
    required this.onCancel,
  });

  final PhoneCredentials credentials;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppLocalizations.of(context).onboardingPairingReceived,
          textAlign: TextAlign.center,
          style: t.typography.h3.copyWith(color: t.colors.textPrimary),
        ),
        SizedBox(height: t.space.x4),
        _Field(label: AppLocalizations.of(context).summaryName, value: credentials.name),
        _Field(label: AppLocalizations.of(context).xtreamHost, value: credentials.host),
        _Field(label: AppLocalizations.of(context).xtreamUsername, value: credentials.username),
        _Field(
          label: AppLocalizations.of(context).commonPassword,
          value: credentials.password.isEmpty
              ? ""
              : "•" * credentials.password.length,
        ),
        SizedBox(height: t.space.x5),
        PrimaryButton(label: AppLocalizations.of(context).onboardingPairingFill, onPressed: onApply),
        SizedBox(height: t.space.x2),
        SecondaryButton(label: AppLocalizations.of(context).commonCancel, onPressed: onCancel),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x1),
          Text(
            value.isEmpty ? "—" : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.typography.body.copyWith(color: t.colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.wifi_off, size: _kIconSizeLarge, color: t.colors.textTertiary),
        SizedBox(height: t.space.x4),
        Text(
          AppLocalizations.of(context).onboardingPairingFailedTitle,
          textAlign: TextAlign.center,
          style: t.typography.h3.copyWith(color: t.colors.textPrimary),
        ),
        SizedBox(height: t.space.x2),
        Text(
          AppLocalizations.of(context).onboardingPairingFailedMessage,
          textAlign: TextAlign.center,
          style: t.typography.caption.copyWith(color: t.colors.textSecondary),
        ),
        SizedBox(height: t.space.x5),
        SecondaryButton(label: AppLocalizations.of(context).onboardingClose, onPressed: onClose),
      ],
    );
  }
}
