FROM java:openjdk-8-jdk
VOLUME /tmp
EXPOSE 8080
ADD webapp.jar /webapp.jar
RUN bash -c 'touch /webapp.jar'
ENTRYPOINT ["java", "-jar", "/webapp.jar"]
