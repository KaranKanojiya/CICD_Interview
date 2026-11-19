# Built by the pipeline after ./gradlew bootJar -PreleaseVersion=<version>
FROM eclipse-temurin:21-jre
ARG JAR=build/libs/*.jar
RUN groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid app app
WORKDIR /app
COPY ${JAR} app.jar
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=70", "-jar", "/app/app.jar"]
