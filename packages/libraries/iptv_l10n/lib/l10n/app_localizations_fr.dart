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
  String get typeOnPhone => 'Saisir depuis le téléphone';

  @override
  String get typeOnPhoneHint =>
      'Le plus rapide — scannez un code et saisissez sur votre téléphone';

  @override
  String get orEnterManually => 'ou saisir manuellement';

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

  @override
  String get commonCancel => 'Annuler';

  @override
  String get settingsPlayback => 'Lecture';

  @override
  String get playbackAutoplayNext => 'Lecture auto de l\'épisode suivant';

  @override
  String get playbackVolumeGesture => 'Geste vertical pour le volume';

  @override
  String get settingsSubtitlesAudio => 'Sous-titres & audio';

  @override
  String get audioPreferredLanguage => 'Langue audio préférée';

  @override
  String get subtitlePreferredLanguage => 'Langue des sous-titres préférée';

  @override
  String get subtitlesEnableDefault => 'Activer les sous-titres par défaut';

  @override
  String get subtitleSize => 'Taille des sous-titres';

  @override
  String get subtitleTextColor => 'Couleur du texte';

  @override
  String get subtitleBackground => 'Fond des sous-titres';

  @override
  String get subtitlesHint =>
      'Les préférences s\'appliquent à l\'ouverture du flux suivant.';

  @override
  String get langNone => 'Aucune';

  @override
  String get subSizeSmall => 'Petit';

  @override
  String get subSizeNormal => 'Normal';

  @override
  String get subSizeLarge => 'Grand';

  @override
  String get subSizeXLarge => 'Très grand';

  @override
  String get colorWhite => 'Blanc';

  @override
  String get colorYellow => 'Jaune';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorGreen => 'Vert';

  @override
  String get bgNone => 'Aucun';

  @override
  String get bgMedium => 'Moyen';

  @override
  String get bgOpaque => 'Opaque';

  @override
  String get settingsParental => 'Contrôle parental';

  @override
  String get parentalHideAdult => 'Masquer les catégories adultes';

  @override
  String get parentalLock => 'Verrouiller le contenu adulte';

  @override
  String get parentalUnlock => 'Déverrouiller le contenu adulte';

  @override
  String get parentalChangePin => 'Modifier le code';

  @override
  String parentalHint(int n) {
    return 'Protégé par un code à $n chiffres. Le contenu se reverrouille à chaque démarrage.';
  }

  @override
  String get parentalSetPin => 'Définir un code';

  @override
  String get parentalEnterPin => 'Entrez le code';

  @override
  String get parentalEnabledToast => 'Contrôle parental activé';

  @override
  String get parentalWrongPin => 'Code incorrect';

  @override
  String get parentalUnlockedToast => 'Contenu adulte déverrouillé';

  @override
  String get parentalCurrentPin => 'Code actuel';

  @override
  String get parentalNewPin => 'Nouveau code';

  @override
  String get parentalChangedToast => 'Code modifié';

  @override
  String get commonAll => 'Tous';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonMore => 'Plus';

  @override
  String get commonLess => 'Moins';

  @override
  String get commonWatch => 'Regarder';

  @override
  String get commonPlay => 'Lire';

  @override
  String get liveEmptyTitle => 'Aucune chaîne';

  @override
  String get liveEmptyMessage => 'Cette catégorie ne contient aucune chaîne.';

  @override
  String get guideUnavailableTitle => 'Guide indisponible';

  @override
  String get guideUnavailableMessage => 'Aucune donnée EPG pour cette source.';

  @override
  String get vodEmptyTitle => 'Aucun film';

  @override
  String get vodEmptyMessage => 'Aucun film dans cette source.';

  @override
  String get seriesEmptyTitle => 'Aucune série';

  @override
  String get seriesEmptyMessage => 'Aucune série dans cette source.';

  @override
  String get seriesNoEpisodes => 'Aucun épisode disponible.';

  @override
  String episodeLabel(int n) {
    return 'Épisode $n';
  }

  @override
  String get errNetwork => 'Pas de connexion Internet. Vérifiez votre réseau.';

  @override
  String errServer(int code) {
    return 'Erreur serveur ($code). Réessayez plus tard.';
  }

  @override
  String get errNotFound => 'Le contenu demandé est introuvable.';

  @override
  String get errUnexpected => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get errInvalidPlaylist =>
      'Cette playlist n\'a pas pu être lue. Vérifiez la source.';

  @override
  String get errPortalAuth => 'Connexion échouée. Vérifiez vos identifiants.';

  @override
  String get errStreamUnavailable => 'Ce flux est actuellement indisponible.';

  @override
  String get errEpgUnavailable =>
      'Le guide TV n\'a pas pu être chargé pour le moment.';

  @override
  String get errCastUnavailable =>
      'Aucun appareil de diffusion trouvé. Vérifiez votre Wi-Fi.';

  @override
  String get errCastConnection =>
      'Connexion à l\'appareil impossible. Réessayez.';

  @override
  String get playerLive => 'DIRECT';

  @override
  String get playerChannels => 'Chaînes';

  @override
  String get playerEpisodes => 'Épisodes';

  @override
  String get playerTracks => 'Pistes';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Sous-titres';

  @override
  String get playerSubtitlesOff => 'Désactivés';

  @override
  String get playerSync => 'Synchronisation';

  @override
  String playerTrackFallback(String id) {
    return 'Piste $id';
  }

  @override
  String get playerError => 'Lecture impossible';

  @override
  String get castTo => 'Diffuser sur';

  @override
  String get castingOn => 'Diffusion sur';

  @override
  String get castUnavailableTitle => 'Diffusion indisponible';

  @override
  String get castDiscovering => 'Recherche d\'appareils…';

  @override
  String nextEpisodeIn(int seconds) {
    return 'Épisode suivant dans ${seconds}s';
  }

  @override
  String get onboardingSyncConnecting => 'Connexion à la source…';

  @override
  String get onboardingSyncLive => 'Récupération des chaînes…';

  @override
  String get onboardingSyncVod => 'Récupération des films…';

  @override
  String get onboardingSyncSeries => 'Récupération des séries…';

  @override
  String get onboardingSyncEpg => 'Chargement du guide TV…';

  @override
  String get onboardingSyncDone => 'Terminé';

  @override
  String get onboardingSyncFailed => 'Échec de la synchronisation';

  @override
  String onboardingSyncStepOf(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get onboardingPasteLink => 'Coller un lien';

  @override
  String get onboardingPasteLinkReviewSub =>
      'Colle l\'adresse complète de ta liste M3U ou de ton portail Xtream : on remplit le formulaire, tu vérifies.';

  @override
  String get onboardingPasteInvalid =>
      'Ce lien n\'est pas reconnu. Vérifie qu\'il commence par http.';

  @override
  String get onboardingNameOptional => 'Facultatif';

  @override
  String get onboardingErrorRequired => 'Ce champ est requis.';

  @override
  String get onboardingErrorInvalidUrl =>
      'Cette adresse n\'est pas valide. Elle doit commencer par http.';

  @override
  String get onboardingXtreamUrlPlaceholder => 'http://monportail.tv:8080';

  @override
  String get onboardingM3uUrlPlaceholder => 'http://exemple.com/playlist.m3u';

  @override
  String get onboardingEpgUrlPlaceholder => 'http://exemple.com/guide.xml';

  @override
  String get onboardingPairingStarting => 'Démarrage…';

  @override
  String get onboardingPairingTitle => 'Saisis sur ton téléphone';

  @override
  String get onboardingPairingScan =>
      'Scanne ce code avec l\'appareil photo de ton téléphone, puis saisis-y les infos de ta source.';

  @override
  String get onboardingPairingConnected =>
      'Téléphone connecté : saisis et touche Envoyer';

  @override
  String get onboardingPairingWaiting => 'En attente de ton téléphone…';

  @override
  String get onboardingPairingReceived => 'Reçu depuis ton téléphone';

  @override
  String get onboardingPairingFill => 'Remplir le formulaire';

  @override
  String get onboardingPairingFailedTitle =>
      'Impossible de lancer l\'appairage';

  @override
  String get onboardingPairingFailedMessage =>
      'Vérifie que cet appareil est connecté au Wi-Fi puis réessaie, ou saisis tes infos avec la télécommande.';

  @override
  String get onboardingClose => 'Fermer';

  @override
  String get sourcesAddTooltip => 'Ajouter une source';

  @override
  String get sourcesActive => 'Active';

  @override
  String get sourcesActivateHint => 'Passer sur cette source';

  @override
  String get sourcesMenuTooltip => 'Options de la source';

  @override
  String get sourcesTypeDemo => 'Démo';

  @override
  String get sourcesRename => 'Renommer';

  @override
  String get sourcesRenameTitle => 'Renommer la source';

  @override
  String get sourcesRenameSave => 'Enregistrer';

  @override
  String get sourcesDelete => 'Supprimer';

  @override
  String get sourcesDeleteTitle => 'Supprimer cette source ?';

  @override
  String sourcesDeleteMessage(String name) {
    return '« $name » sera retirée de cet appareil.';
  }

  @override
  String sourcesDeleteActiveMessage(String name) {
    return '« $name » est ta source active : l’app passera sur une autre source.';
  }

  @override
  String get sourcesRefresh => 'Actualiser le catalogue';

  @override
  String get sourcesSyncBusy =>
      'Une synchronisation est en cours. Réessaie dans un instant.';

  @override
  String get sourcesRenameBlank => 'Le nom ne peut pas être vide.';

  @override
  String sourcesSwitched(String name) {
    return 'Source active : $name';
  }
}
