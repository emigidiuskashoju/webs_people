plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // ============================================================
    // GOOGLE SERVICES PLUGIN (FCM)
    // ============================================================
    //
    // Reads android/app/google-services.json and generates the
    // Firebase configuration used at runtime.
    // ============================================================
    id("com.google.gms.google-services")
}

android {
    namespace = "com.liko.webs"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications for Java 8+ APIs
        // (java.time.*) that are backported to older Android versions.
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.liko.webs"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backports java.time.* and other Java 8+ APIs so that
    // flutter_local_notifications can run on all supported
    // Android versions.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}