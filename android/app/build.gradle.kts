import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.focus_app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.focus_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 2
        versionName = "1.0.1"
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        val keyPropertiesFile = rootProject.file("key.properties")
        if (keyPropertiesFile.exists()) {
            create("release") {
                val keyProperties = Properties()
                keyPropertiesFile.inputStream().use { keyProperties.load(it) }
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfigs.findByName("release")?.let {
                signingConfig = it
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
