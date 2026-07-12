plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.torrentmusic.torrent_music"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.torrentmusic.torrent_music"
        // libtorrent4j (LibreTorrent engine) requires API 24+
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    val libtorrentVersion = "2.1.0-39"
    implementation("org.libtorrent4j:libtorrent4j:$libtorrentVersion")
    implementation("org.libtorrent4j:libtorrent4j-android-arm:$libtorrentVersion")
    implementation("org.libtorrent4j:libtorrent4j-android-arm64:$libtorrentVersion")
    implementation("org.libtorrent4j:libtorrent4j-android-x86:$libtorrentVersion")
    implementation("org.libtorrent4j:libtorrent4j-android-x86_64:$libtorrentVersion")
}
