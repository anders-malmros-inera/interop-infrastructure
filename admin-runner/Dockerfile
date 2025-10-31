FROM maven:3.9.4-eclipse-temurin-17 as build
WORKDIR /app
COPY . /app
RUN mvn -DskipTests package -q

# Final stage includes a Docker CLI so this container can invoke `docker build` against
# the mounted Docker socket. We install the host's docker client via apt.
FROM maven:3.9.4-eclipse-temurin-17
WORKDIR /app

# Install docker CLI (docker.io) so admin-runner can call docker build using the mounted
# /var/run/docker.sock from the host. Keep image small by cleaning apt lists.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends docker.io \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=build /app/target/admin-runner-0.0.1-SNAPSHOT.jar /app/admin-runner.jar
EXPOSE 8081
ENTRYPOINT ["java","-jar","/app/admin-runner.jar"]