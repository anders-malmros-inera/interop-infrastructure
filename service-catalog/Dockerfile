FROM maven:3.9.4-eclipse-temurin-17 as build
WORKDIR /app
COPY . /app

# Build without running tests inside the image. Tests require a Docker environment
# (Testcontainers) and cannot run reliably during a docker build.
RUN mvn -DskipTests package -q

FROM eclipse-temurin:17-jdk-jammy

ARG JAR_FILE=target/*.jar
COPY --from=build /app/target/*.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]