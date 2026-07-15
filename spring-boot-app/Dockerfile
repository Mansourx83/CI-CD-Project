# --- Phase 1: Build ---
# Use the complete Maven image to build the code
FROM maven:3.8.5-openjdk-17 AS build

WORKDIR /app

# Copy pom.xml first to leverage Docker Layer Caching (significantly speeds up the build)
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy the rest of the source code
COPY src ./src

# Build the project and generate the JAR file
RUN mvn clean package -DskipTests

# --- Phase 2: Runtime ---
# Use a lightweight JRE image to reduce the final image size
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy only the generated JAR file from the build phase
# This ensures the final image contains neither Maven nor the source code
COPY --from=build /app/target/*.jar app.jar

# Expose the port the application runs on
EXPOSE 8080

# Command to run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
