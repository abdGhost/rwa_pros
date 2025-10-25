plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

import java.util.Properties

android {
    // Use your real ID everywhere
    namespace = "com.rwa.pros"

    // Use 35 unless you’ve fully moved toolchain to Android 15
    compileSdk = 36
    ndkVersion = "26.1.10909125"
    defaultConfig {
        applicationId = "com.rwa.pros"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Release signing via keystore.properties
    signingConfigs {
         create("release") {
            val props = Properties()
            val f = file("../keystore.properties")
            if (!f.exists()) throw GradleException("keystore.properties missing")
            props.load(f.inputStream())
            storeFile = file(props["storeFile"] as String)   // app/release.keystore
            storePassword = props["storePassword"] as String
            keyAlias = props["keyAlias"] as String
            keyPassword = props["keyPassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
            // keep debug signing default
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions { jvmTarget = "17" }

    // Remove ndkVersion unless you actually use native code
    // ndkVersion = "27.0.12077973"



    buildFeatures { buildConfig = true }
}

kotlin { jvmToolchain(17) }

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Keep BoM to align Firebase libs
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")

    implementation("androidx.multidex:multidex:2.0.1")
}

flutter { source = "../.." }

