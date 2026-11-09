import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase configuration is supplied only for release builds. Keeping this
// conditional lets local tests and non-Firebase builds run without secrets.
if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

// 发布密钥由本机独立保存；未提供签名配置时，Release 校验失败，避免分发调试签名包。
val releaseKeyProperties = Properties()
val releaseKeyPropertiesFile = rootProject.file("key.properties")
if (releaseKeyPropertiesFile.isFile) {
    releaseKeyPropertiesFile.inputStream().use { releaseKeyProperties.load(it) }
}
// Flutter 的 assembleRelease / bundleRelease 和 Gradle 聚合构建都需要完整发布签名。
// 仅构建 Debug 时仍可使用 Android 自动生成的开发密钥。
val releaseSigningRequested = gradle.startParameter.taskNames.any {
    val taskName = it.substringAfterLast(':')
    taskName.contains("release", ignoreCase = true) || taskName in listOf("build", "assemble", "bundle")
}
if (releaseSigningRequested) {
    val requiredProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    if (!releaseKeyPropertiesFile.isFile || requiredProperties.any { releaseKeyProperties.getProperty(it).isNullOrBlank() }) {
        throw GradleException("Android 发布签名未配置完整，请在 android/key.properties 配置本机发布密钥。")
    }
    if (!rootProject.file(releaseKeyProperties.getProperty("storeFile")).isFile) {
        throw GradleException("Android 发布密钥文件不存在，请检查 android/key.properties 中的 storeFile。")
    }
}

android {
    namespace = "org.dpdns.fanxiaogao05.chengxin_youyou"
    // Firebase 的 androidx.core 1.19 要求 API 37；SDK 已安装 android-37.0
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 要求开启 core library desugaring。
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 开发包使用独立标识，可与现有 Capacitor 客户端并存。
        applicationId = "org.dpdns.fanxiaogao05.chengxin.flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseKeyProperties.getProperty("keyAlias")
            keyPassword = releaseKeyProperties.getProperty("keyPassword")
            storeFile = releaseKeyProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = releaseKeyProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.systemProperty("widget.fixture", rootProject.layout.buildDirectory.file("widget-tests/snapshot.json").get().asFile.absolutePath)
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
}

// Android 资源单测会打包 assets，显式依赖 Flutter 的资源复制任务。
for (variant in listOf("Debug", "Release", "Profile")) {
    tasks.matching { it.name == "package${variant}UnitTestForUnitTest" }.configureEach {
        dependsOn("copyFlutterAssets$variant")
    }
}
