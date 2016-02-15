#!/bin/bash

USAGE="usage: ./update-service.sh <imageTag> <environment> <serviceName> <serviceRepositoryName>"
if [ "$#" -lt 4 ] ; then
  echo "${USAGE}"
  exit 1
fi

IMAGE_TAG=$1
ENVIRONMENT=$2
SERVICE_NAME=$3
SERVICE_REPOSITORY_NAME=$4
TAG_ESCAPED=$(echo "${IMAGE_TAG}" | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')
TIMEOUT=90

# Retrieve 'Task Id', 'Task Definition, 'Task Family', 'Cluster' and 'Service Id' of the service to update
TASK_ID=$(aws ecs list-task-definitions --status ACTIVE --sort DESC | jq '.taskDefinitionArns[]' \
        | grep "${ENVIRONMENT}" | grep "${SERVICE_NAME}" | awk 'NR==1{print $1}' | cut -d'"' -f2)
TASK_DEF=$(aws ecs describe-task-definition --task-definition "${TASK_ID}" \
        | sed -e "s|${SERVICE_REPOSITORY_NAME}:.*\"|${SERVICE_REPOSITORY_NAME}:${TAG_ESCAPED}\"|g" \
        | jq '.taskDefinition|{family: .family, volumes: .volumes, containerDefinitions: .containerDefinitions}' )
TASK_FAMILY=$(echo "${TASK_DEF}" | jq '.taskDefinition.family' | cut -d'"' -f2)

CLUSTER=$(aws ecs list-clusters | jq '.clusterArns[]' | grep "${ENVIRONMENT}" | cut -d'"' -f2 )
SERVICE_ID=$(aws ecs list-services --cluster "${CLUSTER}" | jq '.serviceArns[]' | grep "${SERVICE_NAME}" | cut -d'"' -f2 )

# Register the new task definition for this build, and store its ARN
NEW_TASKDEF=$(aws ecs register-task-definition --cli-input-json "${TASK_DEF}" | jq .taskDefinition.taskDefinitionArn | tr -d '"')
STATUS=$?

if [ "${STATUS}" -ne 0 ]; then
    echo "ERROR: Registering the task definition ${TASK_FAMILY} failed."
    exit "${STATUS}"
else
    echo "New task definition: ${NEW_TASKDEF}"
fi

# Retrieve the actual revision and desired count of the task
TASK_REVISION=$(aws ecs describe-task-definition --task-definition "${TASK_FAMILY}" | jq '.taskDefinition.revision' )
DESIRED_COUNT=$(aws ecs describe-services --services "${SERVICE_ID}" --cluster "${CLUSTER}" | jq '.services[0].desiredCount' )

if [ "${DESIRED_COUNT}" = "0" ]; then
    DESIRED_COUNT="1"
fi

echo -e "Family: ${TASK_FAMILY}"
echo -e "Cluster: ${CLUSTER}"
echo -e "Service: ${SERVICE_ID}"
echo -e "Revision: ${TASK_REVISION}"
echo -e "Count: ${DESIRED_COUNT} "


# Update the service with the new task definition and desired count
aws ecs update-service --cluster "${CLUSTER}" --service "${SERVICE_ID}" --task-definition "${TASK_FAMILY}:${TASK_REVISION}" --desired-count "${DESIRED_COUNT}"
STATUS=$?

if [ "${STATUS}" -ne 0 ]; then
    echo "ERROR: Updating the Service ${SERVICE_ID} failed."
    exit "${STATUS}"
fi

# See if the service is able to come up again
every=10
i=0
while [ $i -lt "${TIMEOUT}" ]
do
  # Scan the list of running tasks for that service, and see if one of them is the
  # new version of the task definition

  RUNNING=$(aws ecs list-tasks --cluster "${CLUSTER}"  --service-name "${SERVICE_ID}" --desired-status RUNNING \
    | jq '.taskArns[]' \
    | xargs -I{} aws ecs describe-tasks --cluster ${CLUSTER} --tasks {} \
    | jq ".tasks[]| if .taskDefinitionArn == \"${NEW_TASKDEF}\" then . else empty end|.lastStatus" \
    | grep -e "RUNNING" )

  if [ "${RUNNING}" ]; then
    echo "Service updated successfully, new task definition running.";
    exit 0
  fi

  sleep $every
  i=$(( $i + $every ))
done

# Timeout
echo "ERROR: New task definition not running within $TIMEOUT seconds"
exit 1