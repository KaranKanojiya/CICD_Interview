// Version for this build:
//   HEAD is exactly on tag vX.Y.Z      -> X.Y.Z
//   release-worthy commits since tag  -> <next>-build.<BUILD_NUMBER>   (semver pre-release)
//   nothing release-worthy            -> <last>-build.<BUILD_NUMBER>
def call() {
    def exact = sh(script: "git describe --tags --exact-match --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true", returnStdout: true).trim()
    if (exact) {
        return exact.substring(1)
    }
    def next = sh(script: 'bash scripts/next-version.sh 2>/dev/null || true', returnStdout: true).trim()
    if (!next) {
        def last = sh(script: "git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || echo v0.0.0", returnStdout: true).trim()
        next = last.substring(1)
    }
    return "${next}-build.${env.BUILD_NUMBER}"
}
