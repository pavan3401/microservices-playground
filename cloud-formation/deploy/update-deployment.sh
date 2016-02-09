#!/bin/bash

USAGE="usage: ./create-deployment.sh <releaseVersion#> <bucketName> <keyName> <hostedZoneName> <logCollector> <sumoAccessId> <sumoAccessKey>"
if [ "$#" -lt 5 ] ; then
  echo "${USAGE}"
  exit 1
fi

ENV=microservice-test
RELEASE=test$1
BUCKET_NAME=$2
KEY_NAME=$3
HOSTED_ZONE_NAME=$4
LOG_COLLECTOR=$5
SUMO_ACCESS_ID=${6:-""}
SUMO_ACCESS_KEY=${7:-""}
STACK_NAME=$(aws cloudformation describe-stacks | jq --arg tag "${ENV}" '.Stacks[] | select (.StackName | contains($tag)) | .StackName' | cut -d"\"" -f2)


# Function to check if the stack update/create succeeded. If after x number of minutes it's not successful, we give up and exit 1
# Parameters:
#     $1 String   Why is the fonction called
#     $2 String   status expected
#     $3 Integer  number of minutes to wait
#     $4 String   command to pass
checkStackStatus()
{
    count=0
    STACK_STATUS=""
    while [ -z $STACK_STATUS ]
     do
        STATUS=$(eval "$4")

        if [ "${STATUS}" != "$2" ]
        then
            if [ $count -lt "$3" ]
            then
                echo "Waiting for  $1 to complete, current status : ${STATUS}"
                sleep 60
                count=$((count+1))
            else
                STACK_STATUS=$STATUS
                echo "Giving up on Stack $1"
                exit 1
            fi
        else
           STACK_STATUS=$STATUS
           echo "Stack $1 status : ${STATUS}"
        fi
     done
}

if [ -z "${STACK_NAME}" ]
then
    echo "Unable to retrieve the stack containing the tag name: ${ENV}"
    exit 1
fi


# Upload on S3
aws s3 cp ./stack/ s3://"${BUCKET_NAME}"/deploy/stack/ --grants read=uri=http://acs.amazonaws.com/groups/global/AuthenticatedUsers

# Update Stack
echo -e "\n\n\nThe \"${ENV}\" environement will be updated with version \"${RELEASE}\""
echo "Updating : ${STACK_NAME}"
aws cloudformation update-stack --stack-name "${STACK_NAME}" --template-url https://s3-us-east-1.amazonaws.com/"${BUCKET_NAME}"/deploy/stack/stack_main.json \
--parameters ParameterKey=KeyName,ParameterValue="${KEY_NAME}" \
ParameterKey=Release,ParameterValue="${RELEASE}" \
ParameterKey=AmazonAccount,ParameterValue="${AWS_ACCOUNT_NUMBER}" \
ParameterKey=ConfigBucketName,ParameterValue="${BUCKET_NAME}" \
ParameterKey=HostedZone,ParameterValue="${HOSTED_ZONE_NAME}" \
ParameterKey=LogCollector,ParameterValue="${LOG_COLLECTOR}" \
ParameterKey=SumoAccessID,ParameterValue="${SUMO_ACCESS_ID}" \
ParameterKey=SumoAccessKey,ParameterValue="${SUMO_ACCESS_KEY}" \
ParameterKey=Environment,ParameterValue="${ENV}" --capabilities CAPABILITY_IAM

# Verify Status
COMMAND="aws cloudformation describe-stacks --stack-name ${STACK_NAME} | jq  '.Stacks[0].StackStatus' | cut -d \"\\\"\" -f2"
checkStackStatus "update stack" "UPDATE_COMPLETE" 10 "${COMMAND}"

