plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ✅ Correct plugin ID for Kotlin 2.1.0
    id("com.google.gms.google-services") // ✅ Firebase
    id("dev.flutter.flutter-gradle-plugin") // ✅ Flutter plugin
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.example.rwapros"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
            isCoreLibraryDesugaringEnabled = true
        }

    kotlin {
        jvmToolchain(17)
        }

    defaultConfig {
        applicationId = "com.example.rwapros"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ✅ Firebase BoM – ensures all Firebase libs are version-compatible
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))

    // ✅ Firebase SDKs
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")
}

flutter {
    source = "../.."
}
