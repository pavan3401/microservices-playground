String mainFolder = 'POC'
String projectFolder = 'microservices-test'
String basePath = mainFolder + "/" +  projectFolder
String gitUrl = 'ElizabethGagne/microservices-playground/'


workflowJob("$basePath/create-env-infrastructure") {
  	scm {
        github("$gitUrl")
    }

    definition {
        cps {
            script(readFileFromWorkspace('jobs/Infrastructure.groovy'))
            sandbox()
        }
    }
}

workflowJob("$basePath/build-weather-service") {
  	scm {
        github("$gitUrl")
    }

    triggers {
        githubPush()
    }

    definition {
        cps {
            script(readFileFromWorkspace('jobs/WeatherService.groovy'))
    	    sandbox()
        }
    }
}
