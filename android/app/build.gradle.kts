plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.muanyan.daily"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 用了 java.time，不脱糖就是编译期直接失败
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.muanyan.daily"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // 和上面的 isCoreLibraryDesugaringEnabled 是一对，少一个都编译不过
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 隐私锁走 local_auth，它的 MainActivity 必须是 FlutterFragmentActivity，
    // 而 FragmentActivity 在老系统（Android 8 及以下）上要求主题继承 AppCompat，
    // 否则启动即崩。这两个理由都要这条依赖，缺了是编译期就报找不到主题。
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}
