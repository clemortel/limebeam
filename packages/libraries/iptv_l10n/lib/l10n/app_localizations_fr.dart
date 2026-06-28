// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabTv => 'TV';

  @override
  String get tabBrowse => 'Films & Séries';

  @override
  String get tabSearch => 'Recherche';

  @override
  String get tabSettings => 'Réglages';

  @override
  String get homeResume => 'Reprendre';

  @override
  String get homeFavorites => 'Favoris';

  @override
  String get homePopularMovies => 'Films populaires';

  @override
  String get homePopularSeries => 'Séries populaires';

  @override
  String get homeEmptyTitle => 'Rien à afficher';

  @override
  String get homeEmptyMessage =>
      'Vos chaînes et contenus apparaîtront ici après la synchronisation de votre source.';

  @override
  String get browseMovies => 'Films';

  @override
  String get browseSeries => 'Séries';

  @override
  String get searchTitle => 'Recherche';

  @override
  String get searchPlaceholder => 'Rechercher chaînes, films, séries…';

  @override
  String get searchPrompt => 'Rechercher';

  @override
  String get searchEmptyTitle => 'Aucun résultat';

  @override
  String get searchEmptyMessage =>
      'Aucun contenu ne correspond à votre recherche.';

  @override
  String get settingsSources => 'Sources';

  @override
  String get settingsSupport => 'Soutenir le développeur';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get aboutTitle => 'À propos';

  @override
  String get aboutNoContent =>
      'LimeBeam ne fournit aucun contenu. L\'application lit vos playlists ou identifiants IPTV existants.';

  @override
  String get aboutPrivacy =>
      'Aucune donnée n\'est collectée. Vos identifiants, favoris et historique restent sur votre appareil.';

  @override
  String get aboutLicenses => 'Licences open-source';

  @override
  String aboutVersion(Object version, Object build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutVersionLoading => 'Version…';

  @override
  String get searchPromptMessage =>
      'Trouvez une chaîne, un film ou une série dans vos sources.';
}
