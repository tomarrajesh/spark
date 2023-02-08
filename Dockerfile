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
RUN /bin/bash -c "source $HOME/.sdkman/bin/sdkman-init.sh; sdk version; sdk install java 8.0.302-open;"
# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
RUN export JAVA_HOME

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

COPY microsoft-spark-3-0_2.12-2.1.1.jar /app/jars/microsoft-spark-3-0_2.12-2.1.1.jar

WORKDIR /spark/src/csharp/Microsoft.Spark.Worker

# RUN dotnet restore
RUN dotnet publish -f netcoreapp3.1 -r linux-x64

WORKDIR /spark

# COPY run-debug.sh /app/
# RUN chmod a+x /app/run-debug.sh

ENV DOTNET_WORKER_DIR /spark/artifacts/bin/Microsoft.Spark.Worker/Debug/netcoreapp3.1/linux-x64
ENV DOTNETBACKEND_DEBUG_PORT 5567
ENV SPARK_MASTER_URL local
ENV ENABLE_INIT_DAEMON false
ENV SPARK_APPLICATION_MAIN_CLASS org.apache.spark.deploy.dotnet.DotnetRunner
# use the patched jar
ENV DOTNETBACKEND_JAR /app/jars/microsoft-spark-3-0_2.12-2.1.1.jar


EXPOSE 5567
RUN ls
# ENTRYPOINT ["spark-submit", "--class", "org.apache.spark.deploy.dotnet.DotnetRunner", "--master", "local", "/app/jars/microsoft-spark-3-0_2.12-2.1.1.jar", "debug"]

# # CMD /app/run-debug.sh