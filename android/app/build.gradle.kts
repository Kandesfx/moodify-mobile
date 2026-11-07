plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.moodify.moodify_flutter"
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
        // Development identity. Production app ID and signing remain a release decision.
        applicationId = "dev.moodify.moodify_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        resValue("string", "facebook_app_id", providers.gradleProperty("facebookAppId").orElse("0").get())
        resValue("string", "facebook_client_token", providers.gradleProperty("facebookClientToken").orElse("unconfigured").get())
        resValue("string", "fb_login_protocol_scheme", "fb" + providers.gradleProperty("facebookAppId").orElse("0").get())
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Release signing must be configured with the production identity before distribution.
        }
    }
}

flutter {
    source = "../.."
}
