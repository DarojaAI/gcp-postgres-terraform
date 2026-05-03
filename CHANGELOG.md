# Changelog

## [4.0.0](https://github.com/DarojaAI/gcp-postgres-terraform/compare/v3.0.1...v4.0.0) (2026-05-03)


### ⚠ BREAKING CHANGES

* Existing deployments will lose data on apply. Users must backup before applying and restore after.
* Existing deployments using defaults will have VM replaced on upgrade. Set disk_type = "pd-standard" to preserve behavior.
* network_id, subnet_id, and subnet_cidr are now required variables. The caller (GitHub Actions workflow) must fetch existing infrastructure IDs and pass them via TF_VAR_* environment variables. This ensures terraform count expressions are deterministic at plan time.
* gcp-postgres-terraform no longer creates its own VPC, Cloud NAT, or VPC Access Connector. These are now exclusively managed by vpc-infra module.

### Features

* add backwards compatibility outputs for postgres_internal_ip and postgres_password_secret ([bf07787](https://github.com/DarojaAI/gcp-postgres-terraform/commit/bf07787a46b2a72f381a39fd98b2371008c624de))
* add Checkov security scanning to pre-commit hooks ([08e7ac2](https://github.com/DarojaAI/gcp-postgres-terraform/commit/08e7ac2e5293e35f8ce237110d6e83bfe39a758a))
* Add deployment health check with enhanced startup script ([88f0e82](https://github.com/DarojaAI/gcp-postgres-terraform/commit/88f0e82ea020b8e0c300cf6fee1aeb7f9321dcf2))
* add idempotent init script and deeper validator (PR2 + PR4) ([e9a4045](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e9a40458dce5f5114a6dc60657efb25136e47b7e))
* add nat_project_id variable for NAT preflight check ([3f1adb5](https://github.com/DarojaAI/gcp-postgres-terraform/commit/3f1adb571bfa9afe48b06fbee86d9e234eb40901))
* add optional network/subnet ID inputs to root module ([66f38d0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/66f38d04776dfe4787842a502ea894fcefbb2a3d))
* add preflight checks for NAT validation and GHA IP gating ([9d577f1](https://github.com/DarojaAI/gcp-postgres-terraform/commit/9d577f162d712d41dc77c378d63bcf1462ff572b))
* add repo_prefix and environment variables for naming ([f29283e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f29283e310d7b2f097d55b25a1c7ae2ec2a29953))
* add Secret Manager auto-sync and verification outputs ([13f5c91](https://github.com/DarojaAI/gcp-postgres-terraform/commit/13f5c91b51ec5e95cda32b9fe3a84dd9372017a0))
* add tflint validation to catch provider schema issues ([4a3fc34](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4a3fc3429b969b76fa3c2a01fad4715ac2361a47))
* Add version tracking (2.0.0) and update to google provider 7.0 ([8cc0a4c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/8cc0a4c8de78b7fc6a94be08e0d0bad6184976e4))
* add workflow_dispatch and Checkov to pre-commit CI ([265aa42](https://github.com/DarojaAI/gcp-postgres-terraform/commit/265aa42db264893f7f29e5992c7a458835ee795c))
* add workflow_dispatch to release-please workflow ([e6e4747](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e6e4747c7cbaea31f49b8a5d1bcbfbc55b64b085))
* force PostgreSQL data directory to persistent disk ([18296a3](https://github.com/DarojaAI/gcp-postgres-terraform/commit/18296a3118ced2e6f62373d41265da5c1913a29e))
* support existing VPC and subnet in postgres module ([1abbe4b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/1abbe4bd6be0045212237f5c28d90921eab5b6a1))
* update production defaults for better security and performance ([6cc5713](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6cc571338defab0ca57dbe46b666e1837c9f6a54))


### Bug Fixes

* add explicit attribute_condition to WIF provider ([ab22525](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ab22525ac04b65e2e30ce75360818d2d6c3c9e5d))
* add fetch-tags to checkout and improve pre-commit workflow ([0c9b4a0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0c9b4a032579c6dd3848d1f454162f8c6ea4c78a))
* add GitHub Actions IP filtering for firewall ([#3](https://github.com/DarojaAI/gcp-postgres-terraform/issues/3)) ([a59df83](https://github.com/DarojaAI/gcp-postgres-terraform/commit/a59df8327e40e456b68c250658894cf17d44fcb6))
* add INTERNAL_IP to templatefile vars map ([#6](https://github.com/DarojaAI/gcp-postgres-terraform/issues/6)) ([dca50d4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/dca50d4e1a5f7cd78fdb01da5e65779d20616613))
* add missing provider constraints for http and null ([194fc4b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/194fc4b4ff604c0d3b2f0976bd0396adc72a94ae))
* add missing retry_delay variable to templatefile call in postgres_module.tf ([0b742ea](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0b742ea4b53bc97f5447e86b8810858aa263fdd1))
* add optional github_actions_backup_reader_sa variable for bucket IAM ([#8](https://github.com/DarojaAI/gcp-postgres-terraform/issues/8)) ([d2c4e03](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d2c4e03e05fbf4c463e043202f4eb35c2ef9f4cc))
* add postgres_password_secret output with full Secret Manager reference ([a6ab209](https://github.com/DarojaAI/gcp-postgres-terraform/commit/a6ab2091cfb74eaa2eca115f2dc165558cec5086))
* add pre-commit workflow and simplify hooks to avoid git fetch errors ([fbc1a36](https://github.com/DarojaAI/gcp-postgres-terraform/commit/fbc1a369624bdfc39cb12280ef0ff3adb9d8e99d))
* add project = var.project_id to all project-scoped resources in postgres_module.tf ([18ecb7a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/18ecb7abe527e4fed28ff1d4fbe0bc554501f13b))
* add project to google_compute_network and region to google_compute_resource_policy ([ee9da9e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ee9da9ea43c9656e4b4b8001fbbf5f890a0becb5))
* add project to google_compute_router and google_compute_router_nat ([f3a882f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f3a882fd342026cbcc2516ac37ab3bf3ab88423a))
* add project to google_monitoring_alert_policy ([617be67](https://github.com/DarojaAI/gcp-postgres-terraform/commit/617be67ac78ef0d3e42f563e651a8ee517c139ac))
* add release-type to Release Please workflow ([6f0f2fb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6f0f2fb680fa83ed45584f918705486893bb4a39))
* add required router argument to NAT data source ([d8b0b8a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d8b0b8af1a0c31e353c34d3fe24c616cc4669e51))
* add SA data-source fallback for idempotent apply when SA pre-exists ([f9ae836](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f9ae836bd102a7933824b24d295537d3714039b6))
* adopt Terraform standard module structure ([fc0f302](https://github.com/DarojaAI/gcp-postgres-terraform/commit/fc0f3026e48758be484d0d0f73064edd7d5923d1))
* apply 5000 CIDR limit to SSH firewall rule ([#41](https://github.com/DarojaAI/gcp-postgres-terraform/issues/41)) ([8495187](https://github.com/DarojaAI/gcp-postgres-terraform/commit/849518756e09d2fe2a2a9c9eb9b59b8ba602efbb))
* correct output names to match nested module outputs ([5f5cf61](https://github.com/DarojaAI/gcp-postgres-terraform/commit/5f5cf61c18f973c7d4193084c2cfdce61d3c98cc))
* correct root wrapper outputs to match actual nested module exports ([3944fe4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/3944fe4074bb70384b7cfec2befe3a6cca02c3f9))
* correct WIF pool attribute mapping — google.subject=repo→sub, remove environment ([f9efa37](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f9efa3787e19395292edea3cf828b3d857d7de3e))
* disable warnings for unused declarations and provider constraints ([d0a089a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d0a089a2cba3b7315eb24596cd9d5dbe0db32578))
* eliminate count non-determinism by requiring network_id and subnet_id ([c78b1ba](https://github.com/DarojaAI/gcp-postgres-terraform/commit/c78b1ba26152280db49dca320554ddcc7984416c))
* escape all shell variable references for Terraform templatefile ([ca3796f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ca3796fe4e951461627295452ff058d44a172b22))
* escape dollar signs for terraform templatefile compatibility ([e181ce0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e181ce00ddc938cc1867336be114225e9f26cb75))
* escape INTERNAL_IP shell variable for terraform templatefile ([c6e14fd](https://github.com/DarojaAI/gcp-postgres-terraform/commit/c6e14fdc44e1b771295da00c30f24b2149bb78ce))
* escape shell variable references in postgres_init.sh that Terraform's templatefile was misinterpreting ([b3a6a5b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b3a6a5b0a39a5cb6a655704d985c9636bf514d02))
* extract Python scripts to separate files to fix YAML parsing error ([dcb7c1a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/dcb7c1ac7a3b37c0354814f36828990b38cb36a9))
* limit GitHub Actions IPs to 5000 (GCP firewall rule limit) ([#38](https://github.com/DarojaAI/gcp-postgres-terraform/issues/38)) ([04cfc03](https://github.com/DarojaAI/gcp-postgres-terraform/commit/04cfc03ee928279b79dc80e20423d078340e3a3c))
* make network/subnet data sources optional with direct ID inputs ([b6c8ec8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b6c8ec800dafd8c058cbbc13f312e6fbc7687d0b))
* monitoring dashboard tiles use explicit xPos/yPos to avoid overlap ([6f0e8f7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6f0e8f7ab79443ace2e36977e5f49e9f223383d2))
* only map google.subject, restrict repo access via google.subject.has('repo:owner/repo') ([243f4eb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/243f4eb98ea8e0a431ef8c36724662667cf9689e))
* pass db_password to postgres_init.sh and fix CREATE USER ([6bbbc3c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6bbbc3cecc4d1551a3b0494acbe29852186b50d3))
* pass db_password to postgres_init.sh so CREATE USER uses the actual password ([cfe5885](https://github.com/DarojaAI/gcp-postgres-terraform/commit/cfe5885922d0f3ba921a3a777438827f46a33ad0))
* prevent bash $PID corruption in run_step() and add DOLLAR template var ([a8c6148](https://github.com/DarojaAI/gcp-postgres-terraform/commit/a8c6148baa56102ba094a62f6f16aea27998b2e3))
* prevent trailing newlines in secrets, add validation ([8de62f4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/8de62f4ade21a05a257daadff7b99d3d1893d167))
* **provisioner:** trim trailing newlines from secret validation ([f7028e4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f7028e446f582e08f5c5f8312a4730a22afcf5b7))
* remove broken attribute_condition from WIF provider ([07c9cf6](https://github.com/DarojaAI/gcp-postgres-terraform/commit/07c9cf6b5017917f868677d8b6226966ac729c8c))
* remove deprecated empty provider block from versions.tf ([910cc26](https://github.com/DarojaAI/gcp-postgres-terraform/commit/910cc26c13822dcb16241bf27939bc7f64cb2d06))
* remove duplicate outputs.tf (use main.tf instead) ([843c493](https://github.com/DarojaAI/gcp-postgres-terraform/commit/843c493680df32ecd8f282d4aa42d334eb7bc908))
* remove duplicate project entries in google_compute_router and google_compute_router_nat ([ad3a8c8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ad3a8c86770291b89901d007c85924ae9aac6ffb))
* remove invalid reference to google_vpc_access_connector that was deleted in refactor ([1511576](https://github.com/DarojaAI/gcp-postgres-terraform/commit/1511576fb681ebbb48e1b80e553af8ae28fb88b3))
* remove non-existent tflint rules (rules are enabled by default in v0.39.0) ([16df46c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/16df46c25d4dfb4bb6f52c7f2aaeb331176ad1e1))
* remove redundant null_resource that caused secret version growth ([24c7e3f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/24c7e3ff43f97252b61a8bc01e639d3e05c446c0))
* remove trailing whitespace from all files ([f7932d7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f7932d73edc99b064fecc70ad2fca05e7c520df7))
* remove WIF from postgres module ([f6492bf](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f6492bfc81304ea41929a5bf9465184f4c985641))
* remove WIF resources from postgres module ([26e2ed8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/26e2ed89f2967e0302c73361bc6d4a16c84ad56e))
* remove WIF resources from postgres module ([#7](https://github.com/DarojaAI/gcp-postgres-terraform/issues/7)) ([4c15eb7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4c15eb7bef270b44ec105853368b85472c6ee8b1))
* set initial-version to 1.31.0 for Release Please ([2da9825](https://github.com/DarojaAI/gcp-postgres-terraform/commit/2da98254e7bb6f20e565209d31c581c672527124))
* simplify root outputs to avoid duplicates with nested module ([4f7695e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4f7695e300cbcd481d575762f4dc8c3f7d828ca5))
* strip attribute_mapping to google.subject only, use google.subject.has() for repo restriction ([243f4eb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/243f4eb98ea8e0a431ef8c36724662667cf9689e))
* truncate service account name to 30 char GCP limit ([6cb45b2](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6cb45b2bb5b175feaa65d677d7b33fddb9236bf4))
* use compact() to filter empty strings from CIDR lists ([1c6994c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/1c6994c540d31aeb4e1cfaa9ebdd3e8ebcdf56b2))
* use distinct() length for slice() end index bounds check ([62410a5](https://github.com/DarojaAI/gcp-postgres-terraform/commit/62410a57ce21865ab5659d6353f5ad68949f3487))
* use GITHUB_TOKEN instead of missing RELEASE_PLEASE_TOKEN ([778c533](https://github.com/DarojaAI/gcp-postgres-terraform/commit/778c533d1ef330d1b34fb5103f1710efb31db230))
* use lowercase retry_delay in templatefile vars (matches bash script) and remove hardcoded RETRY_DELAY=2 since Terraform now passes it ([98fff6a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/98fff6aa7e972243656e6fd7f4de48ecefbed777))
* use min(5000, length()) for github_actions_cidrs slice ([b307933](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b307933292edd17a8ea95e25143cb97ba62aab9b))
* use RELEASE_PLEASE_TOKEN for Release Please action ([865b21a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/865b21afcec383fbb7c7b15dbb498e224456b6dd))
* use rule blocks instead of disable for tflint config ([b9b8b6d](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b9b8b6d5fa1ad2214b1f91fab8f649388c4fcb09))
* use sa_resource_name (full path) for iam_member binding, not just email ([f349195](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f3491955c93b2a01e45a24b5bdf8557a5d0f2e8a))
* use single quotes for template vars to prevent set -u SCRAM password crash ([01f68be](https://github.com/DarojaAI/gcp-postgres-terraform/commit/01f68beba638aaee41dc8f643e656c5371ff7133))


### Reverts

* undo release 0.1.0 from PR [#21](https://github.com/DarojaAI/gcp-postgres-terraform/issues/21) ([2d32f8d](https://github.com/DarojaAI/gcp-postgres-terraform/commit/2d32f8d9a2a58bccd4ea76e57e2a6dd454e75180))


### Code Refactoring

* require vpc-infra module, remove VPC fallback creation ([0bd1fd7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0bd1fd77b3b08343f2324961062c51f6a7906936))

## [3.0.1](https://github.com/DarojaAI/gcp-postgres-terraform/compare/v3.0.0...v3.0.1) (2026-05-02)


### Bug Fixes

* limit GitHub Actions IPs to 5000 (GCP firewall rule limit) ([#38](https://github.com/DarojaAI/gcp-postgres-terraform/issues/38)) ([04cfc03](https://github.com/DarojaAI/gcp-postgres-terraform/commit/04cfc03ee928279b79dc80e20423d078340e3a3c))

## [3.0.0](https://github.com/DarojaAI/gcp-postgres-terraform/compare/v2.0.0...v3.0.0) (2026-05-02)


### ⚠ BREAKING CHANGES

* Existing deployments will lose data on apply. Users must backup before applying and restore after.
* Existing deployments using defaults will have VM replaced on upgrade. Set disk_type = "pd-standard" to preserve behavior.
* network_id, subnet_id, and subnet_cidr are now required variables. The caller (GitHub Actions workflow) must fetch existing infrastructure IDs and pass them via TF_VAR_* environment variables. This ensures terraform count expressions are deterministic at plan time.
* gcp-postgres-terraform no longer creates its own VPC, Cloud NAT, or VPC Access Connector. These are now exclusively managed by vpc-infra module.

### Features

* add backwards compatibility outputs for postgres_internal_ip and postgres_password_secret ([bf07787](https://github.com/DarojaAI/gcp-postgres-terraform/commit/bf07787a46b2a72f381a39fd98b2371008c624de))
* add Checkov security scanning to pre-commit hooks ([08e7ac2](https://github.com/DarojaAI/gcp-postgres-terraform/commit/08e7ac2e5293e35f8ce237110d6e83bfe39a758a))
* Add deployment health check with enhanced startup script ([88f0e82](https://github.com/DarojaAI/gcp-postgres-terraform/commit/88f0e82ea020b8e0c300cf6fee1aeb7f9321dcf2))
* add idempotent init script and deeper validator (PR2 + PR4) ([e9a4045](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e9a40458dce5f5114a6dc60657efb25136e47b7e))
* add nat_project_id variable for NAT preflight check ([3f1adb5](https://github.com/DarojaAI/gcp-postgres-terraform/commit/3f1adb571bfa9afe48b06fbee86d9e234eb40901))
* add optional network/subnet ID inputs to root module ([66f38d0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/66f38d04776dfe4787842a502ea894fcefbb2a3d))
* add preflight checks for NAT validation and GHA IP gating ([9d577f1](https://github.com/DarojaAI/gcp-postgres-terraform/commit/9d577f162d712d41dc77c378d63bcf1462ff572b))
* add repo_prefix and environment variables for naming ([f29283e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f29283e310d7b2f097d55b25a1c7ae2ec2a29953))
* add Secret Manager auto-sync and verification outputs ([13f5c91](https://github.com/DarojaAI/gcp-postgres-terraform/commit/13f5c91b51ec5e95cda32b9fe3a84dd9372017a0))
* add tflint validation to catch provider schema issues ([4a3fc34](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4a3fc3429b969b76fa3c2a01fad4715ac2361a47))
* Add version tracking (2.0.0) and update to google provider 7.0 ([8cc0a4c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/8cc0a4c8de78b7fc6a94be08e0d0bad6184976e4))
* add workflow_dispatch and Checkov to pre-commit CI ([265aa42](https://github.com/DarojaAI/gcp-postgres-terraform/commit/265aa42db264893f7f29e5992c7a458835ee795c))
* add workflow_dispatch to release-please workflow ([e6e4747](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e6e4747c7cbaea31f49b8a5d1bcbfbc55b64b085))
* force PostgreSQL data directory to persistent disk ([18296a3](https://github.com/DarojaAI/gcp-postgres-terraform/commit/18296a3118ced2e6f62373d41265da5c1913a29e))
* support existing VPC and subnet in postgres module ([1abbe4b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/1abbe4bd6be0045212237f5c28d90921eab5b6a1))
* update production defaults for better security and performance ([6cc5713](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6cc571338defab0ca57dbe46b666e1837c9f6a54))


### Bug Fixes

* add explicit attribute_condition to WIF provider ([ab22525](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ab22525ac04b65e2e30ce75360818d2d6c3c9e5d))
* add fetch-tags to checkout and improve pre-commit workflow ([0c9b4a0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0c9b4a032579c6dd3848d1f454162f8c6ea4c78a))
* add GitHub Actions IP filtering for firewall ([#3](https://github.com/DarojaAI/gcp-postgres-terraform/issues/3)) ([a59df83](https://github.com/DarojaAI/gcp-postgres-terraform/commit/a59df8327e40e456b68c250658894cf17d44fcb6))
* add INTERNAL_IP to templatefile vars map ([#6](https://github.com/DarojaAI/gcp-postgres-terraform/issues/6)) ([dca50d4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/dca50d4e1a5f7cd78fdb01da5e65779d20616613))
* add missing provider constraints for http and null ([194fc4b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/194fc4b4ff604c0d3b2f0976bd0396adc72a94ae))
* add missing retry_delay variable to templatefile call in postgres_module.tf ([0b742ea](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0b742ea4b53bc97f5447e86b8810858aa263fdd1))
* add optional github_actions_backup_reader_sa variable for bucket IAM ([#8](https://github.com/DarojaAI/gcp-postgres-terraform/issues/8)) ([d2c4e03](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d2c4e03e05fbf4c463e043202f4eb35c2ef9f4cc))
* add postgres_password_secret output with full Secret Manager reference ([a6ab209](https://github.com/DarojaAI/gcp-postgres-terraform/commit/a6ab2091cfb74eaa2eca115f2dc165558cec5086))
* add pre-commit workflow and simplify hooks to avoid git fetch errors ([fbc1a36](https://github.com/DarojaAI/gcp-postgres-terraform/commit/fbc1a369624bdfc39cb12280ef0ff3adb9d8e99d))
* add project = var.project_id to all project-scoped resources in postgres_module.tf ([18ecb7a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/18ecb7abe527e4fed28ff1d4fbe0bc554501f13b))
* add project to google_compute_network and region to google_compute_resource_policy ([ee9da9e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ee9da9ea43c9656e4b4b8001fbbf5f890a0becb5))
* add project to google_compute_router and google_compute_router_nat ([f3a882f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f3a882fd342026cbcc2516ac37ab3bf3ab88423a))
* add project to google_monitoring_alert_policy ([617be67](https://github.com/DarojaAI/gcp-postgres-terraform/commit/617be67ac78ef0d3e42f563e651a8ee517c139ac))
* add release-type to Release Please workflow ([6f0f2fb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6f0f2fb680fa83ed45584f918705486893bb4a39))
* add required router argument to NAT data source ([d8b0b8a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d8b0b8af1a0c31e353c34d3fe24c616cc4669e51))
* add SA data-source fallback for idempotent apply when SA pre-exists ([f9ae836](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f9ae836bd102a7933824b24d295537d3714039b6))
* adopt Terraform standard module structure ([fc0f302](https://github.com/DarojaAI/gcp-postgres-terraform/commit/fc0f3026e48758be484d0d0f73064edd7d5923d1))
* correct output names to match nested module outputs ([5f5cf61](https://github.com/DarojaAI/gcp-postgres-terraform/commit/5f5cf61c18f973c7d4193084c2cfdce61d3c98cc))
* correct root wrapper outputs to match actual nested module exports ([3944fe4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/3944fe4074bb70384b7cfec2befe3a6cca02c3f9))
* correct WIF pool attribute mapping — google.subject=repo→sub, remove environment ([f9efa37](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f9efa3787e19395292edea3cf828b3d857d7de3e))
* disable warnings for unused declarations and provider constraints ([d0a089a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d0a089a2cba3b7315eb24596cd9d5dbe0db32578))
* eliminate count non-determinism by requiring network_id and subnet_id ([c78b1ba](https://github.com/DarojaAI/gcp-postgres-terraform/commit/c78b1ba26152280db49dca320554ddcc7984416c))
* escape all shell variable references for Terraform templatefile ([ca3796f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ca3796fe4e951461627295452ff058d44a172b22))
* escape dollar signs for terraform templatefile compatibility ([e181ce0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e181ce00ddc938cc1867336be114225e9f26cb75))
* escape INTERNAL_IP shell variable for terraform templatefile ([c6e14fd](https://github.com/DarojaAI/gcp-postgres-terraform/commit/c6e14fdc44e1b771295da00c30f24b2149bb78ce))
* escape shell variable references in postgres_init.sh that Terraform's templatefile was misinterpreting ([b3a6a5b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b3a6a5b0a39a5cb6a655704d985c9636bf514d02))
* extract Python scripts to separate files to fix YAML parsing error ([dcb7c1a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/dcb7c1ac7a3b37c0354814f36828990b38cb36a9))
* make network/subnet data sources optional with direct ID inputs ([b6c8ec8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b6c8ec800dafd8c058cbbc13f312e6fbc7687d0b))
* monitoring dashboard tiles use explicit xPos/yPos to avoid overlap ([6f0e8f7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6f0e8f7ab79443ace2e36977e5f49e9f223383d2))
* only map google.subject, restrict repo access via google.subject.has('repo:owner/repo') ([243f4eb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/243f4eb98ea8e0a431ef8c36724662667cf9689e))
* pass db_password to postgres_init.sh and fix CREATE USER ([6bbbc3c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6bbbc3cecc4d1551a3b0494acbe29852186b50d3))
* pass db_password to postgres_init.sh so CREATE USER uses the actual password ([cfe5885](https://github.com/DarojaAI/gcp-postgres-terraform/commit/cfe5885922d0f3ba921a3a777438827f46a33ad0))
* prevent trailing newlines in secrets, add validation ([8de62f4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/8de62f4ade21a05a257daadff7b99d3d1893d167))
* **provisioner:** trim trailing newlines from secret validation ([f7028e4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f7028e446f582e08f5c5f8312a4730a22afcf5b7))
* remove broken attribute_condition from WIF provider ([07c9cf6](https://github.com/DarojaAI/gcp-postgres-terraform/commit/07c9cf6b5017917f868677d8b6226966ac729c8c))
* remove deprecated empty provider block from versions.tf ([910cc26](https://github.com/DarojaAI/gcp-postgres-terraform/commit/910cc26c13822dcb16241bf27939bc7f64cb2d06))
* remove duplicate outputs.tf (use main.tf instead) ([843c493](https://github.com/DarojaAI/gcp-postgres-terraform/commit/843c493680df32ecd8f282d4aa42d334eb7bc908))
* remove duplicate project entries in google_compute_router and google_compute_router_nat ([ad3a8c8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ad3a8c86770291b89901d007c85924ae9aac6ffb))
* remove invalid reference to google_vpc_access_connector that was deleted in refactor ([1511576](https://github.com/DarojaAI/gcp-postgres-terraform/commit/1511576fb681ebbb48e1b80e553af8ae28fb88b3))
* remove non-existent tflint rules (rules are enabled by default in v0.39.0) ([16df46c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/16df46c25d4dfb4bb6f52c7f2aaeb331176ad1e1))
* remove redundant null_resource that caused secret version growth ([24c7e3f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/24c7e3ff43f97252b61a8bc01e639d3e05c446c0))
* remove trailing whitespace from all files ([f7932d7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f7932d73edc99b064fecc70ad2fca05e7c520df7))
* remove WIF from postgres module ([f6492bf](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f6492bfc81304ea41929a5bf9465184f4c985641))
* remove WIF resources from postgres module ([26e2ed8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/26e2ed89f2967e0302c73361bc6d4a16c84ad56e))
* remove WIF resources from postgres module ([#7](https://github.com/DarojaAI/gcp-postgres-terraform/issues/7)) ([4c15eb7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4c15eb7bef270b44ec105853368b85472c6ee8b1))
* set initial-version to 1.31.0 for Release Please ([2da9825](https://github.com/DarojaAI/gcp-postgres-terraform/commit/2da98254e7bb6f20e565209d31c581c672527124))
* simplify root outputs to avoid duplicates with nested module ([4f7695e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4f7695e300cbcd481d575762f4dc8c3f7d828ca5))
* strip attribute_mapping to google.subject only, use google.subject.has() for repo restriction ([243f4eb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/243f4eb98ea8e0a431ef8c36724662667cf9689e))
* truncate service account name to 30 char GCP limit ([6cb45b2](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6cb45b2bb5b175feaa65d677d7b33fddb9236bf4))
* use GITHUB_TOKEN instead of missing RELEASE_PLEASE_TOKEN ([778c533](https://github.com/DarojaAI/gcp-postgres-terraform/commit/778c533d1ef330d1b34fb5103f1710efb31db230))
* use lowercase retry_delay in templatefile vars (matches bash script) and remove hardcoded RETRY_DELAY=2 since Terraform now passes it ([98fff6a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/98fff6aa7e972243656e6fd7f4de48ecefbed777))
* use RELEASE_PLEASE_TOKEN for Release Please action ([865b21a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/865b21afcec383fbb7c7b15dbb498e224456b6dd))
* use rule blocks instead of disable for tflint config ([b9b8b6d](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b9b8b6d5fa1ad2214b1f91fab8f649388c4fcb09))
* use sa_resource_name (full path) for iam_member binding, not just email ([f349195](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f3491955c93b2a01e45a24b5bdf8557a5d0f2e8a))


### Reverts

* undo release 0.1.0 from PR [#21](https://github.com/DarojaAI/gcp-postgres-terraform/issues/21) ([2d32f8d](https://github.com/DarojaAI/gcp-postgres-terraform/commit/2d32f8d9a2a58bccd4ea76e57e2a6dd454e75180))


### Code Refactoring

* require vpc-infra module, remove VPC fallback creation ([0bd1fd7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0bd1fd77b3b08343f2324961062c51f6a7906936))

## [2.0.0](https://github.com/DarojaAI/gcp-postgres-terraform/compare/gcp-postgres-terraform-v1.39.0...gcp-postgres-terraform-v2.0.0) (2026-05-02)


### ⚠ BREAKING CHANGES

* Existing deployments will lose data on apply. Users must backup before applying and restore after.
* Existing deployments using defaults will have VM replaced on upgrade. Set disk_type = "pd-standard" to preserve behavior.
* network_id, subnet_id, and subnet_cidr are now required variables. The caller (GitHub Actions workflow) must fetch existing infrastructure IDs and pass them via TF_VAR_* environment variables. This ensures terraform count expressions are deterministic at plan time.
* gcp-postgres-terraform no longer creates its own VPC, Cloud NAT, or VPC Access Connector. These are now exclusively managed by vpc-infra module.

### Features

* add backwards compatibility outputs for postgres_internal_ip and postgres_password_secret ([bf07787](https://github.com/DarojaAI/gcp-postgres-terraform/commit/bf07787a46b2a72f381a39fd98b2371008c624de))
* add Checkov security scanning to pre-commit hooks ([08e7ac2](https://github.com/DarojaAI/gcp-postgres-terraform/commit/08e7ac2e5293e35f8ce237110d6e83bfe39a758a))
* Add deployment health check with enhanced startup script ([88f0e82](https://github.com/DarojaAI/gcp-postgres-terraform/commit/88f0e82ea020b8e0c300cf6fee1aeb7f9321dcf2))
* add idempotent init script and deeper validator (PR2 + PR4) ([e9a4045](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e9a40458dce5f5114a6dc60657efb25136e47b7e))
* add nat_project_id variable for NAT preflight check ([3f1adb5](https://github.com/DarojaAI/gcp-postgres-terraform/commit/3f1adb571bfa9afe48b06fbee86d9e234eb40901))
* add optional network/subnet ID inputs to root module ([66f38d0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/66f38d04776dfe4787842a502ea894fcefbb2a3d))
* add preflight checks for NAT validation and GHA IP gating ([9d577f1](https://github.com/DarojaAI/gcp-postgres-terraform/commit/9d577f162d712d41dc77c378d63bcf1462ff572b))
* add repo_prefix and environment variables for naming ([f29283e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f29283e310d7b2f097d55b25a1c7ae2ec2a29953))
* add Secret Manager auto-sync and verification outputs ([13f5c91](https://github.com/DarojaAI/gcp-postgres-terraform/commit/13f5c91b51ec5e95cda32b9fe3a84dd9372017a0))
* add tflint validation to catch provider schema issues ([4a3fc34](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4a3fc3429b969b76fa3c2a01fad4715ac2361a47))
* Add version tracking (2.0.0) and update to google provider 7.0 ([8cc0a4c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/8cc0a4c8de78b7fc6a94be08e0d0bad6184976e4))
* add workflow_dispatch and Checkov to pre-commit CI ([265aa42](https://github.com/DarojaAI/gcp-postgres-terraform/commit/265aa42db264893f7f29e5992c7a458835ee795c))
* add workflow_dispatch to release-please workflow ([e6e4747](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e6e4747c7cbaea31f49b8a5d1bcbfbc55b64b085))
* force PostgreSQL data directory to persistent disk ([18296a3](https://github.com/DarojaAI/gcp-postgres-terraform/commit/18296a3118ced2e6f62373d41265da5c1913a29e))
* support existing VPC and subnet in postgres module ([1abbe4b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/1abbe4bd6be0045212237f5c28d90921eab5b6a1))
* update production defaults for better security and performance ([6cc5713](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6cc571338defab0ca57dbe46b666e1837c9f6a54))


### Bug Fixes

* add explicit attribute_condition to WIF provider ([ab22525](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ab22525ac04b65e2e30ce75360818d2d6c3c9e5d))
* add fetch-tags to checkout and improve pre-commit workflow ([0c9b4a0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0c9b4a032579c6dd3848d1f454162f8c6ea4c78a))
* add GitHub Actions IP filtering for firewall ([#3](https://github.com/DarojaAI/gcp-postgres-terraform/issues/3)) ([a59df83](https://github.com/DarojaAI/gcp-postgres-terraform/commit/a59df8327e40e456b68c250658894cf17d44fcb6))
* add INTERNAL_IP to templatefile vars map ([#6](https://github.com/DarojaAI/gcp-postgres-terraform/issues/6)) ([dca50d4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/dca50d4e1a5f7cd78fdb01da5e65779d20616613))
* add missing provider constraints for http and null ([194fc4b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/194fc4b4ff604c0d3b2f0976bd0396adc72a94ae))
* add missing retry_delay variable to templatefile call in postgres_module.tf ([0b742ea](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0b742ea4b53bc97f5447e86b8810858aa263fdd1))
* add optional github_actions_backup_reader_sa variable for bucket IAM ([#8](https://github.com/DarojaAI/gcp-postgres-terraform/issues/8)) ([d2c4e03](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d2c4e03e05fbf4c463e043202f4eb35c2ef9f4cc))
* add postgres_password_secret output with full Secret Manager reference ([a6ab209](https://github.com/DarojaAI/gcp-postgres-terraform/commit/a6ab2091cfb74eaa2eca115f2dc165558cec5086))
* add pre-commit workflow and simplify hooks to avoid git fetch errors ([fbc1a36](https://github.com/DarojaAI/gcp-postgres-terraform/commit/fbc1a369624bdfc39cb12280ef0ff3adb9d8e99d))
* add project = var.project_id to all project-scoped resources in postgres_module.tf ([18ecb7a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/18ecb7abe527e4fed28ff1d4fbe0bc554501f13b))
* add project to google_compute_network and region to google_compute_resource_policy ([ee9da9e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ee9da9ea43c9656e4b4b8001fbbf5f890a0becb5))
* add project to google_compute_router and google_compute_router_nat ([f3a882f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f3a882fd342026cbcc2516ac37ab3bf3ab88423a))
* add project to google_monitoring_alert_policy ([617be67](https://github.com/DarojaAI/gcp-postgres-terraform/commit/617be67ac78ef0d3e42f563e651a8ee517c139ac))
* add release-type to Release Please workflow ([6f0f2fb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6f0f2fb680fa83ed45584f918705486893bb4a39))
* add required router argument to NAT data source ([d8b0b8a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d8b0b8af1a0c31e353c34d3fe24c616cc4669e51))
* add SA data-source fallback for idempotent apply when SA pre-exists ([f9ae836](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f9ae836bd102a7933824b24d295537d3714039b6))
* adopt Terraform standard module structure ([fc0f302](https://github.com/DarojaAI/gcp-postgres-terraform/commit/fc0f3026e48758be484d0d0f73064edd7d5923d1))
* correct output names to match nested module outputs ([5f5cf61](https://github.com/DarojaAI/gcp-postgres-terraform/commit/5f5cf61c18f973c7d4193084c2cfdce61d3c98cc))
* correct root wrapper outputs to match actual nested module exports ([3944fe4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/3944fe4074bb70384b7cfec2befe3a6cca02c3f9))
* correct WIF pool attribute mapping — google.subject=repo→sub, remove environment ([f9efa37](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f9efa3787e19395292edea3cf828b3d857d7de3e))
* disable warnings for unused declarations and provider constraints ([d0a089a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/d0a089a2cba3b7315eb24596cd9d5dbe0db32578))
* eliminate count non-determinism by requiring network_id and subnet_id ([c78b1ba](https://github.com/DarojaAI/gcp-postgres-terraform/commit/c78b1ba26152280db49dca320554ddcc7984416c))
* escape all shell variable references for Terraform templatefile ([ca3796f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ca3796fe4e951461627295452ff058d44a172b22))
* escape dollar signs for terraform templatefile compatibility ([e181ce0](https://github.com/DarojaAI/gcp-postgres-terraform/commit/e181ce00ddc938cc1867336be114225e9f26cb75))
* escape INTERNAL_IP shell variable for terraform templatefile ([c6e14fd](https://github.com/DarojaAI/gcp-postgres-terraform/commit/c6e14fdc44e1b771295da00c30f24b2149bb78ce))
* escape shell variable references in postgres_init.sh that Terraform's templatefile was misinterpreting ([b3a6a5b](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b3a6a5b0a39a5cb6a655704d985c9636bf514d02))
* extract Python scripts to separate files to fix YAML parsing error ([dcb7c1a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/dcb7c1ac7a3b37c0354814f36828990b38cb36a9))
* make network/subnet data sources optional with direct ID inputs ([b6c8ec8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b6c8ec800dafd8c058cbbc13f312e6fbc7687d0b))
* monitoring dashboard tiles use explicit xPos/yPos to avoid overlap ([6f0e8f7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6f0e8f7ab79443ace2e36977e5f49e9f223383d2))
* only map google.subject, restrict repo access via google.subject.has('repo:owner/repo') ([243f4eb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/243f4eb98ea8e0a431ef8c36724662667cf9689e))
* pass db_password to postgres_init.sh and fix CREATE USER ([6bbbc3c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6bbbc3cecc4d1551a3b0494acbe29852186b50d3))
* pass db_password to postgres_init.sh so CREATE USER uses the actual password ([cfe5885](https://github.com/DarojaAI/gcp-postgres-terraform/commit/cfe5885922d0f3ba921a3a777438827f46a33ad0))
* prevent trailing newlines in secrets, add validation ([8de62f4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/8de62f4ade21a05a257daadff7b99d3d1893d167))
* **provisioner:** trim trailing newlines from secret validation ([f7028e4](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f7028e446f582e08f5c5f8312a4730a22afcf5b7))
* remove broken attribute_condition from WIF provider ([07c9cf6](https://github.com/DarojaAI/gcp-postgres-terraform/commit/07c9cf6b5017917f868677d8b6226966ac729c8c))
* remove deprecated empty provider block from versions.tf ([910cc26](https://github.com/DarojaAI/gcp-postgres-terraform/commit/910cc26c13822dcb16241bf27939bc7f64cb2d06))
* remove duplicate outputs.tf (use main.tf instead) ([843c493](https://github.com/DarojaAI/gcp-postgres-terraform/commit/843c493680df32ecd8f282d4aa42d334eb7bc908))
* remove duplicate project entries in google_compute_router and google_compute_router_nat ([ad3a8c8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/ad3a8c86770291b89901d007c85924ae9aac6ffb))
* remove invalid reference to google_vpc_access_connector that was deleted in refactor ([1511576](https://github.com/DarojaAI/gcp-postgres-terraform/commit/1511576fb681ebbb48e1b80e553af8ae28fb88b3))
* remove non-existent tflint rules (rules are enabled by default in v0.39.0) ([16df46c](https://github.com/DarojaAI/gcp-postgres-terraform/commit/16df46c25d4dfb4bb6f52c7f2aaeb331176ad1e1))
* remove redundant null_resource that caused secret version growth ([24c7e3f](https://github.com/DarojaAI/gcp-postgres-terraform/commit/24c7e3ff43f97252b61a8bc01e639d3e05c446c0))
* remove trailing whitespace from all files ([f7932d7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f7932d73edc99b064fecc70ad2fca05e7c520df7))
* remove WIF from postgres module ([f6492bf](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f6492bfc81304ea41929a5bf9465184f4c985641))
* remove WIF resources from postgres module ([26e2ed8](https://github.com/DarojaAI/gcp-postgres-terraform/commit/26e2ed89f2967e0302c73361bc6d4a16c84ad56e))
* remove WIF resources from postgres module ([#7](https://github.com/DarojaAI/gcp-postgres-terraform/issues/7)) ([4c15eb7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4c15eb7bef270b44ec105853368b85472c6ee8b1))
* set initial-version to 1.31.0 for Release Please ([2da9825](https://github.com/DarojaAI/gcp-postgres-terraform/commit/2da98254e7bb6f20e565209d31c581c672527124))
* simplify root outputs to avoid duplicates with nested module ([4f7695e](https://github.com/DarojaAI/gcp-postgres-terraform/commit/4f7695e300cbcd481d575762f4dc8c3f7d828ca5))
* strip attribute_mapping to google.subject only, use google.subject.has() for repo restriction ([243f4eb](https://github.com/DarojaAI/gcp-postgres-terraform/commit/243f4eb98ea8e0a431ef8c36724662667cf9689e))
* truncate service account name to 30 char GCP limit ([6cb45b2](https://github.com/DarojaAI/gcp-postgres-terraform/commit/6cb45b2bb5b175feaa65d677d7b33fddb9236bf4))
* use GITHUB_TOKEN instead of missing RELEASE_PLEASE_TOKEN ([778c533](https://github.com/DarojaAI/gcp-postgres-terraform/commit/778c533d1ef330d1b34fb5103f1710efb31db230))
* use lowercase retry_delay in templatefile vars (matches bash script) and remove hardcoded RETRY_DELAY=2 since Terraform now passes it ([98fff6a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/98fff6aa7e972243656e6fd7f4de48ecefbed777))
* use RELEASE_PLEASE_TOKEN for Release Please action ([865b21a](https://github.com/DarojaAI/gcp-postgres-terraform/commit/865b21afcec383fbb7c7b15dbb498e224456b6dd))
* use rule blocks instead of disable for tflint config ([b9b8b6d](https://github.com/DarojaAI/gcp-postgres-terraform/commit/b9b8b6d5fa1ad2214b1f91fab8f649388c4fcb09))
* use sa_resource_name (full path) for iam_member binding, not just email ([f349195](https://github.com/DarojaAI/gcp-postgres-terraform/commit/f3491955c93b2a01e45a24b5bdf8557a5d0f2e8a))


### Reverts

* undo release 0.1.0 from PR [#21](https://github.com/DarojaAI/gcp-postgres-terraform/issues/21) ([2d32f8d](https://github.com/DarojaAI/gcp-postgres-terraform/commit/2d32f8d9a2a58bccd4ea76e57e2a6dd454e75180))


### Code Refactoring

* require vpc-infra module, remove VPC fallback creation ([0bd1fd7](https://github.com/DarojaAI/gcp-postgres-terraform/commit/0bd1fd77b3b08343f2324961062c51f6a7906936))
