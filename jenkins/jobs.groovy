// Job DSL seed: defines the pipeline job as code. The pipeline itself comes from the repo's Jenkinsfile.
pipelineJob('cicd-demo') {
    description('Build, test, version and stage cicd-demo from the mounted repo (main branch).')
    parameters {
        booleanParam('DEPLOY_PROD', false, 'Ask for approval and promote the same artifact to prod')
    }
    logRotator {
        numToKeep(20)
    }
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('file:///workspace-repo')
                    }
                    branch('*/main')
                }
            }
            scriptPath('Jenkinsfile')
            lightweight(false)
        }
    }
}
