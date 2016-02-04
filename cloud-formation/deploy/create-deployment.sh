#!/bin/bash

echo -e "\n\n------  This script will create a deployment for a Microservice test AWS cloud environment ------"

USAGE="usage: ./create-deployment.sh <bucketName> <keyName> <hostedZoneName>"
if [ "$#" -lt 3 ] ; then
  echo "${USAGE}"
  exit 1
fi

ENV=microservice-test
BUCKET_NAME=$1
KEY_NAME=$2
HOSTED_ZONE_NAME=$3


## Function to check if the stack creation succeeded. If after x number of minutes it's not successful, we give up and exit 1
## Parameters:
##     $1 String   why is this function called
##     $2 String   status expected
##     $3 Integer  number of minutes to wait
##     $4 String   command to pass
checkStackStatus()
{
    count=0
    STACK_STATUS=""
    while [ -z $STACK_STATUS ]
     do
        STATUS=$(eval "$4")

        if [ "${STATUS}" != "$2" ]
        then
            if [ "${STATUS}" == "CREATE_FAILED" ]
            then
                STACK_STATUS=$STATUS
                echo "Creation failed"
                exit 1
            else
                if [ $count -lt "$3" ]
                then
                    echo "Waiting for $1 to complete, current status : ${STATUS}"
                    sleep 60
                    count=$((count+1))
                else
                    STACK_STATUS=$STATUS
                    echo "Giving up on Stack $1"
                    exit 1
                fi
            fi
        else
           STACK_STATUS=$STATUS
           echo "Stack $1 status : ${STATUS}"
        fi
     done
}


echo -e "\n\n\nThe \"${ENV}\" environment will be created."


# Global Variables
STACK_NAME=$ENV-$(date +%m-%d-%y-%H%M)
RELEASE=test

# Upload on S3 the templates
aws s3 cp ./stack/ s3://"${BUCKET_NAME}"/deploy/stack/ --recursive --grants read=uri=http://acs.amazonaws.com/groups/global/AuthenticatedUsers


# Create Stack in AWS
echo "Create : ${STACK_NAME}"
echo $ENV
echo -e "Create Stack ${STACK_NAME}\n"
aws cloudformation create-stack --stack-name "${STACK_NAME}" --template-url  https://s3.amazonaws.com/"${BUCKET_NAME}"/deploy/stack/stack_main.json \
--parameters ParameterKey=KeyName,ParameterValue="${KEY_NAME}" \
ParameterKey=Release,ParameterValue="${RELEASE}" \
ParameterKey=AccountNumber,ParameterValue="${AWS_ACCOUNT_NUMBER}" \
ParameterKey=HostedZone,ParameterValue="${HOSTED_ZONE_NAME}" \
ParameterKey=ConfigBucketName,ParameterValue="${BUCKET_NAME}" \
ParameterKey=Environment,ParameterValue="${ENV}" --capabilities CAPABILITY_IAM --disable-rollback

# Check Stack Status
COMMAND="aws cloudformation describe-stacks --stack-name ${STACK_NAME} | jq  '.Stacks[0].StackStatus' |  cut -d \"\\\"\" -f2"
checkStackStatus "create stack" "CREATE_COMPLETE" 45 "$COMMAND"

echo "Stack created... displaying info"
aws cloudformation describe-stacks --stack-name "${STACK_NAME}"
