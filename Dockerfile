# Use a Tomcat base image with JDK 17
FROM tomcat:9.0.71-jdk17-temurin

# Set the working directory to the Tomcat home
WORKDIR $CATALINA_HOME

# Define environment variables at the top for clarity
# The CMDBUILD_URL has been changed to a direct download link
ENV CMDBUILD_URL="https://downloads.sourceforge.net/project/openmaint/2.3/openmaint-2.3-3.4.1-d.war" \
    POSTGRES_USER="postgres" \
    POSTGRES_PASS="postgres" \
    POSTGRES_PORT="5432" \
    POSTGRES_HOST="openmaint_db" \
    POSTGRES_DB="openmaint" \
    CMDBUILD_DUMP="demo.dump.xz"

# Create the tomcat group and user first to ensure they exist for ownership changes
RUN groupadd -r tomcat && useradd -r -g tomcat -d $CATALINA_HOME -s /bin/false tomcat

# Install dependencies in a single `RUN` command to reduce image layers
RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    postgresql-client \
    unzip \
    wget \
    # Create necessary directories
    && mkdir -p $CATALINA_HOME/conf/cmdbuild/ \
    $CATALINA_HOME/webapps/cmdbuild/ \
    /usr/local/bin/ \
    # Clean up the apt-get cache to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files and the entrypoint script
# Use a separate COPY command for the entrypoint to set permissions with `--chmod`
COPY --chown=tomcat:tomcat files/tomcat-users.xml $CATALINA_HOME/conf/
COPY --chown=tomcat:tomcat files/context.xml $CATALINA_HOME/webapps/manager/META-INF/
COPY --chown=tomcat:tomcat files/database.conf $CATALINA_HOME/conf/cmdbuild/
COPY --chmod=755 --chown=tomcat:tomcat files/docker-entrypoint.sh /usr/local/bin/

# Download the WAR file, unpack it, and set permissions
RUN set -x \
    && wget --no-check-certificate -O /tmp/cmdbuild.war "$CMDBUILD_URL" \
    && unzip /tmp/cmdbuild.war -d $CATALINA_HOME/webapps/cmdbuild/ \
    && mv /tmp/cmdbuild.war $CATALINA_HOME/webapps/cmdbuild.war \
    && chmod +x $CATALINA_HOME/webapps/cmdbuild/cmdbuild.sh \
    && chown -R tomcat:tomcat $CATALINA_HOME \
    && rm -f /tmp/cmdbuild.war

# The ENTRYPOINT and CMD are split for clear separation of concerns
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Run the container as the non-root `tomcat` user for security
USER tomcat

# Expose the default Tomcat port
EXPOSE 8080

# The CMD acts as the default argument to the ENTRYPOINT script
CMD ["catalina.sh", "run"]
