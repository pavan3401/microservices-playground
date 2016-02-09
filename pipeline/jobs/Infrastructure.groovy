node {
    git url: GIT_URL

    stage "Create Deployment Infrastructure" // --------------------------------------

    sh 'echo ${SUMO_ACCESS_ID}'
    sh 'echo ${SUMO_ACCESS_KEY}'
    //createDeployment(BUCKET_NAME, KEY_NAME, HOSTED_ZONE_NAME, LOG_COLLECTOR, SUMO_ACCESS_ID, SUMO_ACCESS_KEY)
}

def createDeployment(bucketName, keyName, zoneName, logCollector, sumoAccessId, sumoAccessKey) {
    def command = 'cd cloud-formation/deploy/\n' +
        '/bin/bash ./create-deployment.sh ' + bucketName + ' ' + keyName + ' ' + zoneName + ' ' + logCollector + ' ' + sumoAccessId + ' ' + sumoAccessKey
    sh command
}