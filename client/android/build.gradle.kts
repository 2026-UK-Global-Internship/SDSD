allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
android {
    compileSdkVersion 34  // 최신 버전으로 업데이트

    defaultConfig {
        minSdkVersion 21
        // ...
    }
}

dependencies {
    // Google Play Services 추가
    implementation 'com.google.android.gms:play-services-auth:20.7.0'
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
