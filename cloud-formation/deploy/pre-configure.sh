#!/bin/bash

USAGE="usage: ./pre-configure.sh <bucketName>"
if [ "$#" -lt 1 ] ; then
  echo "${USAGE}"
  exit 1
fi

# Global variables
PROJECT="microservices"
S3_BUCKET=$1
declare -a EXPECTED_REPOSITORIES=("weather-service" "config-server" "eureka-server" "webapp" "ecs-cloudwatch-logs")

# Find all existing S3 buckets into that AWS account
findAllExistingS3Buckets()
{
    ALL_BUCKETS=$(aws s3api list-buckets | jq '.Buckets[].Name' | cut -d'"' -f2)
}

# Retrieve all existing ECR Repository into that AWS account
findAllExistingRepositories()
{
    ALL_ECR_REPOSITORIES=$(aws ecr describe-repositories --registry-id "${AWS_ACCOUNT_NUMBER}" | jq '.repositories[].repositoryName' | cut -d'"' -f2)
}

# Create the necessary S3 Bucket
createNecessaryS3Bucket()
{
    FOUND=false
    case "${ALL_BUCKETS[@]}" in  *$S3_BUCKET*)
        FOUND=true;;
    esac

    if [ "$FOUND" = false ]; then
        echo "Creating S3 ${S3_BUCKET} bucket"
        aws s3api create-bucket --bucket "${S3_BUCKET}" --region "${AWS_DEFAULT_REGION}" --grant-full-control
        STATUS=$?

        if [ "${STATUS}" -ne 0 ]; then
            echo "ERROR: Creating the S3 Bucket ${S3_BUCKET} failed."
            exit "${STATUS}"
        fi
    fi
}

# Create necessary ECR repositories
createNecessaryRepositories()
{
    echo "Creating necessary ECR Repositories..."
    for repo in "${EXPECTED_REPOSITORIES[@]}"
    do
         FOUND=false
         REPOSITORY=$PROJECT"/"$repo

         case "${ALL_ECR_REPOSITORIES[@]}" in  *$REPOSITORY*)
            FOUND=true;;
         esac

         if [ "${FOUND}" = false ]; then
            echo "Creating ${REPOSITORY} repository"
            aws ecr create-repository --repository-name "${REPOSITORY}"
            STATUS=$?

            if [ "${STATUS}" -ne 0 ]; then
                echo "ERROR: Creating the ECR Repository ${REPOSITORY} failed."
                exit "${STATUS}"
            fi
         fi
    done
}

# Create microservices/ecs-cloudwatch-logs image
createCloudWatchLogsImage()
{
    echo "Creating CloudWatch Logs Image..."
    docker build -t microservices/ecs-cloudwatch-logs ../../cloudwatch-logs
}

# Tag and Push Latest Images to ECR
tagAndPushLatestImagesToECR()
{
    echo "Tagging and pushing Latests Images to ECR..."
    for repo in "${EXPECTED_REPOSITORIES[@]}"
    do
        REPOSITORY="${PROJECT}/${repo}"

        echo "Tagging Image ${REPOSITORY}:latest"
        TAG="${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${REPOSITORY}:latest"

        echo "Pushing Image ${REPOSITORY}:latest to ECR repository"
        docker tag "${REPOSITORY}:latest" "${TAG}"
        docker push "${TAG}"
    done
}

# Authenticate to ECR Docker Registry
loginToECR()
{
    echo "Authenticating to ECR..."
    LOGIN_CMD=$(aws ecr get-login --region "${AWS_DEFAULT_REGION}")
    eval "${LOGIN_CMD}"
}


findAllExistingS3Buckets
createNecessaryS3Bucket
findAllExistingRepositories
createNecessaryRepositories
createCloudWatchLogsImage
loginToECR
tagAndPushLatestImagesToECR

echo "Pre-configuration completed successfully"




