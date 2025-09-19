# Use a Tomcat base image with JDK 17, which is a good choice for OpenMAINT 2.3
FROM tomcat:9.0.71-jdk17-temurin

# Set the working directory to the Tomcat home
WORKDIR $CATALINA_HOME

# Define all environment variables at the top for clarity and easy modification
ENV CMDBUILD_URL="https://sourceforge.net/projects/openmaint/files/2.3/openmaint-2.3-3.4.1-d.war/download" \
    POSTGRES_USER="postgres" \
    POSTGRES_PASS="postgres" \
    POSTGRES_PORT="5432" \
    POSTGRES_HOST="openmaint_db" \
    POSTGRES_DB="openmaint" \
    CMDBUILD_DUMP="demo.dump.xz"

# Install dependencies in a single `RUN` command to reduce image layers
# `rm -rf /var/lib/apt/lists/*` is added to clean up the cache and keep the image small
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    postgresql-client \
    unzip \
    wget \
    # Clean up the cache after installation to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories for OpenMAINT configuration
RUN mkdir -p $CATALINA_HOME/conf/cmdbuild/ \
    $CATALINA_HOME/webapps/cmdbuild/ \
    /usr/local/bin/

# Copy configuration files into the image. Using `COPY --chown` is a good practice for setting ownership.
COPY --chown=tomcat:tomcat files/tomcat-users.xml $CATALINA_HOME/conf/
COPY --chown=tomcat:tomcat files/context.xml $CATALINA_HOME/webapps/manager/META-INF/
COPY --chown=tomcat:tomcat files/database.conf $CATALINA_HOME/conf/cmdbuild/

# Copy the entrypoint script and make it executable in the same step using `COPY --chmod`
# This is a more modern and efficient way to handle permissions.
COPY --chmod=755 files/docker-entrypoint.sh /usr/local/bin/

# Use a multi-line RUN command to download, unpack, and set permissions
# This also re-locates the WAR file and sets ownership in one step.
RUN set -x \
    && wget --no-check-certificate -O /tmp/cmdbuild.war "$CMDBUILD_URL" \
    && unzip /tmp/cmdbuild.war -d $CATALINA_HOME/webapps/cmdbuild/ \
    && mv /tmp/cmdbuild.war $CATALINA_HOME/webapps/cmdbuild.war \
    && chmod +x $CATALINA_HOME/webapps/cmdbuild/cmdbuild.sh \
    && chown -R tomcat:tomcat $CATALINA_HOME \
    && rm -f /tmp/cmdbuild.war

# Use `CMD` with the ENTRYPOINT for passing default arguments
# The ENTRYPOINT and CMD are split for clear separation of concerns
# The `exec` in the entrypoint script will replace the shell process with `catalina.sh`
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# The `tomcat` user is already created in the base image, so setting the `USER` here is a good practice.
USER tomcat

# Expose the default Tomcat port
EXPOSE 8080

# This CMD acts as the default argument to the ENTRYPOINT script
CMD ["catalina.sh", "run"]
