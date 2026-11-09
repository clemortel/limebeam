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

  @override
  String get commonContinue => 'Continue';

  @override
  String get typeOnPhone => 'Type on your phone';

  @override
  String get typeOnPhoneHint => 'Fastest — scan a code and type on your phone';

  @override
  String get orEnterManually => 'or enter manually';

  @override
  String get commonValidate => 'Confirm';

  @override
  String get commonEdit => 'Edit';

  @override
  String get authAddSource => 'Add a source';

  @override
  String get welcomeTagline => 'Your IPTV player, in the clear.';

  @override
  String get welcomeTryDemo => 'Try the demo';

  @override
  String get welcomeHaveSource => 'I already have a source';

  @override
  String get welcomeLegal =>
      'This app provides no content. It reads your existing IPTV playlists or credentials.';

  @override
  String get sourceTypeXtream => 'Xtream / Portal';

  @override
  String get sourceTypeXtreamSub => 'Host + credentials';

  @override
  String get sourceTypeM3u => 'M3U playlist';

  @override
  String get sourceTypeM3uSub => 'Playlist URL (live channels)';

  @override
  String get formSourceName => 'Source name';

  @override
  String get xtreamNameHint => 'My subscription';

  @override
  String get xtreamHost => 'URL / Host';

  @override
  String get xtreamUsername => 'Username';

  @override
  String get xtreamUsernameHint => 'username';

  @override
  String get commonPassword => 'Password';

  @override
  String get xtreamHint => 'Your IPTV provider gives you these details.';

  @override
  String get m3uNameHint => 'My playlist';

  @override
  String get m3uUrl => 'M3U URL';

  @override
  String get m3uUrlHint => 'Direct link to your .m3u / .m3u8 file';

  @override
  String get m3uEpgUrl => 'EPG URL (optional)';

  @override
  String get m3uHint =>
      'M3U provides live channels. Movies and series require an Xtream portal.';

  @override
  String get summaryTitle => 'Summary';

  @override
  String get summaryName => 'Name';

  @override
  String get summaryHost => 'Host';

  @override
  String get summaryUser => 'User';

  @override
  String get sourcesEmptyTitle => 'No source';

  @override
  String get sourcesEmptyMessage => 'Add an IPTV source to start watching.';

  @override
  String get connectingLabel => 'Connecting to the source…';

  @override
  String get connectingErrorTitle => 'Connection failed';

  @override
  String get successTitle => 'Source connected';

  @override
  String get successDiscover => 'Explore';

  @override
  String successCounts(Object channels, Object movies, Object series) {
    return '$channels channels · $movies movies · $series series';
  }

  @override
  String get successEpgUnavailable => 'EPG unavailable for this source.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get playbackAutoplayNext => 'Auto-play next episode';

  @override
  String get playbackVolumeGesture => 'Vertical swipe for volume';

  @override
  String get settingsSubtitlesAudio => 'Subtitles & audio';

  @override
  String get audioPreferredLanguage => 'Preferred audio language';

  @override
  String get subtitlePreferredLanguage => 'Preferred subtitle language';

  @override
  String get subtitlesEnableDefault => 'Enable subtitles by default';

  @override
  String get subtitleSize => 'Subtitle size';

  @override
  String get subtitleTextColor => 'Text color';

  @override
  String get subtitleBackground => 'Subtitle background';

  @override
  String get subtitlesHint => 'Preferences apply when the next stream opens.';

  @override
  String get langNone => 'None';

  @override
  String get subSizeSmall => 'Small';

  @override
  String get subSizeNormal => 'Normal';

  @override
  String get subSizeLarge => 'Large';

  @override
  String get subSizeXLarge => 'Extra large';

  @override
  String get colorWhite => 'White';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorCyan => 'Cyan';

  @override
  String get colorGreen => 'Green';

  @override
  String get bgNone => 'None';

  @override
  String get bgMedium => 'Medium';

  @override
  String get bgOpaque => 'Opaque';

  @override
  String get settingsParental => 'Parental control';

  @override
  String get parentalHideAdult => 'Hide adult categories';

  @override
  String get parentalLock => 'Lock adult content';

  @override
  String get parentalUnlock => 'Unlock adult content';

  @override
  String get parentalChangePin => 'Change PIN';

  @override
  String parentalHint(int n) {
    return 'Protected by a $n-digit PIN. Content re-locks on each launch.';
  }

  @override
  String get parentalSetPin => 'Set a PIN';

  @override
  String get parentalEnterPin => 'Enter the PIN';

  @override
  String get parentalEnabledToast => 'Parental control enabled';

  @override
  String get parentalWrongPin => 'Wrong PIN';

  @override
  String get parentalUnlockedToast => 'Adult content unlocked';

  @override
  String get parentalCurrentPin => 'Current PIN';

  @override
  String get parentalNewPin => 'New PIN';

  @override
  String get parentalChangedToast => 'PIN changed';

  @override
  String get commonAll => 'All';

  @override
  String get commonError => 'Error';

  @override
  String get commonMore => 'More';

  @override
  String get commonLess => 'Less';

  @override
  String get commonWatch => 'Watch';

  @override
  String get commonPlay => 'Play';

  @override
  String get liveEmptyTitle => 'No channel';

  @override
  String get liveEmptyMessage => 'This category has no channels.';

  @override
  String get guideUnavailableTitle => 'Guide unavailable';

  @override
  String get guideUnavailableMessage => 'No EPG data for this source.';

  @override
  String get vodEmptyTitle => 'No movie';

  @override
  String get vodEmptyMessage => 'No movies in this source.';

  @override
  String get seriesEmptyTitle => 'No series';

  @override
  String get seriesEmptyMessage => 'No series in this source.';

  @override
  String get seriesNoEpisodes => 'No episodes available.';

  @override
  String episodeLabel(int n) {
    return 'Episode $n';
  }

  @override
  String get errNetwork => 'No internet connection. Check your network.';

  @override
  String errServer(int code) {
    return 'Server error ($code). Try again later.';
  }

  @override
  String get errNotFound => 'The requested content was not found.';

  @override
  String get errUnexpected => 'Something went wrong. Please try again.';

  @override
  String get errInvalidPlaylist =>
      'This playlist could not be read. Check the source.';

  @override
  String get errPortalAuth => 'Login failed. Check your portal credentials.';

  @override
  String get errStreamUnavailable => 'This stream is currently unavailable.';

  @override
  String get errEpgUnavailable => 'The TV guide could not be loaded right now.';

  @override
  String get errCastUnavailable =>
      'No cast devices found. Check your Wi-Fi network.';

  @override
  String get errCastConnection =>
      'Could not connect to the cast device. Try again.';

  @override
  String get playerLive => 'LIVE';

  @override
  String get playerChannels => 'Channels';

  @override
  String get playerEpisodes => 'Episodes';

  @override
  String get playerTracks => 'Tracks';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSubtitlesOff => 'Off';

  @override
  String get playerSync => 'Sync';

  @override
  String playerTrackFallback(String id) {
    return 'Track $id';
  }

  @override
  String get playerError => 'Playback failed';

  @override
  String get castTo => 'Cast to';

  @override
  String get castingOn => 'Casting to';

  @override
  String get castUnavailableTitle => 'Casting unavailable';

  @override
  String get castDiscovering => 'Searching for devices…';

  @override
  String nextEpisodeIn(int seconds) {
    return 'Next episode in ${seconds}s';
  }

  @override
  String get onboardingSyncConnecting => 'Connecting to the source…';

  @override
  String get onboardingSyncLive => 'Fetching channels…';

  @override
  String get onboardingSyncVod => 'Fetching movies…';

  @override
  String get onboardingSyncSeries => 'Fetching series…';

  @override
  String get onboardingSyncEpg => 'Loading the TV guide…';

  @override
  String get onboardingSyncDone => 'Done';

  @override
  String get onboardingSyncFailed => 'Sync failed';

  @override
  String onboardingSyncStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingPasteLink => 'Paste a link';

  @override
  String get onboardingPasteLinkReviewSub =>
      'Paste the full address of your M3U list or Xtream portal. We\'ll fill the form in for you to check.';

  @override
  String get onboardingPasteInvalid =>
      'This link isn\'t recognised. Check that it starts with http.';

  @override
  String get onboardingNameOptional => 'Optional';

  @override
  String get onboardingErrorRequired => 'This field is required.';

  @override
  String get onboardingErrorInvalidUrl =>
      'This address isn\'t valid. It must start with http.';

  @override
  String get onboardingXtreamUrlPlaceholder => 'http://myportal.tv:8080';

  @override
  String get onboardingM3uUrlPlaceholder => 'http://example.com/playlist.m3u';

  @override
  String get onboardingEpgUrlPlaceholder => 'http://example.com/guide.xml';

  @override
  String get onboardingPairingStarting => 'Starting…';

  @override
  String get onboardingPairingTitle => 'Type on your phone';

  @override
  String get onboardingPairingScan =>
      'Scan this code with your phone camera, then type your source details there.';

  @override
  String get onboardingPairingConnected => 'Phone connected: type and tap Send';

  @override
  String get onboardingPairingWaiting => 'Waiting for your phone…';

  @override
  String get onboardingPairingReceived => 'Received from your phone';

  @override
  String get onboardingPairingFill => 'Fill the form';

  @override
  String get onboardingPairingFailedTitle => 'Can\'t start phone pairing';

  @override
  String get onboardingPairingFailedMessage =>
      'Make sure this device is on Wi-Fi, then try again, or enter your details with the remote.';

  @override
  String get onboardingClose => 'Close';

  @override
  String get sourcesAddTooltip => 'Add a source';

  @override
  String get sourcesActive => 'Active';

  @override
  String get sourcesActivateHint => 'Switch to this source';

  @override
  String get sourcesMenuTooltip => 'Source options';

  @override
  String get sourcesTypeDemo => 'Demo';

  @override
  String get sourcesRename => 'Rename';

  @override
  String get sourcesRenameTitle => 'Rename the source';

  @override
  String get sourcesRenameSave => 'Save';

  @override
  String get sourcesDelete => 'Delete';

  @override
  String get sourcesDeleteTitle => 'Delete this source?';

  @override
  String sourcesDeleteMessage(String name) {
    return '\"$name\" will be removed from this device.';
  }

  @override
  String sourcesDeleteActiveMessage(String name) {
    return '\"$name\" is your active source: the app will switch to another one.';
  }

  @override
  String sourcesDeleteLastMessage(String name) {
    return '\"$name\" is your only source: after deleting it you will need to add a new one.';
  }

  @override
  String get sourcesRefresh => 'Refresh catalog';

  @override
  String get sourcesSyncBusy => 'A sync is in progress. Try again in a moment.';

  @override
  String get sourcesRenameBlank => 'The name can\'t be empty.';

  @override
  String sourcesSwitched(String name) {
    return 'Active source: $name';
  }
}
