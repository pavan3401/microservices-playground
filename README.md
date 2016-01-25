# Microservices playground

This is a simple weather app. It demonstrates solutions for common microservice architecture related problems:
- local development and testing
- configuration management
- service discovery
- log management

## Supported deployment scenarios:
- dev environment with docker compose
- EC2 Container Service

### Running locally with docker compose
1. Build fat jars:
```mvn clean package install```
2. Run eureka-server and config-server:
```docker-compose --file docker-compose-deps.yml up```
3. Run webapp and weather service:
```docker-compose --file docker-compose.yml up```

### Running on EC2 Container Service (Create CloudFormation stack):
cd ./cloud-formation/deploy/
sh ./create-deployment.sh
