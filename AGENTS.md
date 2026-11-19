# AGENTS.md

CI/CD interview prep: a Spring Boot app delivered by GitHub Actions, Jenkins (Dockerized, JCasC + Job DSL), and reference Spinnaker/Harness pipelines, plus Conventional-Commit-based release scripts.

## Commands
```bash
./gradlew test                          # 2 tests
bash scripts/test-release-scripts.sh    # 10 assertions must pass
actionlint                              # workflows must lint clean
./jenkins/up.sh && ./jenkins/run-pipeline.sh   # needs Docker; Jenkins builds committed main, must end SUCCESS
```

## Rules
- No secrets in the repo. Jenkins admin password comes from `JENKINS_ADMIN_PASSWORD` or the git-ignored `jenkins/.admin-password`; Spinnaker/Harness reference secrets by name only.
- Workflows: least-privilege `permissions`, untrusted values only via `env:`, never `${{ }}` inside `run:` for event data.
- Jenkins: pass values to `sh` via `withEnv` and single-quoted scripts, not Groovy string interpolation.
- `release.sh` must never push; keep `next-version.sh` rules and the self-test in sync.
- Spinnaker JSON and Harness YAML must stay parseable (`python3 -m json.tool`, `ruby -ryaml`).
- Question numbers referenced from other docs (e.g. Q30) must match `docs/INTERVIEW_QUESTIONS.md`.
- No company names, internal numbers or absolute paths (this repo may be public).
