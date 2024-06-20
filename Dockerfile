# Use Maven image to build the application
FROM maven:3.8.1-openjdk-17-slim AS build
# Set maintainer information
LABEL maintainer="rajendra.daggubati@gmail.com"
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Run tests using the built application (optional)
FROM build as test
RUN mvn clean test

# Use OpenJDK Alpine image as the runtime base
FROM openjdk:17-jdk-alpine
# Set maintainer information
LABEL maintainer="rajendra.daggubati@gmail.com"
WORKDIR /app
# Copy the built JAR file from the build stage
COPY --from=build /app/target/sysfoo-0.0.1-SNAPSHOT.jar ./sysfoo.jar

# Expose ports 8080 for HTTP and 8443 for HTTPS
EXPOSE 8080 8443

# Install Apache HTTP Server (httpd) and SSL utilities
RUN apk add --no-cache apache2-utils apache2 openssl

# Generate a self-signed SSL certificate (replace with your own cert for production)
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache-selfsigned.key \
    -out /etc/ssl/certs/apache-selfsigned.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=My Organization/OU=My Unit/CN=rajasys.com"

# Configure Apache for HTTPS
COPY apache/default-ssl.conf /etc/apache2/conf.d/default-ssl.conf
RUN sed -i 's/Listen 443/Listen 8443/' /etc/apache2/conf.d/default-ssl.conf \
    && sed -i '/<\/VirtualHost>/i RewriteEngine On\nRewriteCond %{HTTPS} off\nRewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}' /etc/apache2/conf.d/default-ssl.conf

# Create a non-root user for running the application
RUN adduser -D raja

# Secure the container access with a password for the user
RUN echo "raja:password" | chpasswd

# Limit the access rights for the application
RUN chown raja:raja /app /app/sysfoo.jar \
    && chmod 500 /app /app/sysfoo.jar

# Drop the root privileges
USER raja

# Set the entry point to run the application
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "sysfoo.jar"]
