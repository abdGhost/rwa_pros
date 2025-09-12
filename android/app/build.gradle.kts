plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")      // Kotlin plugin
    id("com.google.gms.google-services")    // Firebase
    id("dev.flutter.flutter-gradle-plugin") // Flutter
    id("com.google.firebase.crashlytics")   // Crashlytics
}

android {
    namespace = "com.example.rwapros"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.rwapros"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // ✅ Slim, Play-Store-ready release config
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // TODO: switch to your real release keystore before Play upload
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            // keeps debug builds fast; no shrink/minify
        }
    }

    // Optional: reduce packaging noise
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/NOTICE",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

// ✅ Preferred way in Kotlin DSL
kotlin {
    jvmToolchain(17)
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Firebase BoM keeps versions aligned
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")
}

flutter {
    source = "../.."
}
