#!/bin/bash

# Exit this bash script on any error
set -e

# Get the script name from its filename in the path
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")

# Get the script version from git when available or otherwise default to 0.1.0
SCRIPT_VERSION="$(git describe --long --match [0-9]* 2>/dev/null || echo 0.1.0)"

# Usage to be displayed when using -h, --help or any invalid option
USAGE="NAME
    $SCRIPT_NAME - Update the service with the new version

SYNOPSIS
    $SCRIPT_NAME [options]

DESCRIPTION
    $SCRIPT_NAME is a script to update the running service with a new version.

    This script is creating a new AWS Task Definition and Update the Service with it.
    It will trigger blue/green deployments on Amazon Elastic Container Service for that Service.

OPTIONS
    Options start with one or two dashes.
    Many of the options require an additional value next to them.

    The short 'single-dash' form of the options, -h for example,
    may be used with or without a space between it and its value,
    although a space is a recommended separator.

    The long 'double-dash' form of the options, --help for example,
    requires a space between it and its value.

    Short version options that don't need any additional values
    can be used immediately next to each other, for example
    all the options -x, -Y and -z can be specified at once as -xYz.

    -i | --image-tag <tag>
        The new docker image tag. (Mandatory)
    -e | --environment <environment>
        Environment in which the service is running. (Mandatory)
    -n | --service-name <name>
        Name of service to deploy. (Mandatory)
    -r | --repository-name <repository>
        Repository name of the service. (Mandatory)
    -t | --timeout <value>
        The timeout (in seconds) to wait for the service to come up. Default 120 seconds. (Optional)
    -h, --help
        Show this script usage information then exit successfully.
    -v, --version
        Only output version information then exit successfully.

EXAMPLE
    ./update-service.sh --image-tag 1.0-e65e3cad-latest --environment microservice-test --service-name WeatherService --repository-name weather-service
"

if [ "$#" == 0 ] ; then
  echo "${USAGE}"
  exit 1
fi

# Setup default values for variables
IMAGE_TAG=false
ENVIRONMENT=false
SERVICE_NAME=false
SERVICE_REPOSITORY_NAME=false
TIMEOUT=300

# Loop through arguments, two at a time for key and value
while [[ $# > 0 ]]
do
    key="$1"

    case $key in
	    -e|--environment)
	        ENVIRONMENT="$2"
	        shift # past argument
	        ;;
        -r|--repository-name)
            SERVICE_REPOSITORY_NAME="$2"
            shift # past argument
            ;;
        -n|--service-name)
            SERVICE_NAME="$2"
            shift # past argument
            ;;
        -i|--image-tag)
            IMAGE_TAG="$2"
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift
            ;;
        -h)
            echo "${USAGE}"
            exit 0;;
        -v)
            echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
            exit 0;;
        *)
            echo "${USAGE}"
            exit 2
        ;;
    esac
    shift # past argument or value
done

if [ $SERVICE_REPOSITORY_NAME == false ]; then
    echo "SERVICE REPOSITORY NAME is required. You can pass the value using -r or --repository-name"
    exit 1
fi
if [ $SERVICE_NAME == false ]; then
    echo "SERVICE NAME is required. You can pass the value using -n or --service-name"
    exit 1
fi
if [ $IMAGE_TAG == false ]; then
    echo "IMAGE TAG is required. You can pass the value using -i or --image-tag"
    exit 1
fi
if [ $ENVIRONMENT == false ]; then
    echo "ENVIRONMENT is required. You can pass the value using -e or --environment"
    exit 1
fi

echo -e "--------------------------------------"
echo -e "Image Tag: ${IMAGE_TAG}"
echo -e "Service Name: ${SERVICE_NAME}"
echo -e "Service Repository: ${SERVICE_REPOSITORY_NAME}"
echo -e "Environment: ${ENVIRONMENT}"
echo -e "Timeout: ${TIMEOUT}"
echo -e "--------------------------------------\n"


TAG_ESCAPED=$(echo "${IMAGE_TAG}" | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')

# Retrieve 'Task Id', 'Task Definition, 'Task Family', 'Cluster' and 'Service Id' of the service to update
TASK_ARN=$(aws ecs list-task-definitions --status ACTIVE --sort DESC | jq '.taskDefinitionArns[]' \
        | grep "${ENVIRONMENT}" | grep "${SERVICE_NAME}" | awk 'NR==1{print $1}' | cut -d'"' -f2)
TASK_DEF=$(aws ecs describe-task-definition --task-definition "${TASK_ARN}")
TASK_FAMILY=$(echo "${TASK_DEF}" | jq '.taskDefinition.family' | cut -d'"' -f2)
NEW_TASK_DEF=$(echo "${TASK_DEF}" \
        | sed -e "s|${SERVICE_REPOSITORY_NAME}:.*\"|${SERVICE_REPOSITORY_NAME}:${TAG_ESCAPED}\"|g" \
        | jq '.taskDefinition|{family: .family, volumes: .volumes, containerDefinitions: .containerDefinitions}' )

CLUSTER_ARN=$(aws ecs list-clusters | jq '.clusterArns[]' | grep "${ENVIRONMENT}" | cut -d'"' -f2 )
SERVICE_ARN=$(aws ecs list-services --cluster "${CLUSTER_ARN}" | jq '.serviceArns[]' | grep "${SERVICE_NAME}" | cut -d'"' -f2 )

# Register the new task definition for this build, and store its ARN
NEW_TASKDEF_ARN=$(aws ecs register-task-definition --cli-input-json "${NEW_TASK_DEF}" | jq .taskDefinition.taskDefinitionArn | tr -d '"')
STATUS=$?

if [ "${STATUS}" -ne 0 ]; then
    echo "ERROR: Registering the task definition ${TASK_FAMILY} failed."
    exit "${STATUS}"
fi

# Retrieve the actual revision and desired count of the task
TASK_REVISION=$(aws ecs describe-task-definition --task-definition "${TASK_FAMILY}" | jq '.taskDefinition.revision' )
DESIRED_COUNT=$(aws ecs describe-services --services "${SERVICE_ARN}" --cluster "${CLUSTER_ARN}" | jq '.services[0].desiredCount' )

if [ "${DESIRED_COUNT}" = "0" ]; then
    DESIRED_COUNT="1"
fi

echo -e "--------------------------------------"
echo -e "Family: ${TASK_FAMILY}"
echo -e "TaskArn (old): ${TASK_ARN}"
echo -e "TaskArn (new): ${NEW_TASKDEF_ARN}"
echo -e "ClusterArn: ${CLUSTER_ARN}"
echo -e "ServiceArn: ${SERVICE_ARN}"
echo -e "Revision: ${TASK_REVISION}"
echo -e "Count: ${DESIRED_COUNT} "
echo -e "--------------------------------------\n"

# Update the service with the new task definition and desired count
aws ecs update-service --cluster "${CLUSTER_ARN}" --service "${SERVICE_ARN}" --task-definition "${TASK_FAMILY}:${TASK_REVISION}" --desired-count "${DESIRED_COUNT}"
STATUS=$?

if [ "${STATUS}" -ne 0 ]; then
    echo "ERROR: Updating the Service ${SERVICE_ARN} failed."
    exit "${STATUS}"
fi

# See if the service is able to come up again
every=10
i=0
while [ $i -lt "${TIMEOUT}" ]
do
  # Scan the list of running tasks for that service, and see if one of them is the
  # new version of the task definition

  RUNNING=$(aws ecs list-tasks --cluster "${CLUSTER_ARN}"  --service-name "${SERVICE_ARN}" --desired-status RUNNING \
    | jq '.taskArns[]' \
    | xargs -I{} aws ecs describe-tasks --cluster ${CLUSTER_ARN} --tasks {} \
    | jq ".tasks[]| if .taskDefinitionArn == \"${NEW_TASKDEF_ARN}\" then . else empty end|.lastStatus" | cut -d'"' -f2 )

  if [ -z "${RUNNING}" ]; then
     echo "status = PENDING"
  else
    echo "status = ${RUNNING}"
  fi

  if [ "${RUNNING}" == "RUNNING" ]; then
    echo "Service updated successfully, new task definition running."
    exit 0
  fi

  sleep $every
  i=$(( $i + $every ))
done

# Timeout
echo "ERROR: New task definition not running within ${TIMEOUT} seconds"
exit 1