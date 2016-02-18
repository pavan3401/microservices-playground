#!/bin/bash

# Exit this bash script on any error
set -e

# Get the script name from its filename in the path
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")

# Get the script version from git when available or otherwise default to 0.1.0
SCRIPT_VERSION="$(git describe --long --match [0-9]* 2>/dev/null || echo 0.1.0)"

# Usage to be displayed when using -h, --help or any invalid option
USAGE="NAME
    $SCRIPT_NAME - Create AWS deployment.

SYNOPSIS
    $SCRIPT_NAME [options]

DESCRIPTION
    $SCRIPT_NAME is a script that will create a deployment for a Microservice test AWS cloud environment.

    This script is creating necessary AWS environment to run the Microservice test.
    It will create VPC, Subnets, SecurityGroups, ECS clusters, TaskDefinitions etc... then deploy the microservices.

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

    Mandatory Options:

    -b | --bucket-name <bucket>
        The bucket name to create to receive Cloud Formation Templates.
    -k | --key-name <key>
        The AWS .pem key used to create the resources.
    -d | --domain-name <domain>
        The domain name that Route53 will translate to the ELB facing internet IP address.
    -c | --log-collector <collector, either cloudwatch|sumologic>
        Log Collector type to use, either 'cloudwatch' or 'sumologic'. If sumologic is chosen, the Sumo Access ID and Key are required.

    Optional Options:

    -r | --newrelic-license <licence>
        The NewRelic License Key. Used to Monitoring ECS instances.
    -i | --sumologic-access-id <id>
        The SumoLogic Access Id. Used to collect syslogs.
    -a | --sumologic-access-key <key>
        The SumoLogic Access Key. Used to collect syslogs.
    -h | --help
        Show this script usage information then exit successfully.
    -v | --version
        Only output version information then exit successfully.

EXAMPLE
    ./$SCRIPT_NAME -b eliza-eureka -k eureka -d goe3.ca -c cloudwatch
"

if [ "$#" == 0 ] ; then
  echo "${USAGE}"
  exit 1
fi

# Setup default values for variables
ENV=microservice-test
BUCKET_NAME=false
KEY_NAME=false
HOSTED_ZONE_NAME=false
LOG_COLLECTOR=false
SUMO_ACCESS_ID=
SUMO_ACCESS_KEY=
NEWRELIC_LICENSE_KEY=""
AWS_ACCOUNT_NUMBER=$(aws iam get-user | awk '/arn:aws:/{print $2}' | cut -d \: -f 5)

# Loop through arguments, two at a time for key and value
while [[ $# > 0 ]]
do
    key="$1"

    case $key in
	    -b|--bucket-name)
	        BUCKET_NAME="$2"
	        shift # past argument
	        ;;
        -k|--key-name)
            KEY_NAME="$2"
            shift # past argument
            ;;
        -d|--domain-name)
            HOSTED_ZONE_NAME="$2"
            shift # past argument
            ;;
        -c|--log-collector)
            LOG_COLLECTOR="$2"
            shift
            ;;
        -r|--newrelic-license)
            NEWRELIC_LICENSE_KEY="$2"
            shift
            ;;
        -i|--sumologic-access-id)
            SUMO_ACCESS_ID="$2"
            shift
            ;;
        -a|--sumologic-access-key)
            SUMO_ACCESS_KEY="$2"
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

# Validate input
if [ "${BUCKET_NAME}" == false ]; then
    echo "Error: BUCKET_NAME is required. You can pass the value using -b or --bucket-name"
    exit 1
fi
if [ "${KEY_NAME}" == false ]; then
    echo "Error: KEY_NAME is required. You can pass the value using -k or --key-name"
    exit 1
fi
if [ "${HOSTED_ZONE_NAME}" == false ]; then
    echo "Error: HOSTED_ZONE_NAME is required. You can pass the value using -d or --domain-name"
    exit 1
fi
if [ "${LOG_COLLECTOR}" == false ]; then
    echo "Error: LOG_COLLECTOR is required. You can pass the value using -c or --log-collector"
    exit 1
fi
if  [[ ! "${LOG_COLLECTOR}" =~ ^(cloudwatch|sumologic) ]]; then
    echo "Error: LOG_COLLECTOR should be a string set to either 'cloudwatch' or 'sumologic'"
    exit 1
fi
if [[ "${LOG_COLLECTOR}" =~ ^sumologic ]]; then
    if [[ -z "${SUMO_ACCESS_ID}" ]] || [[ -z "${SUMO_ACCESS_KEY}" ]]; then
        echo "Error: When choosing sumologic as the LOG_COLLECTOR you should provide the Sumo Access Id & Key of the account, options -i and -a"
        exit 1
    fi
fi


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

echo -e "\n\n------  This script will create a deployment for a Microservice test AWS cloud environment ------"
echo -e "\n\n\nThe \"${ENV}\" environment will be created."


# Global Variables
#STACK_NAME=$ENV-$(date +%m-%d-%y-%H%M)
#RELEASE=test
#
## Upload on S3 the templates
#aws s3 cp ./stack/ s3://"${BUCKET_NAME}"/deploy/stack/ --recursive --grants read=uri=http://acs.amazonaws.com/groups/global/AuthenticatedUsers
#
#
## Create Stack in AWS
#echo "Create : ${STACK_NAME}"
#echo $ENV
#echo -e "Create Stack ${STACK_NAME}\n"
#aws cloudformation create-stack --stack-name "${STACK_NAME}" --template-url  https://s3.amazonaws.com/"${BUCKET_NAME}"/deploy/stack/stack_main.json \
#--parameters ParameterKey=KeyName,ParameterValue="${KEY_NAME}" \
#ParameterKey=Release,ParameterValue="${RELEASE}" \
#ParameterKey=AccountNumber,ParameterValue="${AWS_ACCOUNT_NUMBER}" \
#ParameterKey=HostedZone,ParameterValue="${HOSTED_ZONE_NAME}" \
#ParameterKey=ConfigBucketName,ParameterValue="${BUCKET_NAME}" \
#ParameterKey=LogCollector,ParameterValue="${LOG_COLLECTOR}" \
#ParameterKey=SumoAccessID,ParameterValue="${SUMO_ACCESS_ID}" \
#ParameterKey=SumoAccessKey,ParameterValue="${SUMO_ACCESS_KEY}" \
#ParameterKey=NewRelicLicenseKey,ParameterValue="${NEWRELIC_LICENSE_KEY}" \
#ParameterKey=Environment,ParameterValue="${ENV}" --capabilities CAPABILITY_IAM --disable-rollback
#
## Check Stack Status
#COMMAND="aws cloudformation describe-stacks --stack-name ${STACK_NAME} | jq  '.Stacks[0].StackStatus' |  cut -d \"\\\"\" -f2"
#checkStackStatus "create stack" "CREATE_COMPLETE" 45 "$COMMAND"
#
#echo "Stack created... displaying info"
#aws cloudformation describe-stacks --stack-name "${STACK_NAME}"
