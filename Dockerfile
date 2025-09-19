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

# Install dependencies in a single `RUN` command to reduce image layers
# The `set -x` command is for debugging and can be removed in a final version
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

# Copy all configuration and entrypoint files at once.
# Using a single COPY command is more efficient.
# The `--chown` flag sets the ownership correctly.
COPY --chown=tomcat:tomcat files/ $CATALINA_HOME/

# Move the docker-entrypoint.sh to its correct location and set permissions.
# The `chmod` instruction is now combined with the file move.
# This approach is less redundant.
RUN mv $CATALINA_HOME/docker-entrypoint.sh /usr/local/bin/ \
    && chmod 755 /usr/local/bin/docker-entrypoint.sh

# Download the WAR file and unpack it
RUN set -x \
    && wget --no-check-certificate -O /tmp/cmdbuild.war "$CMDBUILD_URL" \
    && unzip /tmp/cmdbuild.war -d $CATALINA_HOME/webapps/cmdbuild/ \
    && mv /tmp/cmdbuild.war $CATALINA_HOME/webapps/cmdbuild.war \
    && chmod +x $CATALINA_HOME/webapps/cmdbuild/cmdbuild.sh \
    && rm -f /tmp/cmdbuild.war

# Set correct ownership for all files within $CATALINA_HOME
RUN chown -R tomcat:tomcat $CATALINA_HOME

# The ENTRYPOINT and CMD are split for clear separation of concerns
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Run the container as the non-root `tomcat` user for security
USER tomcat

# Expose the default Tomcat port
EXPOSE 8080

# The CMD acts as the default argument to the ENTRYPOINT script
CMD ["catalina.sh", "run"]
