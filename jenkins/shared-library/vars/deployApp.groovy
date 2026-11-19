// Starts the built jar in the background as a stand-in for a real environment deploy.
// JENKINS_NODE_COOKIE stops Jenkins killing the process when the sh step returns.
def call(Map args) {
    withEnv(["APP_NAME=${args.name}", "APP_PORT=${args.port}", "APP_VERSION=${args.version}", 'JENKINS_NODE_COOKIE=dontKillMe']) {
        sh '''
            nohup java -jar "build/libs/cicd-demo-$APP_VERSION.jar" --server.port="$APP_PORT" > "$APP_NAME.log" 2>&1 &
            echo $! > "$APP_NAME.pid"
            echo "Started $APP_NAME (pid $(cat "$APP_NAME.pid")) on port $APP_PORT"
        '''
    }
}
