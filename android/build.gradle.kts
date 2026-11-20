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
// --------------------------------------------------------------------------
// Aligne les greffons sur le compileSdk de l'application.
//
// Pourquoi : certains greffons epinglent leur propre niveau d'API. Par
// exemple `flutter_secure_storage` demande `compileSdk 34`, ce qui oblige
// Gradle a installer `platforms;android-34` meme quand des plateformes
// plus recentes sont deja la. Sur une connexion lente, ce telechargement
// echoue et toute la compilation tombe.
//
// Compiler un greffon avec un SDK PLUS RECENT que celui qu'il demande est
// sans danger : les API Android sont retrocompatibles a la compilation.
// L'inverse ne le serait pas, d'ou la comparaison : on ne descend jamais
// en dessous de ce que le greffon exige.
//
// Ce bloc doit etre declare AVANT `evaluationDependsOn(":app")` : celui-ci
// force l'evaluation des projets, et Gradle refuse ensuite tout nouveau
// `afterEvaluate` (« Cannot run Project.afterEvaluate when the project is
// already evaluated »).
//
// L'appel passe par la reflexion car le projet racine n'a pas le greffon
// Android sur son chemin de classes : le type `BaseExtension` n'y est donc
// pas resolvable a la compilation du script.
// --------------------------------------------------------------------------
val niveauApiApplication = 36

fun niveauDe(extension: Any): Int =
    runCatching {
        (extension.javaClass.getMethod("getCompileSdkVersion").invoke(extension) as? String)
            ?.substringAfter("android-")
            ?.toIntOrNull()
    }.getOrNull() ?: 0

subprojects {
    afterEvaluate {
        val extensionAndroid = extensions.findByName("android")
        if (extensionAndroid != null && niveauDe(extensionAndroid) < niveauApiApplication) {
            runCatching {
                extensionAndroid.javaClass
                    .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(extensionAndroid, niveauApiApplication)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
