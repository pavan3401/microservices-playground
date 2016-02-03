String gitUrl = 'https://github.com/ElizabethGagne/microservices-playground/'
String project = 'microservices'
String repository = 'weather-service'
String region = 'us-east-1'
String service = 'WeatherService'
String environment = 'microservice-test'

node {

    stage "Build Service" // --------------------------------------

    git url: gitUrl
    env.EPOCH="latest"
    env.GIT_HASH=stringFromOutput('git rev-parse HEAD | cut -c-8')
    env.TAG_LIST="1.0-${env.GIT_HASH}-${env.EPOCH}"
    env.REPOSITORY="${project}/${repository}"
    env.ACCOUNT_NUMBER=stringFromOutput("aws iam get-user | awk '/arn:aws:/{print \$2}' | cut -d \\: -f 5")
    env.AWS_TAG="${env.ACCOUNT_NUMBER}.dkr.ecr.${region}.amazonaws.com/${env.REPOSITORY}:${env.TAG_LIST}"

    sh 'echo ${AWS_TAG}'

    // Build the java code with maven
    docker.image('maven:3.3.3-jdk-8').inside {
      sh 'ls -l'
      buildService()
    }

    stage "Bake Service's Docker image" // ------------------------

    // Bake the Docker Image
    def localImage = docker.build("${env.AWS_TAG}", "./${repository}")
    sh 'docker images'

    // Login into Amazon ECR
    sh '$(aws ecr get-login --region us-east-1)'

    // Push Docker Image to Amazon ECR Repository
    localImage.push()

    stage "Deploy Service to ECS" // ------------------------------

    deployService(service, environment)
}

def buildService() {
    def command = 'cd weather-service\n' + 'mvn clean package'
    sh command
}

def deployService(service, environment) {
    def command = 'cd pipeline/resources\n' +
        '/bin/bash ./update-service.sh ' + './' + service + '.json '  + env.AWS_TAG + ' ' + environment + ' ' + service
    sh command
}

def stringFromOutput(String command) {
    sh command + ' > .variable'
    String content = readFile '.variable'
    return content.trim()
}