plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

kotlin {
    jvmToolchain(17)
}

android {
    namespace = "com.example.frontend"

    // You can omit compileSdk/targetSdk and let Flutter’s plugin drive them,
    // but if you want them explicit, keep these numbers aligned with your SDKs.
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.frontend"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        debug {
            // Ensure debug builds don't require native symbols
            // ndk { debugSymbolLevel = com.android.build.api.dsl.DebugSymbolLevel.NONE }
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Do not force an NDK version here unless you actually need it.
            // ndk { debugSymbolLevel = com.android.build.api.dsl.DebugSymbolLevel.NONE }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}
