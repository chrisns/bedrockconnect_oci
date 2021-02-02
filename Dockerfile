FROM openjdk:17-jdk-alpine
WORKDIR /app
RUN wget -q -O BedrockConnect.jar https://github.com/Pugmatt/BedrockConnect/releases/download/1.5.5/BedrockConnect-1.0-SNAPSHOT.jar
USER 1000
ENTRYPOINT [ "java", "-jar",  "BedrockConnect.jar", "nodb=true"]