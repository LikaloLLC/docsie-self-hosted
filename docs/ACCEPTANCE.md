# Clean-install acceptance

Use a disposable AWS account/environment explicitly approved by its owner.
Record the source commit, chart packages, image digests, region and Terraform
plan. Do not reuse a customer deployment or assume running pods prove success.

- [ ] Image preflight passes for every rendered image and target architecture.
- [ ] Review and approve the Terraform plan before apply.
- [ ] Complete installation from public instructions without unpublished files.
- [ ] DNS and HTTPS work in a normal browser.
- [ ] Create the initial administrator and workspace; login/logout work.
- [ ] Upload a document and image; browser storage URLs work.
- [ ] Publish and read a knowledge-base page.
- [ ] Ask a grounded KB question using the customer's configured AI endpoint.
- [ ] Run a document comparison and inspect saved results and source references.
- [ ] For full profile, generate documentation from a sample narrated video.
- [ ] Verify license acceptance, expiry, renewal, user limits and data export.
- [ ] Restart workloads and verify data and signing/crypto keys persist.
- [ ] Back up, upgrade and restore a disposable installation.
- [ ] Verify teardown removes intended billable resources and documents retained data.

Store evidence separately from public deployment configuration. Redact secrets,
customer content, account IDs and private hostnames before publishing results.
