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
        stringParam('GIT_URL' , "$gitUrl", 'Git repository url of your application.')
        stringParam('BUCKET_NAME', 'eliza-eureka', 'Bucket name to receive cloud formation templates.')
    }

    definition {
        cps {
            script(readFileFromWorkspace('pipeline/jobs/PreConfigure.groovy'))
            sandbox()
        }
    }
}

workflowJob("$basePath/2. create-deployment") {
  	scm {
        github("$gitRepo")
    }

    parameters {
        stringParam('GIT_URL' , "$gitUrl", 'Git repository url of your application.')
        stringParam('BUCKET_NAME', 'eliza-eureka', 'Bucket name to receive cloud formation templates.')
        stringParam('KEY_NAME', 'eureka', 'AWS .pem key used to create resources.')
        stringParam('HOSTED_ZONE_NAME', 'goe3.ca', 'Domain Name for your Application.')
        choiceParam('LOG_COLLECTOR', ['cloudwatch', 'sumologic'], 'Log Collector to use.')
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
        stringParam('GIT_URL' , "$gitUrl", 'Git repository url of your application.')
    }

    definition {
        cps {
            script(readFileFromWorkspace('pipeline/jobs/WeatherService.groovy'))
    	    sandbox()
        }
    }
}
