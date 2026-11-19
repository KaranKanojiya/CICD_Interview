// Declarative pipeline: version -> build/test -> quality gates -> archive -> image -> staging + smoke -> approval -> prod.
// Shared steps (semver, deployApp, smokeTest, stopApp) live in jenkins/shared-library/vars.
@Library('cicd-lib') _

pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(name: 'DEPLOY_PROD', defaultValue: false, description: 'Ask for approval and promote the same artifact to prod')
    }

    environment {
        STAGING_PORT = '18080'
        GRADLE_OPTS = '-Dorg.gradle.daemon=false'
    }

    stages {
        stage('Version') {
            steps {
                script {
                    env.APP_VERSION = semver()
                    env.GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.APP_VERSION}"
                }
                echo "Building version ${env.APP_VERSION} from ${env.GIT_SHORT}"
            }
        }

        stage('Build & test') {
            steps {
                // Single quotes: the shell expands the variables, Groovy does not (no injection via interpolation).
                sh './gradlew build -PreleaseVersion="$APP_VERSION" -PgitCommit="$GIT_SHORT"'
            }
            post {
                always {
                    junit 'build/test-results/test/*.xml'
                }
            }
        }

        stage('Quality gates') {
            parallel {
                stage('Release scripts self-test') {
                    steps {
                        sh 'bash scripts/test-release-scripts.sh'
                    }
                }
                stage('Coverage report exists') {
                    steps {
                        sh 'test -s build/reports/jacoco/test/jacocoTestReport.xml'
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'build/libs/*.jar', fingerprint: true
            }
        }

        stage('Docker image') {
            when {
                expression { sh(script: 'command -v docker', returnStatus: true) == 0 }
            }
            steps {
                sh 'docker build --build-arg JAR="build/libs/cicd-demo-$APP_VERSION.jar" -t "cicd-demo:$APP_VERSION" .'
            }
        }

        stage('Deploy staging') {
            steps {
                deployApp(name: 'staging', port: env.STAGING_PORT, version: env.APP_VERSION)
                smokeTest(baseUrl: "http://localhost:${env.STAGING_PORT}", expectedVersion: env.APP_VERSION)
            }
        }

        stage('Approve prod') {
            when {
                expression { params.DEPLOY_PROD }
            }
            // Holds the executor while waiting. With real agents: top-level `agent none`, per-stage agents, stash/unstash.
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: "Promote ${env.APP_VERSION} to prod?", ok: 'Deploy'
                }
            }
        }

        stage('Deploy prod') {
            when {
                expression { params.DEPLOY_PROD }
            }
            steps {
                echo "Promoting the archived artifact cicd-demo-${env.APP_VERSION}.jar (fingerprinted) - no rebuild."
            }
        }
    }

    post {
        always {
            stopApp(name: 'staging')
        }
        success {
            echo "Pipeline OK for ${env.APP_VERSION}"
        }
        failure {
            echo 'Pipeline failed - check the stage view and staging.log'
        }
    }
}
