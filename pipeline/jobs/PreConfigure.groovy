node {
    git url: GIT_URL

    stage "Build Service" // --------------------------------------

    // Build all the services with maven
    docker.image('maven:3.3.3-jdk-8').inside {
      sh 'mvn clean package'
    }

    step([$class: 'JUnitResultArchiver', testResults: '**/target/surefire-reports/*.xml'])

    stage "Pre-configure" // --------------------------------------

    preConfigure(BUCKET_NAME)
}

def preConfigure(bucketName) {
    def command = 'cd cloud-formation/deploy/\n' +
        '/bin/bash ./pre-configure.sh ' + bucketName
    sh command
}