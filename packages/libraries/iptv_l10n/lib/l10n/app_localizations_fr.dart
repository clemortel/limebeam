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

  @override
  String get settingsInterface => 'Interface';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get settingsFontSize => 'Taille du texte';

  @override
  String get fontNormal => 'Normal';

  @override
  String get fontLarge => 'Grande';

  @override
  String get settingsReduceTransparency => 'Réduire la transparence';

  @override
  String get settingsReduceTransparencyHint =>
      'Désactive les effets de verre pour des surfaces plus lisibles.';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get donateIntroTitle => 'Soutenir LimeBeam';

  @override
  String get donateIntroBody =>
      'LimeBeam est entièrement gratuit, sans pub ni tracking. Je développe l\'app sur mon temps libre pour un player IPTV propre, rapide et agréable.\n\nSi tu veux m\'aider à continuer, tu peux laisser un pourboire ci-dessous. Merci ❤️';

  @override
  String get donateSoonTitle => 'Bientôt';

  @override
  String get donateSoonMessage =>
      'Les pourboires seront disponibles très vite.';

  @override
  String get donateErrorTitle => 'Indisponible';

  @override
  String get donateErrorMessage =>
      'Impossible de charger les options de soutien pour l\'instant.';

  @override
  String get donateCardCta => 'Soutenir';

  @override
  String get donatePopular => 'Populaire';

  @override
  String get donateLegalFooter =>
      'Les pourboires sont des achats intégrés. Ils ne débloquent aucun contenu : c\'est simplement un soutien au développement.';

  @override
  String get donatePurchaseError => 'Achat impossible. Réessaie plus tard.';

  @override
  String get tipPromptTitle => 'Tu aimes LimeBeam ?';

  @override
  String get tipPromptBody =>
      'LimeBeam est gratuit, sans pub et sans tracking. Si l\'app te simplifie la vie, tu peux m\'offrir un café pour soutenir le dev ☕.';

  @override
  String get tipPromptSupport => 'Soutenir LimeBeam';

  @override
  String get tipPromptLater => 'Plus tard';

  @override
  String get thanksTitle => 'Merci ❤️';

  @override
  String get thanksBody =>
      'Ton soutien fait vraiment la différence. Grâce à toi, LimeBeam continue d\'avancer — gratuit, sans pub et sans tracking.';

  @override
  String get thanksBadge => '✨ Supporter';

  @override
  String get thanksCta => 'Avec plaisir';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonValidate => 'Valider';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get authAddSource => 'Ajouter une source';

  @override
  String get welcomeTagline => 'Votre lecteur IPTV, en clair.';

  @override
  String get welcomeTryDemo => 'Essayer la démo';

  @override
  String get welcomeHaveSource => 'J\'ai déjà une source configurée';

  @override
  String get welcomeLegal =>
      'Cette application ne fournit aucun contenu. Elle lit vos playlists ou identifiants IPTV existants.';

  @override
  String get sourceTypeXtream => 'Xtream / Portail';

  @override
  String get sourceTypeXtreamSub => 'Host + identifiants';

  @override
  String get sourceTypeM3u => 'Playlist M3U';

  @override
  String get sourceTypeM3uSub => 'URL de playlist (chaînes en direct)';

  @override
  String get formSourceName => 'Nom de la source';

  @override
  String get xtreamNameHint => 'Mon abonnement';

  @override
  String get xtreamHost => 'URL / Host';

  @override
  String get xtreamUsername => 'Nom d\'utilisateur';

  @override
  String get xtreamUsernameHint => 'utilisateur';

  @override
  String get commonPassword => 'Mot de passe';

  @override
  String get xtreamHint =>
      'Ces informations sont fournies par votre opérateur IPTV.';

  @override
  String get m3uNameHint => 'Ma playlist';

  @override
  String get m3uUrl => 'URL M3U';

  @override
  String get m3uUrlHint => 'Lien direct vers votre fichier .m3u / .m3u8';

  @override
  String get m3uEpgUrl => 'URL EPG (optionnel)';

  @override
  String get m3uHint =>
      'Le M3U fournit les chaînes en direct. Les films et séries nécessitent un portail Xtream.';

  @override
  String get summaryTitle => 'Résumé';

  @override
  String get summaryName => 'Nom';

  @override
  String get summaryHost => 'Host';

  @override
  String get summaryUser => 'Utilisateur';

  @override
  String get sourcesEmptyTitle => 'Aucune source';

  @override
  String get sourcesEmptyMessage =>
      'Ajoutez une source IPTV pour commencer à regarder.';

  @override
  String get connectingLabel => 'Connexion à la source…';

  @override
  String get connectingErrorTitle => 'Connexion impossible';

  @override
  String get successTitle => 'Source connectée';

  @override
  String get successDiscover => 'Découvrir';

  @override
  String successCounts(Object channels, Object movies, Object series) {
    return '$channels chaînes · $movies films · $series séries';
  }

  @override
  String get successEpgUnavailable => 'EPG indisponible pour cette source.';
}
