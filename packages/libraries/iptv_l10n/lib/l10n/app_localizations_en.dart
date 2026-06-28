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
}
