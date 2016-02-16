node {
    git url: GIT_URL

    stage "Create Deployment Infrastructure" // --------------------------------------

    env.sumo_id  = null
    env.sumo_key = null

    if (LOG_COLLECTOR == 'sumologic') {
        env.sumo_id  = credential("SUMO_ACCESS_ID")
        env.sumo_key = credential("SUMO_ACCESS_KEY")
    }

    env.newrelic_license_key = credential("NEWRELIC_LICENSE_KEY")

    createDeployment(BUCKET_NAME, KEY_NAME, HOSTED_ZONE_NAME, LOG_COLLECTOR,
                     env.sumo_id, env.sumo_key, env.newrelic_license_key)
}

def createDeployment(bucketName, keyName, zoneName, logCollector, sumoAccessId, sumoAccessKey, newRelicLicense) {
    def command = 'cd cloud-formation/deploy/\n' +
        '/bin/bash ./create-deployment.sh -b ' + bucketName +
        ' -k ' + keyName + '  -d ' + zoneName + ' -c ' + logCollector +
        ' -i ' + sumoAccessId + ' -a ' + sumoAccessKey + ' -r ' + newRelicLicense
    sh command
}

def credential(name) {
    def v;
    withCredentials([[$class: 'StringBinding', credentialsId: name, variable: 'foo']]) {
        v = env.foo;
    }
    return v
}