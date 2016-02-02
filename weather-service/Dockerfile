FROM java:openjdk-8-jdk
VOLUME /tmp
EXPOSE 8081
ADD target/weather-service.jar /weather-service.jar
RUN bash -c 'touch /weather-service.jar'
ENTRYPOINT ["java", "-jar", "/weather-service.jar"]

