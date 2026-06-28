/// iptv_ui — publishable design system.
///
/// Pure, primitive-only widgets and design tokens. No business logic,
/// no Failures, no Riverpod. Implementation stays under `src/`.
library iptv_ui;

// Brand (LimeBeam mark / wordmark / lockup).
export "src/brand/brand.dart";
// Components (§2).
export "src/components/app_badge.dart";
export "src/components/app_bottom_sheet.dart";
export "src/components/app_buttons.dart";
export "src/components/app_input.dart";
export "src/components/app_toast.dart";
export "src/components/channel_row.dart";
export "src/components/empty_state.dart";
export "src/components/filter_chip_x.dart";
export "src/components/glass_scope.dart";
export "src/components/glass_surface.dart";
export "src/components/iptv_focusable.dart";
export "src/components/live_tile.dart";
export "src/components/media_poster_card.dart";
export "src/components/pressable_scale.dart";
export "src/components/section_carousel.dart";
export "src/components/skeleton_box.dart";
// Responsive (form-factor adaptation, read via FormFactorScope.of).
export "src/responsive/form_factor.dart";
// Theme tokens (read via context.appTheme).
export "src/theme/app_colors.dart";
export "src/theme/app_glass.dart";
export "src/theme/app_motion.dart";
export "src/theme/app_radius.dart";
export "src/theme/app_space.dart";
export "src/theme/app_theme.dart";
export "src/theme/app_type.dart";
