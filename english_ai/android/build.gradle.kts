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

// Some plugins are published with an old compileSdk while their AndroidX
// dependencies require a newer one, which fails checkDebugAarMetadata
// (e.g. ":connectivity_plus is currently compiled against android-33").
// Force every subproject to compile against a modern SDK level.
fun Project.forceModernCompileSdk() {
    val androidExtension = extensions.findByName("android") ?: return
    val method = try {
        androidExtension.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
    } catch (_: Exception) {
        try {
            androidExtension.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
        } catch (_: Exception) {
            null
        }
    }
    try {
        method?.invoke(androidExtension, 36)
    } catch (_: Exception) {
    }
}

subprojects {
    if (state.executed) {
        forceModernCompileSdk()
    } else {
        afterEvaluate { forceModernCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
