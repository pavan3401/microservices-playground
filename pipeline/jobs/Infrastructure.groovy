node {
    git url: GIT_URL

    stage "Create Deployment Infrastructure" // --------------------------------------

    createDeployment(BUCKET_NAME, KEY_NAME, HOSTED_ZONE_NAME)
}

def createDeployment(bucketName, keyName, zoneName) {
    def command = 'cd cloud-formation/deploy/\n' +
        '/bin/bash ./create-deployment.sh ' + bucketName + ' ' + keyName + ' ' + zoneName
    sh command
}