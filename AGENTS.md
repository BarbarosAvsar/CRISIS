# Repository workflow

- `main` is the single canonical branch for this project. Work in the existing checkout on `main`; do not create feature branches or worktrees unless the user explicitly changes this policy.
- Keep one canonical implementation of each platform. Do not commit duplicate source snapshots or version-suffixed copies.
- Preserve normal Git commit history. A single branch does not authorize force-pushes, rebases of published history, or deleting commits.
- Commit project source, original assets, documentation, tests, CI and the current deliverable APK. Exclude dependency/build caches, machine-local configuration and duplicate ZIP exports.
- Push or publish only when authorized by the user. Publishing the cloud environment is separate from pushing Git commits.
