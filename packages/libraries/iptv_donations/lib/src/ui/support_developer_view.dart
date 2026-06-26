import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/donation_product.dart";
import "../riverpods/donation_products_notifier.dart";
import "../riverpods/donation_purchase_notifier.dart";

const double _kHeaderIconSize = 56;
const double _kTipEmojiSize = 28;
const int _kSkeletonCards = 3;
const double _kTipCardHeight = 76;
const double _kCardBorderWidth = 1;
const double _kRecommendedBorderWidth = 1.5;

/// "Soutenir le développeur" (Tip Jar). Warm, non-pushy: an intro block + a few
/// consumable tips. No external links — platform billing only, unlocks nothing.
class SupportDeveloperView extends ConsumerWidget {
  const SupportDeveloperView({this.onTipped, super.key});

  /// Called after a successful tip (the app marks the user as a supporter).
  final VoidCallback? onTipped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<DonationProduct>> products =
        ref.watch(donationProductsNotifierProvider);
    final bool busy =
        ref.watch(donationPurchaseNotifierProvider) is AsyncLoading<bool>;

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text("Soutenir le développeur", style: t.typography.h3),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(t.space.x4),
          children: <Widget>[
            const _IntroBlock(),
            SizedBox(height: t.space.x6),
            switch (products) {
              AsyncIdle<IList<DonationProduct>>() => const _CardsSkeleton(),
              AsyncLoading<IList<DonationProduct>>() => const _CardsSkeleton(),
              AsyncError<IList<DonationProduct>>() => _ErrorBlock(
                  onRetry: () => ref
                      .read(donationProductsNotifierProvider.notifier)
                      .refresh(),
                ),
              AsyncSuccess<IList<DonationProduct>>(
                :final IList<DonationProduct> data
              ) =>
                data.isEmpty
                    ? const EmptyState(
                        icon: Icons.volunteer_activism_outlined,
                        title: "Bientôt",
                        message: "Les pourboires seront disponibles très vite.",
                      )
                    : Column(
                        children: <Widget>[
                          for (final DonationProduct p in data) ...<Widget>[
                            _TipCard(
                              product: p,
                              enabled: !busy,
                              onTap: () => _buy(context, ref, p),
                            ),
                            SizedBox(height: t.space.x3),
                          ],
                        ],
                      ),
            },
            SizedBox(height: t.space.x4),
            const _LegalFooter(),
          ],
        ),
      ),
    );
  }

  Future<void> _buy(
    BuildContext context,
    WidgetRef ref,
    DonationProduct product,
  ) async {
    final bool purchased =
        await ref.read(donationPurchaseNotifierProvider.notifier).buy(product);
    if (!context.mounted) return;
    if (purchased) {
      AppToast.show(context, message: "Merci pour ton soutien ❤️");
      onTipped?.call();
      return;
    }
    final AsyncState<bool> state = ref.read(donationPurchaseNotifierProvider);
    if (state is AsyncError<bool>) {
      AppToast.show(
        context,
        message: "Achat impossible. Réessaie plus tard.",
        kind: ToastKind.error,
      );
    }
  }
}

class _IntroBlock extends StatelessWidget {
  const _IntroBlock();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.favorite, size: _kHeaderIconSize, color: t.colors.accent),
        SizedBox(height: t.space.x4),
        Text("Soutenir LimeBeam", style: t.typography.h2),
        SizedBox(height: t.space.x2),
        Text(
          "LimeBeam est entièrement gratuit, sans pub ni tracking. Je développe "
          "l'app sur mon temps libre pour avoir un player IPTV propre, rapide et "
          "agréable.\n\nSi tu veux m'aider à continuer (et à tester de nouvelles "
          "idées), tu peux laisser un pourboire ci-dessous. Merci ❤️",
          style: t.typography.body.copyWith(color: t.colors.textSecondary),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.product,
    required this.enabled,
    required this.onTap,
  });

  final DonationProduct product;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool highlight = product.isRecommended;
    return PressableScale(
      enabled: enabled,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: _kTipCardHeight),
          padding: EdgeInsets.all(t.space.x4),
          decoration: BoxDecoration(
            color: highlight ? t.colors.accentSubtle : t.colors.bgSurface,
            borderRadius: t.radius.lgAll,
            border: Border.all(
              color: highlight ? t.colors.accent : t.colors.borderSubtle,
              width: highlight ? _kRecommendedBorderWidth : _kCardBorderWidth,
            ),
          ),
          child: Row(
            children: <Widget>[
              Text(
                product.emoji,
                style: const TextStyle(fontSize: _kTipEmojiSize),
              ),
              SizedBox(width: t.space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            product.title,
                            style: t.typography.bodyStrong
                                .copyWith(color: t.colors.textPrimary),
                          ),
                        ),
                        if (highlight) ...<Widget>[
                          SizedBox(width: t.space.x2),
                          const _RecommendedBadge(),
                        ],
                      ],
                    ),
                    SizedBox(height: t.space.x1),
                    Text(
                      product.subtitle,
                      style: t.typography.caption
                          .copyWith(color: t.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.space.x3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    product.price,
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.accent),
                  ),
                  SizedBox(height: t.space.x1),
                  Text(
                    "Soutenir",
                    style:
                        t.typography.micro.copyWith(color: t.colors.accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.x2, vertical: t.space.x1),
      decoration: BoxDecoration(
        color: t.colors.accent,
        borderRadius: t.radius.smAll,
      ),
      child: Text(
        "Populaire",
        style: t.typography.micro.copyWith(color: t.colors.textOnAccent),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Text(
      "Les pourboires sont traités comme des achats intégrés. Ils ne débloquent "
      "aucun contenu : c'est simplement un soutien au développement.",
      style: t.typography.caption.copyWith(color: t.colors.textTertiary),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.volunteer_activism_outlined,
      title: "Indisponible",
      message: "Impossible de charger les options de soutien pour l'instant.",
      action: PrimaryButton(
        label: "Réessayer",
        expand: false,
        onPressed: onRetry,
      ),
    );
  }
}

class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      children: <Widget>[
        for (int i = 0; i < _kSkeletonCards; i++) ...<Widget>[
          SkeletonBox(height: _kTipCardHeight, borderRadius: t.radius.lgAll),
          SizedBox(height: t.space.x3),
        ],
      ],
    );
  }
}
