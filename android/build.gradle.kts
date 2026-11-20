// Version unique du greffon Kotlin, alignee sur celle declaree dans
// settings.gradle.kts. Les deux doivent rester identiques.
val versionKotlinProjet = "2.4.0"

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // ----------------------------------------------------------------------
    // Unifie la version du greffon Gradle Kotlin sur TOUT le projet.
    //
    // Le probleme : certains greffons Flutter epinglent leur propre version
    // dans leur `buildscript`. `image_picker_android` demande la 2.3.20,
    // alors que l'application utilise la 2.4.0 (declaree dans
    // settings.gradle.kts). Gradle doit donc telecharger une SECONDE
    // version du greffon Kotlin, uniquement pour configurer ce sous-projet.
    //
    // Sur une connexion instable, ce telechargement echoue — et comme il a
    // lieu a la CONFIGURATION, toute la compilation tombe avec des erreurs
    // trompeuses (« 'kotlin-android' plugin requires one of the Android
    // Gradle plugins »), qui ne sont que la consequence du classpath
    // incomplet.
    //
    // La redirection resout les deux : plus rien a telecharger, et une
    // seule version de Kotlin compile tout le projet — ce qui evite aussi
    // les incompatibilites de metadonnees entre versions.
    buildscript {
        configurations.all {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin" &&
                    requested.name.startsWith("kotlin-gradle-plugin")
                ) {
                    useVersion(versionKotlinProjet)
                }
            }
        }
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
