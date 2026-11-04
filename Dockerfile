FROM eclipse-temurin:21-jre
WORKDIR /app
EXPOSE 8080
COPY target/*.jar app.jar
CMD ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
