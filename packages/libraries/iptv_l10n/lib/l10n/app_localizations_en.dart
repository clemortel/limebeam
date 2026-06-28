// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabHome => 'Home';

  @override
  String get tabTv => 'TV';

  @override
  String get tabBrowse => 'Movies & Series';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabSettings => 'Settings';

  @override
  String get homeResume => 'Resume';

  @override
  String get homeFavorites => 'Favorites';

  @override
  String get homePopularMovies => 'Popular movies';

  @override
  String get homePopularSeries => 'Popular series';

  @override
  String get homeEmptyTitle => 'Nothing to show';

  @override
  String get homeEmptyMessage =>
      'Your channels and content will appear here once your source has synced.';

  @override
  String get browseMovies => 'Movies';

  @override
  String get browseSeries => 'Series';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchPlaceholder => 'Search channels, movies, series…';

  @override
  String get searchPrompt => 'Search';

  @override
  String get searchEmptyTitle => 'No results';

  @override
  String get searchEmptyMessage => 'No content matches your search.';

  @override
  String get settingsSources => 'Sources';

  @override
  String get settingsSupport => 'Support the developer';

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutNoContent =>
      'LimeBeam provides no content. The app reads your existing IPTV playlists or credentials.';

  @override
  String get aboutPrivacy =>
      'No data is collected. Your credentials, favorites and history stay on your device.';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String aboutVersion(Object version, Object build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutVersionLoading => 'Version…';

  @override
  String get searchPromptMessage =>
      'Find a channel, movie or series in your sources.';

  @override
  String get settingsInterface => 'Interface';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsFontSize => 'Text size';

  @override
  String get fontNormal => 'Normal';

  @override
  String get fontLarge => 'Large';

  @override
  String get settingsReduceTransparency => 'Reduce transparency';

  @override
  String get settingsReduceTransparencyHint =>
      'Disables glass effects for more legible surfaces.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageFrench => 'French';

  @override
  String get languageEnglish => 'English';

  @override
  String get commonRetry => 'Retry';

  @override
  String get donateIntroTitle => 'Support LimeBeam';

  @override
  String get donateIntroBody =>
      'LimeBeam is completely free, with no ads or tracking. I build it in my spare time to have a clean, fast and pleasant IPTV player.\n\nIf you\'d like to help me keep going, you can leave a tip below. Thank you ❤️';

  @override
  String get donateSoonTitle => 'Coming soon';

  @override
  String get donateSoonMessage => 'Tips will be available very soon.';

  @override
  String get donateErrorTitle => 'Unavailable';

  @override
  String get donateErrorMessage =>
      'Couldn\'t load the support options right now.';

  @override
  String get donateCardCta => 'Support';

  @override
  String get donatePopular => 'Popular';

  @override
  String get donateLegalFooter =>
      'Tips are in-app purchases. They unlock no content — they\'re simply support for development.';

  @override
  String get donatePurchaseError => 'Purchase failed. Please try again later.';

  @override
  String get tipPromptTitle => 'Enjoying LimeBeam?';

  @override
  String get tipPromptBody =>
      'LimeBeam is free, with no ads or tracking. If it makes your life easier, you can buy me a coffee to support development ☕.';

  @override
  String get tipPromptSupport => 'Support LimeBeam';

  @override
  String get tipPromptLater => 'Later';

  @override
  String get thanksTitle => 'Thank you ❤️';

  @override
  String get thanksBody =>
      'Your support truly makes a difference. Thanks to you, LimeBeam keeps moving forward — free, no ads, no tracking.';

  @override
  String get thanksBadge => '✨ Supporter';

  @override
  String get thanksCta => 'My pleasure';
}
