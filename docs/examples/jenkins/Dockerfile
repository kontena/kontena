FROM jenkins:latest

COPY plugins.txt /usr/share/jenkins/ref/
COPY master.groovy /usr/share/jenkins/ref/init.groovy.d/master.groovy
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/ref/plugins.txt
