FROM java:openjdk-8-jdk
VOLUME /tmp
ADD target/config-server.jar config-server.jar
RUN bash -c 'touch /config-server.jar'
EXPOSE 9000
ENTRYPOINT ["java", "-jar", "/config-server.jar"]