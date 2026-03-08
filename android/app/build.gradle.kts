import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. 使用 Kotlin 语法读取 key.properties 文件
val signingProperties = Properties()
val signingPropertiesFile = project.rootProject.file("key.properties") // 假设 key.properties 在 android/ 目录下
if (signingPropertiesFile.exists()) {
    signingProperties.load(FileInputStream(signingPropertiesFile))
}

android {
    namespace = "com.appstore.perdev.perdev"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

        defaultConfig {
        // TODO: Specify your own unique Application ID .
        applicationId = "com.appstore.perdev.perdev"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // *** 关键修复：强制设置 NDK ABI 过滤器 ***
        ndk {
            abiFilters.clear() // 清除所有默认或冲突的过滤器
            abiFilters.add("arm64-v8a") // 只添加我们需要的架构
        }
    }

    // android/app/build.gradle.kts 文件中
    signingConfigs {
        create("release") {
            // 正确行：使用 project.rootProject.file() 确保路径从 android/ 目录开始解析
            storeFile = project.rootProject.file(signingProperties.getProperty("storeFile")) 
            
            storePassword = signingProperties.getProperty("storePassword")
            keyAlias = signingProperties.getProperty("keyAlias")
            keyPassword = signingProperties.getProperty("keyPassword")
        }
    }

   
    // 4. 构建类型 (Build Types)
    buildTypes {
        getByName("release") {
            // 确保使用我们上面定义的 release 签名配置
            signingConfig = signingConfigs.getByName("release")
            // 建议启用代码混淆和资源压缩
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}