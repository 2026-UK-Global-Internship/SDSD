allprojects {
    repositories {
        google()
        mavenCentral()
    }
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

// ==========================================
// 모든 하위 플러그인(geolocator, image_picker 등)에
// Java 17을 강제 적용 (경고 "source/target value 8 is obsolete" 해결용)
// ==========================================
// "이 프로젝트의 모든 Java 컴파일 작업은 Java 17을 기준으로 하라"고
// 직접 지정하는 방식이라 AGP 버전/구조와 무관하게 항상 동작합니다.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}