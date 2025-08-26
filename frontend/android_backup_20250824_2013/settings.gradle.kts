// android/settings.gradle.kts
import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    val props = java.util.Properties()
    file("local.properties").inputStream().use { props.load(it) }
    val flutterSdk = props.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in local.properties")

    // Make Flutter’s Gradle build available (provides dev.flutter plugins)
    includeBuild("$flutterSdk/packages/flutter_tools/gradle")

    // Pin Kotlin plugin version HERE (so resolution is centralized)
    plugins {
        id("org.jetbrains.kotlin.android") version "2.0.21"
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven("https://storage.googleapis.com/download.flutter.io")
    }
}

// Newer Flutter templates include the loader plugin in settings.
// Keep this — it enables Flutter’s plugin to contribute dependencies properly.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}

@Suppress("UnstableApiUsage")
dependencyResolutionManagement {
    // Ensure project-level repos don't mask settings-level repos
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // REQUIRED for Flutter engine artifacts (embedding, arm64_v8a_*, etc.)
        maven("https://storage.googleapis.com/download.flutter.io")
    }
}

rootProject.name = "TRAINER_TRACKER_APP"
include(":app")
