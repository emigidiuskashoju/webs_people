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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ============================================================
// GOOGLE SERVICES PLUGIN (FCM)
// ============================================================
//
// Required by firebase_messaging. The plugin reads the
// google-services.json file you placed in android/app/ and
// turns it into build-time constants that Firebase uses.
//
// Note: In Kotlin DSL, `buildscript { }` must be a top-level
// block, which is why this is at the very bottom of the file,
// after all the existing configuration.
// ============================================================

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}