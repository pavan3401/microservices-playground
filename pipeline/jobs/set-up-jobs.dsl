String mainFolder = 'POC'
String projectFolder = 'microservices-test'
String basePath = mainFolder + "/" +  projectFolder
String gitRepo = 'ElizabethGagne/microservices-playground'
String gitUrl = 'https://github.com/' + gitRepo

workflowJob("$basePath/1. pre-configure") {
  	scm {
        github("$gitRepo")
    }

    parameters {
        stringParam('GIT_URL' , "$gitUrl")
        stringParam('BUCKET_NAME', 'eliza-eureka')
    }

    definition {
        cps {
            script(readFileFromWorkspace('pipeline/jobs/PreConfigure.groovy'))
            sandbox()
        }
    }

    publishers {
        archiveJunit('**/target/surefire-reports/*.xml')
        downstream("$basePath/2. create-deployment", 'SUCCESS')
    }
}

workflowJob("$basePath/2. create-deployment") {
  	scm {
        github("$gitRepo")
    }

    parameters {
        stringParam('GIT_URL' , "$gitUrl")
        stringParam('BUCKET_NAME', 'eliza-eureka')
        stringParam('KEY_NAME', 'eureka')
        stringParam('HOSTED_ZONE_NAME', 'goe3.ca')
    }

    definition {
        cps {
            script(readFileFromWorkspace('pipeline/jobs/Infrastructure.groovy'))
            sandbox()
        }
    }
}

workflowJob("$basePath/3. update-weather-service") {
  	scm {
        github("$gitRepo")
    }

    triggers {
        githubPush()
    }

    parameters {
        stringParam('GIT_URL' , "$gitUrl")
    }

    definition {
        cps {
            script(readFileFromWorkspace('pipeline/jobs/WeatherService.groovy'))
    	    sandbox()
        }
    }

    publishers {
        archiveJunit('**/target/surefire-reports/*.xml')
    }
}
