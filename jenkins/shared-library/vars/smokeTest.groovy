// Waits for /actuator/health to be UP, then checks /api/version reports the expected version.
def call(Map args) {
    int attempts = args.attempts ?: 30
    withEnv(["BASE_URL=${args.baseUrl}", "EXPECTED=${args.expectedVersion}", "ATTEMPTS=${attempts}"]) {
        sh '''
            for i in $(seq 1 "$ATTEMPTS"); do
              if curl -fsS "$BASE_URL/actuator/health" | grep -q '"status":"UP"'; then
                echo "healthy after $i attempt(s)"
                break
              fi
              if [ "$i" -eq "$ATTEMPTS" ]; then echo "never became healthy"; exit 1; fi
              sleep 2
            done
            body=$(curl -fsS "$BASE_URL/api/version")
            echo "version endpoint: $body"
            echo "$body" | grep -q "\\"version\\":\\"$EXPECTED\\"" || { echo "expected version $EXPECTED"; exit 1; }
        '''
    }
}
