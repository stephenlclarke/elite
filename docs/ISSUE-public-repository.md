# Protect the newly public repository

The public repository initially had unprotected main, unrestricted action selection and disabled secret scanning. Only Stephen had write access. The public contribution path needs pull requests and verified checks without exposing the main-only Sonar secret or requiring a second reviewer in a single-maintainer project.

Implementation: [PR-1-public-repository.md](PR-1-public-repository.md).
