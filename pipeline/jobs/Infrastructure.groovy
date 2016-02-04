node {
    git url: env.GIT_URL

    stage "Create Deployment Infrastructure" // --------------------------------------

    createDeployment(env.BUCKET_NAME, env.KEY_NAME, env.HOSTED_ZONE_NAME)
}

def createDeployment(bucketName, keyName, zoneName) {
    def command = 'cd cloud-formation/deploy/\n' +
        '/bin/bash ./create-deployment.sh ' + bucketName + ' ' + keyName + ' ' + zoneName
    sh command
}