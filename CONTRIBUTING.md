# Contributing to the distribution

This repository contains deployment tooling and documentation for proprietary
Docsie. Contributions here do not change the application's license.

For chart or installation documentation improvements:

1. Describe the problem and affected release in an issue or pull request.
2. Keep changes focused; omit credentials, kubeconfigs, customer data and private images.
3. Check documentation links and shell examples. For chart changes, run the
   distribution's packaging/validation workflow using `requirements-dev.txt`
   and `bash scripts/package-release.sh`.
4. State what you tested: rendered charts, a local install and completed user
   workflows are separate results.

Use versioned image references and preserve generated keys and persistent data
on upgrades. Keep example values consistent with the selected release and mark
unreleased capabilities explicitly. Agent-assisted work should follow [AGENTS.md](AGENTS.md).
