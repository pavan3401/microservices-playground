FROM java:openjdk-8-jdk
VOLUME /tmp
EXPOSE 8761
ADD target/eureka-server.jar eureka-server.jar
RUN bash -c 'touch /eureka-server.jar'
ENTRYPOINT ["java", "-jar", "/eureka-server.jar"]
