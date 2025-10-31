FROM maven:3.9.4-eclipse-temurin-17 as build
WORKDIR /app
COPY . /app
RUN mvn -DskipTests package -q

FROM maven:3.9.4-eclipse-temurin-17
WORKDIR /app
COPY --from=build /app/target/admin-runner-0.0.1-SNAPSHOT.jar /app/admin-runner.jar
EXPOSE 8081
ENTRYPOINT ["java","-jar","/app/admin-runner.jar"]