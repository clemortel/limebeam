import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // kotlin-android is intentionally absent: Flutter's Built-in Kotlin applies
    // it automatically to avoid conflicts with plugins that also apply KGP
    // (wakelock_plus, flutter_chrome_cast, package_info_plus).
    // See: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is loaded from `android/key.properties` (kept out of source
// control). When the file is absent we fall back to debug keys so that
// `flutter run --release` still works locally.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.limebeam.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.limebeam.app"
        // Google Cast framework (flutter_chrome_cast) requires API 24+; raise
        // the floor above Flutter's default when it would be lower.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Impeller renderer toggle, injected into AndroidManifest's
        // EnableImpeller meta-data. Default on (avoids Skia's EGLImage raster
        // cost on the Fire TV Stick PowerVR GE8300). To A/B against Skia, set
        // `enableImpeller=false` in android/gradle.properties (or pass
        // `-PenableImpeller=false`) and rebuild. See tool/perf/README.md.
        manifestPlaceholders["enableImpeller"] =
            (project.findProperty("enableImpeller") as String?) ?: "true"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ExoPlayer (androidx.media3): backs the SurfaceView video engine used for
    // LIVE playback on Android TV. A SurfaceView is composited by SurfaceFlinger
    // as a hardware overlay, so the app GPU never composites video frames —
    // which is what lets a weak Fire TV Stick present 50/60fps live without
    // dropping frames (the libmpv texture path cannot). VOD + phones stay on
    // media_kit. -exoplayer-hls covers HLS live variants; core handles MPEG-TS.
    val media3Version = "1.5.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-common:$media3Version")
}
