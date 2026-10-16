plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigning = mapOf(
    "CARVEXA_RELEASE_STORE_FILE" to System.getenv("CARVEXA_RELEASE_STORE_FILE"),
    "CARVEXA_RELEASE_STORE_PASSWORD" to System.getenv("CARVEXA_RELEASE_STORE_PASSWORD"),
    "CARVEXA_RELEASE_KEY_ALIAS" to System.getenv("CARVEXA_RELEASE_KEY_ALIAS"),
    "CARVEXA_RELEASE_KEY_PASSWORD" to System.getenv("CARVEXA_RELEASE_KEY_PASSWORD"),
)
val configuredReleaseSigning = releaseSigning.values.all { !it.isNullOrBlank() }
val partiallyConfiguredReleaseSigning = releaseSigning.values.any { !it.isNullOrBlank() }
val allowDebugReleaseSigning = System.getenv("CARVEXA_ALLOW_DEBUG_RELEASE_SIGNING") == "true"

if (partiallyConfiguredReleaseSigning && !configuredReleaseSigning) {
    val missing = releaseSigning.filterValues { it.isNullOrBlank() }.keys.joinToString(", ")
    throw GradleException("Incomplete Android signing configuration. Set: $missing")
}

gradle.taskGraph.whenReady {
    val requestsReleaseArtifact = allTasks.any { task ->
        task.name.contains("release", ignoreCase = true)
    }
    if (requestsReleaseArtifact && !configuredReleaseSigning && !allowDebugReleaseSigning) {
        throw GradleException(
            "Release signing is not configured. Set the four CARVEXA_RELEASE_* variables; " +
                "for a local QA build only, set CARVEXA_ALLOW_DEBUG_RELEASE_SIGNING=true.",
        )
    }
}

android {
    namespace = "com.carvexa.ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (configuredReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigning.getValue("CARVEXA_RELEASE_STORE_FILE")!!)
                storePassword = releaseSigning.getValue("CARVEXA_RELEASE_STORE_PASSWORD")
                keyAlias = releaseSigning.getValue("CARVEXA_RELEASE_KEY_ALIAS")
                keyPassword = releaseSigning.getValue("CARVEXA_RELEASE_KEY_PASSWORD")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.carvexa.ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage requires Android 7.0 (API 24) or newer.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use the private release keystore when configured. A debug key is
            // allowed only for an explicitly requested local QA artifact.
            signingConfig = signingConfigs.getByName(
                if (configuredReleaseSigning) "release" else "debug",
            )
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
