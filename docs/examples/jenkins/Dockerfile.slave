FROM csanchez/jenkins-swarm-slave:latest

USER root

ENV DOCKER_VERSION=1.8.3 COMPOSE_VERSION=1.5.2
ADD https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION} /usr/local/bin/docker
ADD https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64 /usr/local/bin/docker-compose

RUN chmod +rx /usr/local/bin/docker /usr/local/bin/docker-compose
RUN chmod +s /usr/local/bin/docker /usr/local/bin/docker-compose

RUN apt-get update && apt-get install -y ruby && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    gem install kontena-cli

USER jenkins-slave
