pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Plus plugins (device_info_plus, package_info_plus) still apply
    // kotlin-android from a 1.7.22 buildscript classpath. That mixed KGP
    // produces incomplete release class jars, and GeneratedPluginRegistrant
    // then fails with "cannot find symbol DeviceInfoPlusPlugin".
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id.startsWith("org.jetbrains.kotlin")) {
                useVersion("2.2.20")
            }
        }
    }
}

gradle.beforeProject {
    buildscript.configurations.findByName("classpath")?.resolutionStrategy?.eachDependency {
        if (requested.group == "org.jetbrains.kotlin") {
            useVersion("2.2.20")
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
