FROM jenkins/jenkins:lts-jdk21

USER root
# The repo is bind-mounted read-only and owned by another uid; let git read it.
RUN git config --system --add safe.directory '*'
USER jenkins

# Optional mirror override, e.g. --build-arg JENKINS_UC_DOWNLOAD_URL=https://archives.jenkins.io/plugins
ARG JENKINS_UC_DOWNLOAD_URL=""
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN if [ -z "$JENKINS_UC_DOWNLOAD_URL" ]; then unset JENKINS_UC_DOWNLOAD_URL; fi; \
    jenkins-plugin-cli --verbose --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins:jenkins casc.yaml /usr/share/jenkins/ref/casc.yaml
COPY --chown=jenkins:jenkins jobs.groovy /usr/share/jenkins/ref/jobs.groovy

ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc.yaml
