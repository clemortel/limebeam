import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @tabHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get tabHome;

  /// No description provided for @tabTv.
  ///
  /// In fr, this message translates to:
  /// **'TV'**
  String get tabTv;

  /// No description provided for @tabBrowse.
  ///
  /// In fr, this message translates to:
  /// **'Films & Séries'**
  String get tabBrowse;

  /// No description provided for @tabSearch.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get tabSearch;

  /// No description provided for @tabSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get tabSettings;

  /// No description provided for @homeResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get homeResume;

  /// No description provided for @homeFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get homeFavorites;

  /// No description provided for @homePopularMovies.
  ///
  /// In fr, this message translates to:
  /// **'Films populaires'**
  String get homePopularMovies;

  /// No description provided for @homePopularSeries.
  ///
  /// In fr, this message translates to:
  /// **'Séries populaires'**
  String get homePopularSeries;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien à afficher'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vos chaînes et contenus apparaîtront ici après la synchronisation de votre source.'**
  String get homeEmptyMessage;

  /// No description provided for @browseMovies.
  ///
  /// In fr, this message translates to:
  /// **'Films'**
  String get browseMovies;

  /// No description provided for @browseSeries.
  ///
  /// In fr, this message translates to:
  /// **'Séries'**
  String get browseSeries;

  /// No description provided for @searchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get searchTitle;

  /// No description provided for @searchPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher chaînes, films, séries…'**
  String get searchPlaceholder;

  /// No description provided for @searchPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get searchPrompt;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu ne correspond à votre recherche.'**
  String get searchEmptyMessage;

  /// No description provided for @settingsSources.
  ///
  /// In fr, this message translates to:
  /// **'Sources'**
  String get settingsSources;

  /// No description provided for @settingsSupport.
  ///
  /// In fr, this message translates to:
  /// **'Soutenir le développeur'**
  String get settingsSupport;

  /// No description provided for @settingsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get settingsAbout;

  /// No description provided for @aboutTitle.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get aboutTitle;

  /// No description provided for @aboutNoContent.
  ///
  /// In fr, this message translates to:
  /// **'LimeBeam ne fournit aucun contenu. L\'application lit vos playlists ou identifiants IPTV existants.'**
  String get aboutNoContent;

  /// No description provided for @aboutPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée n\'est collectée. Vos identifiants, favoris et historique restent sur votre appareil.'**
  String get aboutPrivacy;

  /// No description provided for @aboutLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences open-source'**
  String get aboutLicenses;

  /// No description provided for @aboutVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version {version} ({build})'**
  String aboutVersion(Object version, Object build);

  /// No description provided for @aboutVersionLoading.
  ///
  /// In fr, this message translates to:
  /// **'Version…'**
  String get aboutVersionLoading;

  /// No description provided for @searchPromptMessage.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez une chaîne, un film ou une série dans vos sources.'**
  String get searchPromptMessage;

  /// No description provided for @settingsInterface.
  ///
  /// In fr, this message translates to:
  /// **'Interface'**
  String get settingsInterface;

  /// No description provided for @settingsTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @settingsFontSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille du texte'**
  String get settingsFontSize;

  /// No description provided for @fontNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get fontNormal;

  /// No description provided for @fontLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grande'**
  String get fontLarge;

  /// No description provided for @settingsReduceTransparency.
  ///
  /// In fr, this message translates to:
  /// **'Réduire la transparence'**
  String get settingsReduceTransparency;

  /// No description provided for @settingsReduceTransparencyHint.
  ///
  /// In fr, this message translates to:
  /// **'Désactive les effets de verre pour des surfaces plus lisibles.'**
  String get settingsReduceTransparencyHint;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get languageSystem;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @donateIntroTitle.
  ///
  /// In fr, this message translates to:
  /// **'Soutenir LimeBeam'**
  String get donateIntroTitle;

  /// No description provided for @donateIntroBody.
  ///
  /// In fr, this message translates to:
  /// **'LimeBeam est entièrement gratuit, sans pub ni tracking. Je développe l\'app sur mon temps libre pour un player IPTV propre, rapide et agréable.\n\nSi tu veux m\'aider à continuer, tu peux laisser un pourboire ci-dessous. Merci ❤️'**
  String get donateIntroBody;

  /// No description provided for @donateSoonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt'**
  String get donateSoonTitle;

  /// No description provided for @donateSoonMessage.
  ///
  /// In fr, this message translates to:
  /// **'Les pourboires seront disponibles très vite.'**
  String get donateSoonMessage;

  /// No description provided for @donateErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get donateErrorTitle;

  /// No description provided for @donateErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les options de soutien pour l\'instant.'**
  String get donateErrorMessage;

  /// No description provided for @donateCardCta.
  ///
  /// In fr, this message translates to:
  /// **'Soutenir'**
  String get donateCardCta;

  /// No description provided for @donatePopular.
  ///
  /// In fr, this message translates to:
  /// **'Populaire'**
  String get donatePopular;

  /// No description provided for @donateLegalFooter.
  ///
  /// In fr, this message translates to:
  /// **'Les pourboires sont des achats intégrés. Ils ne débloquent aucun contenu : c\'est simplement un soutien au développement.'**
  String get donateLegalFooter;

  /// No description provided for @donatePurchaseError.
  ///
  /// In fr, this message translates to:
  /// **'Achat impossible. Réessaie plus tard.'**
  String get donatePurchaseError;

  /// No description provided for @tipPromptTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu aimes LimeBeam ?'**
  String get tipPromptTitle;

  /// No description provided for @tipPromptBody.
  ///
  /// In fr, this message translates to:
  /// **'LimeBeam est gratuit, sans pub et sans tracking. Si l\'app te simplifie la vie, tu peux m\'offrir un café pour soutenir le dev ☕.'**
  String get tipPromptBody;

  /// No description provided for @tipPromptSupport.
  ///
  /// In fr, this message translates to:
  /// **'Soutenir LimeBeam'**
  String get tipPromptSupport;

  /// No description provided for @tipPromptLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get tipPromptLater;

  /// No description provided for @thanksTitle.
  ///
  /// In fr, this message translates to:
  /// **'Merci ❤️'**
  String get thanksTitle;

  /// No description provided for @thanksBody.
  ///
  /// In fr, this message translates to:
  /// **'Ton soutien fait vraiment la différence. Grâce à toi, LimeBeam continue d\'avancer — gratuit, sans pub et sans tracking.'**
  String get thanksBody;

  /// No description provided for @thanksBadge.
  ///
  /// In fr, this message translates to:
  /// **'✨ Supporter'**
  String get thanksBadge;

  /// No description provided for @thanksCta.
  ///
  /// In fr, this message translates to:
  /// **'Avec plaisir'**
  String get thanksCta;

  /// No description provided for @commonContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonContinue;

  /// No description provided for @typeOnPhone.
  ///
  /// In fr, this message translates to:
  /// **'Saisir depuis le téléphone'**
  String get typeOnPhone;

  /// No description provided for @typeOnPhoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Le plus rapide — scannez un code et saisissez sur votre téléphone'**
  String get typeOnPhoneHint;

  /// No description provided for @orEnterManually.
  ///
  /// In fr, this message translates to:
  /// **'ou saisir manuellement'**
  String get orEnterManually;

  /// No description provided for @commonValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get commonValidate;

  /// No description provided for @commonEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// No description provided for @authAddSource.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une source'**
  String get authAddSource;

  /// No description provided for @welcomeTagline.
  ///
  /// In fr, this message translates to:
  /// **'Votre lecteur IPTV, en clair.'**
  String get welcomeTagline;

  /// No description provided for @welcomeTryDemo.
  ///
  /// In fr, this message translates to:
  /// **'Essayer la démo'**
  String get welcomeTryDemo;

  /// No description provided for @welcomeHaveSource.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà une source configurée'**
  String get welcomeHaveSource;

  /// No description provided for @welcomeLegal.
  ///
  /// In fr, this message translates to:
  /// **'Cette application ne fournit aucun contenu. Elle lit vos playlists ou identifiants IPTV existants.'**
  String get welcomeLegal;

  /// No description provided for @sourceTypeXtream.
  ///
  /// In fr, this message translates to:
  /// **'Xtream / Portail'**
  String get sourceTypeXtream;

  /// No description provided for @sourceTypeXtreamSub.
  ///
  /// In fr, this message translates to:
  /// **'Host + identifiants'**
  String get sourceTypeXtreamSub;

  /// No description provided for @sourceTypeM3u.
  ///
  /// In fr, this message translates to:
  /// **'Playlist M3U'**
  String get sourceTypeM3u;

  /// No description provided for @sourceTypeM3uSub.
  ///
  /// In fr, this message translates to:
  /// **'URL de playlist (chaînes en direct)'**
  String get sourceTypeM3uSub;

  /// No description provided for @formSourceName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la source'**
  String get formSourceName;

  /// No description provided for @xtreamNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Mon abonnement'**
  String get xtreamNameHint;

  /// No description provided for @xtreamHost.
  ///
  /// In fr, this message translates to:
  /// **'URL / Host'**
  String get xtreamHost;

  /// No description provided for @xtreamUsername.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur'**
  String get xtreamUsername;

  /// No description provided for @xtreamUsernameHint.
  ///
  /// In fr, this message translates to:
  /// **'utilisateur'**
  String get xtreamUsernameHint;

  /// No description provided for @commonPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get commonPassword;

  /// No description provided for @xtreamHint.
  ///
  /// In fr, this message translates to:
  /// **'Ces informations sont fournies par votre opérateur IPTV.'**
  String get xtreamHint;

  /// No description provided for @m3uNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ma playlist'**
  String get m3uNameHint;

  /// No description provided for @m3uUrl.
  ///
  /// In fr, this message translates to:
  /// **'URL M3U'**
  String get m3uUrl;

  /// No description provided for @m3uUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'Lien direct vers votre fichier .m3u / .m3u8'**
  String get m3uUrlHint;

  /// No description provided for @m3uEpgUrl.
  ///
  /// In fr, this message translates to:
  /// **'URL EPG (optionnel)'**
  String get m3uEpgUrl;

  /// No description provided for @m3uHint.
  ///
  /// In fr, this message translates to:
  /// **'Le M3U fournit les chaînes en direct. Les films et séries nécessitent un portail Xtream.'**
  String get m3uHint;

  /// No description provided for @summaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Résumé'**
  String get summaryTitle;

  /// No description provided for @summaryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get summaryName;

  /// No description provided for @summaryHost.
  ///
  /// In fr, this message translates to:
  /// **'Host'**
  String get summaryHost;

  /// No description provided for @summaryUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get summaryUser;

  /// No description provided for @sourcesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune source'**
  String get sourcesEmptyTitle;

  /// No description provided for @sourcesEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez une source IPTV pour commencer à regarder.'**
  String get sourcesEmptyMessage;

  /// No description provided for @connectingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Connexion à la source…'**
  String get connectingLabel;

  /// No description provided for @connectingErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible'**
  String get connectingErrorTitle;

  /// No description provided for @successTitle.
  ///
  /// In fr, this message translates to:
  /// **'Source connectée'**
  String get successTitle;

  /// No description provided for @successDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get successDiscover;

  /// No description provided for @successCounts.
  ///
  /// In fr, this message translates to:
  /// **'{channels} chaînes · {movies} films · {series} séries'**
  String successCounts(Object channels, Object movies, Object series);

  /// No description provided for @successEpgUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'EPG indisponible pour cette source.'**
  String get successEpgUnavailable;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @settingsPlayback.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get settingsPlayback;

  /// No description provided for @playbackAutoplayNext.
  ///
  /// In fr, this message translates to:
  /// **'Lecture auto de l\'épisode suivant'**
  String get playbackAutoplayNext;

  /// No description provided for @playbackVolumeGesture.
  ///
  /// In fr, this message translates to:
  /// **'Geste vertical pour le volume'**
  String get playbackVolumeGesture;

  /// No description provided for @settingsSubtitlesAudio.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres & audio'**
  String get settingsSubtitlesAudio;

  /// No description provided for @audioPreferredLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue audio préférée'**
  String get audioPreferredLanguage;

  /// No description provided for @subtitlePreferredLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue des sous-titres préférée'**
  String get subtitlePreferredLanguage;

  /// No description provided for @subtitlesEnableDefault.
  ///
  /// In fr, this message translates to:
  /// **'Activer les sous-titres par défaut'**
  String get subtitlesEnableDefault;

  /// No description provided for @subtitleSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille des sous-titres'**
  String get subtitleSize;

  /// No description provided for @subtitleTextColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du texte'**
  String get subtitleTextColor;

  /// No description provided for @subtitleBackground.
  ///
  /// In fr, this message translates to:
  /// **'Fond des sous-titres'**
  String get subtitleBackground;

  /// No description provided for @subtitlesHint.
  ///
  /// In fr, this message translates to:
  /// **'Les préférences s\'appliquent à l\'ouverture du flux suivant.'**
  String get subtitlesHint;

  /// No description provided for @langNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get langNone;

  /// No description provided for @subSizeSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petit'**
  String get subSizeSmall;

  /// No description provided for @subSizeNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get subSizeNormal;

  /// No description provided for @subSizeLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grand'**
  String get subSizeLarge;

  /// No description provided for @subSizeXLarge.
  ///
  /// In fr, this message translates to:
  /// **'Très grand'**
  String get subSizeXLarge;

  /// No description provided for @colorWhite.
  ///
  /// In fr, this message translates to:
  /// **'Blanc'**
  String get colorWhite;

  /// No description provided for @colorYellow.
  ///
  /// In fr, this message translates to:
  /// **'Jaune'**
  String get colorYellow;

  /// No description provided for @colorCyan.
  ///
  /// In fr, this message translates to:
  /// **'Cyan'**
  String get colorCyan;

  /// No description provided for @colorGreen.
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get colorGreen;

  /// No description provided for @bgNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get bgNone;

  /// No description provided for @bgMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get bgMedium;

  /// No description provided for @bgOpaque.
  ///
  /// In fr, this message translates to:
  /// **'Opaque'**
  String get bgOpaque;

  /// No description provided for @settingsParental.
  ///
  /// In fr, this message translates to:
  /// **'Contrôle parental'**
  String get settingsParental;

  /// No description provided for @parentalHideAdult.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les catégories adultes'**
  String get parentalHideAdult;

  /// No description provided for @parentalLock.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller le contenu adulte'**
  String get parentalLock;

  /// No description provided for @parentalUnlock.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller le contenu adulte'**
  String get parentalUnlock;

  /// No description provided for @parentalChangePin.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le code'**
  String get parentalChangePin;

  /// No description provided for @parentalHint.
  ///
  /// In fr, this message translates to:
  /// **'Protégé par un code à {n} chiffres. Le contenu se reverrouille à chaque démarrage.'**
  String parentalHint(int n);

  /// No description provided for @parentalSetPin.
  ///
  /// In fr, this message translates to:
  /// **'Définir un code'**
  String get parentalSetPin;

  /// No description provided for @parentalEnterPin.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code'**
  String get parentalEnterPin;

  /// No description provided for @parentalEnabledToast.
  ///
  /// In fr, this message translates to:
  /// **'Contrôle parental activé'**
  String get parentalEnabledToast;

  /// No description provided for @parentalWrongPin.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect'**
  String get parentalWrongPin;

  /// No description provided for @parentalUnlockedToast.
  ///
  /// In fr, this message translates to:
  /// **'Contenu adulte déverrouillé'**
  String get parentalUnlockedToast;

  /// No description provided for @parentalCurrentPin.
  ///
  /// In fr, this message translates to:
  /// **'Code actuel'**
  String get parentalCurrentPin;

  /// No description provided for @parentalNewPin.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code'**
  String get parentalNewPin;

  /// No description provided for @parentalChangedToast.
  ///
  /// In fr, this message translates to:
  /// **'Code modifié'**
  String get parentalChangedToast;

  /// No description provided for @commonAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get commonAll;

  /// No description provided for @commonError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get commonError;

  /// No description provided for @commonMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get commonMore;

  /// No description provided for @commonLess.
  ///
  /// In fr, this message translates to:
  /// **'Moins'**
  String get commonLess;

  /// No description provided for @commonWatch.
  ///
  /// In fr, this message translates to:
  /// **'Regarder'**
  String get commonWatch;

  /// No description provided for @commonPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get commonPlay;

  /// No description provided for @liveEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune chaîne'**
  String get liveEmptyTitle;

  /// No description provided for @liveEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette catégorie ne contient aucune chaîne.'**
  String get liveEmptyMessage;

  /// No description provided for @guideUnavailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Guide indisponible'**
  String get guideUnavailableTitle;

  /// No description provided for @guideUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée EPG pour cette source.'**
  String get guideUnavailableMessage;

  /// No description provided for @vodEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun film'**
  String get vodEmptyTitle;

  /// No description provided for @vodEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun film dans cette source.'**
  String get vodEmptyMessage;

  /// No description provided for @seriesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune série'**
  String get seriesEmptyTitle;

  /// No description provided for @seriesEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune série dans cette source.'**
  String get seriesEmptyMessage;

  /// No description provided for @seriesNoEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun épisode disponible.'**
  String get seriesNoEpisodes;

  /// No description provided for @episodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Épisode {n}'**
  String episodeLabel(int n);

  /// No description provided for @errNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion Internet. Vérifiez votre réseau.'**
  String get errNetwork;

  /// No description provided for @errServer.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur ({code}). Réessayez plus tard.'**
  String errServer(int code);

  /// No description provided for @errNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Le contenu demandé est introuvable.'**
  String get errNotFound;

  /// No description provided for @errUnexpected.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get errUnexpected;

  /// No description provided for @errInvalidPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Cette playlist n\'a pas pu être lue. Vérifiez la source.'**
  String get errInvalidPlaylist;

  /// No description provided for @errPortalAuth.
  ///
  /// In fr, this message translates to:
  /// **'Connexion échouée. Vérifiez vos identifiants.'**
  String get errPortalAuth;

  /// No description provided for @errStreamUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Ce flux est actuellement indisponible.'**
  String get errStreamUnavailable;

  /// No description provided for @errEpgUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le guide TV n\'a pas pu être chargé pour le moment.'**
  String get errEpgUnavailable;

  /// No description provided for @errCastUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil de diffusion trouvé. Vérifiez votre Wi-Fi.'**
  String get errCastUnavailable;

  /// No description provided for @errCastConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion à l\'appareil impossible. Réessayez.'**
  String get errCastConnection;

  /// No description provided for @playerLive.
  ///
  /// In fr, this message translates to:
  /// **'DIRECT'**
  String get playerLive;

  /// No description provided for @playerChannels.
  ///
  /// In fr, this message translates to:
  /// **'Chaînes'**
  String get playerChannels;

  /// No description provided for @playerEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Épisodes'**
  String get playerEpisodes;

  /// No description provided for @playerTracks.
  ///
  /// In fr, this message translates to:
  /// **'Pistes'**
  String get playerTracks;

  /// No description provided for @playerAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get playerAudio;

  /// No description provided for @playerSubtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get playerSubtitles;

  /// No description provided for @playerSubtitlesOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivés'**
  String get playerSubtitlesOff;

  /// No description provided for @playerSync.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation'**
  String get playerSync;

  /// No description provided for @playerTrackFallback.
  ///
  /// In fr, this message translates to:
  /// **'Piste {id}'**
  String playerTrackFallback(String id);

  /// No description provided for @playerError.
  ///
  /// In fr, this message translates to:
  /// **'Lecture impossible'**
  String get playerError;

  /// No description provided for @castTo.
  ///
  /// In fr, this message translates to:
  /// **'Diffuser sur'**
  String get castTo;

  /// No description provided for @castingOn.
  ///
  /// In fr, this message translates to:
  /// **'Diffusion sur'**
  String get castingOn;

  /// No description provided for @castUnavailableTitle.
  ///
  /// In fr, this message translates to:
  /// **'Diffusion indisponible'**
  String get castUnavailableTitle;

  /// No description provided for @castDiscovering.
  ///
  /// In fr, this message translates to:
  /// **'Recherche d\'appareils…'**
  String get castDiscovering;

  /// No description provided for @nextEpisodeIn.
  ///
  /// In fr, this message translates to:
  /// **'Épisode suivant dans {seconds}s'**
  String nextEpisodeIn(int seconds);

  /// No description provided for @downloadsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get downloadsTitle;

  /// No description provided for @downloadsSeasonAction.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger la saison'**
  String get downloadsSeasonAction;

  /// No description provided for @downloadsSeasonProgress.
  ///
  /// In fr, this message translates to:
  /// **'{done}/{total}'**
  String downloadsSeasonProgress(int done, int total);

  /// No description provided for @downloadsSeasonDone.
  ///
  /// In fr, this message translates to:
  /// **'Saison téléchargée'**
  String get downloadsSeasonDone;

  /// No description provided for @downloadsEpisodeDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger l\'épisode'**
  String get downloadsEpisodeDownload;

  /// No description provided for @downloadsEpisodeQueued.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement en attente'**
  String get downloadsEpisodeQueued;

  /// No description provided for @downloadsEpisodeRunning.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement en cours, {percent} %'**
  String downloadsEpisodeRunning(int percent);

  /// No description provided for @downloadsEpisodeDone.
  ///
  /// In fr, this message translates to:
  /// **'Épisode téléchargé'**
  String get downloadsEpisodeDone;

  /// No description provided for @downloadsEpisodeRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer le téléchargement'**
  String get downloadsEpisodeRetry;

  /// No description provided for @downloadsRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get downloadsRemove;

  /// No description provided for @downloadsRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement ?'**
  String get downloadsRemoveTitle;

  /// No description provided for @downloadsRemoveMessage.
  ///
  /// In fr, this message translates to:
  /// **'L\'épisode ne sera plus disponible hors connexion.'**
  String get downloadsRemoveMessage;

  /// No description provided for @downloadsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun téléchargement'**
  String get downloadsEmptyTitle;

  /// No description provided for @downloadsEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez des épisodes depuis une fiche série pour les regarder sans connexion.'**
  String get downloadsEmptyMessage;

  /// No description provided for @downloadsSeasonHeader.
  ///
  /// In fr, this message translates to:
  /// **'Saison {n}'**
  String downloadsSeasonHeader(int n);

  /// No description provided for @downloadsPlayEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Lire {title}'**
  String downloadsPlayEpisode(String title);

  /// No description provided for @seriesOfflineBanner.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get seriesOfflineBanner;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
