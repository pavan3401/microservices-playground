node {

    stage "Build Service" // --------------------------------------

    // Build all the services with maven
    docker.image('maven:3.3.3-jdk-8').inside {
      sh 'ls -l'
      sh 'mvn clean package'
    }

    stage "Pre-configure" // --------------------------------------

    preConfigure(env.BUCKET_NAME)
}

def preConfigure(bucketName) {
    def command = 'cd cloud-formation/deploy/\n' +
        '/bin/bash ./pre-configure.sh ' + bucketName
    sh command
}