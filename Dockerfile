ARG IMAGE_VARIANT=jammy
ARG PYTHON_VERSION=3.9.8

# 1. basic setup
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS base
WORKDIR /spark
RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt-get -y install apt-transport-https
RUN apt-get -y update
RUN apt-get -y install python3 python3-pip

#2. download jdk
# Install "software-properties-common" (for the "add-apt-repository")
RUN apt-get update && apt-get install -y curl zip unzip
RUN curl -s 'https://get.sdkman.io' | bash
RUN /bin/bash -c "source $HOME/.sdkman/bin/sdkman-init.sh; sdk version; sdk install java 8.0.302-open; sdk install maven 3.6.3"
RUN /bin/bash -c "source $HOME/.sdkman/bin/sdkman-init.sh; sdk version; sdk install java 8.0.302-open;"
# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
RUN export JAVA_HOME

# RUN apt-get -y install maven

# ENV MAVEN_HOME /usr/share/maven
# ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

# ENV MAVEN_HOME /usr/share/maven
# ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

# # Define commonly used JAVA_HOME variable
# ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# 3. download spark
ARG SPARK_VERSION=3.0.2
ARG HADOOP_VERSION=2.7
RUN mkdir /tempdata \
    && chmod 777 /tempdata \
    && cd / \
    && echo "Downloading spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz ..." \
    && wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar -xvzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} spark \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

ENV DAEMON_RUN=true \
    HADOOP_VERSION=$HADOOP_VERSION \
    SPARK_DEBUG_DISABLED="" \
    SPARK_HOME=/spark/spark-3.0.2-bin-hadoop2.7 \
    SPARK_MASTER_DISABLED="" \
    SPARK_MASTER_PORT=7077 \
    SPARK_MASTER_WEBUI_PORT=8080 \
    SPARK_MASTER_URL="local" \
    SPARK_SUBMIT_PACKAGES="" \
    SPARK_VERSION=$SPARK_VERSION \
    SPARK_WORKER_INSTANCES=1 \
    SPARK_WORKER_PORT=7078 \
    SPARK_WORKER_WEBUI_PORT=8081
ENV PATH="${SPARK_HOME}/bin:${DOTNET_WORKER_DIR}:${PATH}"

#. copy dotnet source
COPY . .

FROM maven:3.6.3-jdk-8-slim as build-jar
COPY --from=base . .
RUN ls
WORKDIR /spark/src/scala
RUN mvn clean package
RUN ls

# COPY src/scala/microsoft-spark-3-0/target/microsoft-spark-3-0_2.12-2.1.1.jar /app/jars/microsoft-spark-3-0_2.12-2.1.1.jar

# # Define default command.
# # CMD ["mvn", "--version"]
# # WORKDIR /spark/src/scala
# # RUN mvn clean package

# WORKDIR /spark/src/csharp/Microsoft.Spark.Worker

# # RUN dotnet restore
# # RUN dotnet publish -f netcoreapp3.1 -r linux-x64

# WORKDIR /spark

# COPY run-debug.sh /app/
# RUN chmod a+x /app/run-debug.sh

# ENV DOTNET_WORKER_DIR /spark/artifacts/bin/Microsoft.Spark.Worker/Debug/netcoreapp3.1/linux-x64
# ENV DOTNETBACKEND_DEBUG_PORT 5567
# ENV SPARK_MASTER_URL local
# ENV ENABLE_INIT_DAEMON false
# ENV SPARK_APPLICATION_MAIN_CLASS org.apache.spark.deploy.dotnet.DotnetRunner
# # use the patched jar
# ENV DOTNETBACKEND_JAR /app/jars/microsoft-spark-3-0_2.12-2.1.1.jar


# EXPOSE 5567
# RUN ls
# # ENTRYPOINT spark-submit --class ${SPARK_APPLICATION_MAIN_CLASS} --master ${SPARK_MASTER_URL} ${DOTNETBACKEND_JAR} debug

# # CMD /app/run-debug.sh