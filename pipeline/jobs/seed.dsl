String mainFolder = 'POC'
String projectFolder = 'microservices-test'
String basePath = mainFolder + "/" +  projectFolder
String gitUrl = 'https://github.com/ElizabethGagne/microservices-playground/'


folder("$mainFolder") {
    description 'POC Folder'
}

folder("$basePath") {
    description 'microservices-test'
}

// If you want, you can define your seed job in the DSL and create it via the REST API.
// See README.md

job("$basePath/seed") {
    scm {
        git("$gitUrl")
    }
    triggers {
        scm 'H/5 * * * *'
    }
    steps {
        dsl {
            external 'pipeline/jobs/set-up-jobs.dsl'
            additionalClasspath 'src/main/groovy'
        }
    }
}