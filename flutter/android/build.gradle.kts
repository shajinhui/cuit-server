allprojects {
    repositories {
        // 可选的官方引擎离线缓存，避免受限网络反复下载同一基础版本。
        System.getenv("SHOREBIRD_MAVEN_CACHE")?.takeIf { file(it).isDirectory }?.let { cache ->
            maven {
                url = uri(cache)
                content { includeGroup("io.flutter") }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
