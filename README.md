# Microservices playground

This is a simple weather app. It demonstrates solutions for common microservice architecture related problems:
- local development and testing
- configuration management
- service discovery
- log management

## Supported deployment scenarios:
- dev environment with docker compose
- EC2 Container Service + ECR

### Running locally with docker compose
1. Build jars and docker containers:
```mvn clean package install```
2. Bake docker images and run containers: eureka-server, config-server, webapp and weather-service
```docker-compose up```

### Running on EC2 Container Service (Create CloudFormation stack):
1. Build jars and docker containers:
```mvn clean package install```
2. Create S3 Bucket, ECR repositories and push containers to them
```cd ./cloud-formation/deploy/```
```sh ./pre-configure.sh <bucketName>
3. Create AWS resources and deploy containers in ECS cluster
```cd ./cloud-formation/deploy/```
```sh ./create-deployment.sh <bucketName> <keyName> <hostedZoneName> <logCollector clouwatch|sumologic>```

http://microservices-test.goe3.ca/
