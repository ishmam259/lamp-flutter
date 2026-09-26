import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lamp.bcolbd.lamp_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lamp.bcolbd.lamp_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The shared release key. `android/key.properties` (git-ignored) points at
    // the keystore; see docs/FIREBASE_SETUP.md. Google sign-in only works from
    // builds signed with a key whose fingerprint is registered in Firebase, so
    // every release APK, from any PC, must be signed with this one.
    val keyProps = Properties()
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) keyPropsFile.inputStream().use { keyProps.load(it) }
    val hasReleaseKey = keyProps.getProperty("storeFile")?.let { file(it).exists() } == true

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without the key file (a fresh checkout) fall back to the debug key so
            // `flutter run --release` still builds. Such an APK will NOT sign in
            // with Google on other people's phones unless its fingerprint is
            // registered, so never hand one out.
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

// Kotlin 2.2+ replaced `android { kotlinOptions { jvmTarget = ... } }`, which is
// now an error, with this. Same meaning: compile to Java 11.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

// Firebase. `flutterfire configure` writes google-services.json next to this
// file. Without it the build still succeeds (a debug build then runs on the
// local sign-in stand-in); with it, the plugin wires the Firebase project and
// the Google sign-in client id into the app.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
