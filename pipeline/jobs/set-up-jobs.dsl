String mainFolder = 'POC'
String projectFolder = 'microservices-test'
String basePath = mainFolder + "/" +  projectFolder
String gitUrl = 'https://github.com/ElizabethGagne/microservices-playground/'


workflowJob("$basePath/create-env-infrastructure") {
  	scm {
        git("$gitUrl")
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
        git("$gitUrl")
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
