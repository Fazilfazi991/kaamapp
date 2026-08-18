import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kaamperfectmatch.kaam_perfect_match"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.kaamperfectmatch.kaam_perfect_match"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Kaam"
    }

    flavorDimensions += "environment"
    productFlavors {
        create("qa") {
            dimension = "environment"
            applicationIdSuffix = ".qa"
            versionNameSuffix = "-qa"
            manifestPlaceholders["appLabel"] = "Kaam QA"
        }
        create("production") {
            dimension = "environment"
            manifestPlaceholders["appLabel"] = "Kaam"
        }
    }

    buildTypes {
        release {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = Properties().apply {
                    keyPropertiesFile.inputStream().use(::load)
                }
                val kaamStorePassword = providers.environmentVariable("KAAM_STORE_PASSWORD").orNull
                val kaamKeyPassword = providers.environmentVariable("KAAM_KEY_PASSWORD").orNull
                val hasCompleteSigningConfig = listOf("storeFile", "keyAlias")
                    .all { key ->
                        val value = keyProperties.getProperty(key)
                        !value.isNullOrBlank()
                    }
                if (hasCompleteSigningConfig && !kaamStorePassword.isNullOrBlank() && !kaamKeyPassword.isNullOrBlank()) {
                    signingConfigs.create("release") {
                        keyAlias = keyProperties.getProperty("keyAlias")
                        keyPassword = kaamKeyPassword
                        storeFile = file(keyProperties.getProperty("storeFile"))
                        storePassword = kaamStorePassword
                    }
                    signingConfig = signingConfigs.getByName("release")
                }
            }
            // No debug-key fallback: Play artifacts must be explicitly signed.
            isMinifyEnabled = true
            isShrinkResources = true
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.play:app-update:2.1.0")
}

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task -> task.name.contains("Release", ignoreCase = true) }
    if (!releaseRequested) return@whenReady
    val keyPropertiesFile = rootProject.file("key.properties")
    if (!keyPropertiesFile.exists()) {
        throw GradleException("Missing android/key.properties. A production release must be signed with the KAAM upload key.")
    }
    val keyProperties = Properties().apply { keyPropertiesFile.inputStream().use(::load) }
    val missingKeys = listOf("storeFile", "keyAlias").filter { key ->
        val value = keyProperties.getProperty(key)
        value.isNullOrBlank()
    }
    val missingEnvironment = listOf("KAAM_STORE_PASSWORD", "KAAM_KEY_PASSWORD").filter { name ->
        providers.environmentVariable(name).orNull.isNullOrBlank()
    }
    if (missingKeys.isNotEmpty() || missingEnvironment.isNotEmpty()) {
        throw GradleException(
            "Production signing is incomplete. Missing key.properties values: ${missingKeys.joinToString(", ")}; " +
                "missing environment variables: ${missingEnvironment.joinToString(", ")}.",
        )
    }
}
