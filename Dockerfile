# Use official Tomcat base image
FROM tomcat:9.0

# Remove default ROOT application
RUN rm -rf /usr/local/tomcat/webapps/ROOT

# Copy generated WAR file into webapps as ROOT
COPY target/*.war /usr/local/tomcat/webapps/ROOT.war

# Expose port 8080
EXPOSE 8080

# Start Tomcat 
CMD ["catalina.sh", "run"]
