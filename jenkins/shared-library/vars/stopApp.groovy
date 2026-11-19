// Stops a process started by deployApp. Safe to call when nothing is running.
def call(Map args) {
    withEnv(["APP_NAME=${args.name}"]) {
        sh '''
            if [ -f "$APP_NAME.pid" ]; then
              kill "$(cat "$APP_NAME.pid")" 2>/dev/null || true
              rm -f "$APP_NAME.pid"
              echo "Stopped $APP_NAME"
            fi
        '''
    }
}
