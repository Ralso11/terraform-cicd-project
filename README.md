# Terraform CI/CD Project

A hands-on DevOps portfolio project: a static website hosted on AWS, with its
infrastructure defined as code (Terraform) and deployed automatically through
a CI/CD pipeline (GitHub Actions).

This project exists to demonstrate a real-world cloud workflow end to end —
not just "clicking around in the AWS Console," but defining infrastructure in
version-controlled code, and safely automating how it gets deployed.

## Why this project exists

Two skills matter most for a remote cloud/DevOps role:

1. **Infrastructure as Code (IaC)** — proving infrastructure can be defined,
   reviewed, and reproduced from code instead of manual console clicks.
2. **CI/CD** — proving that deployments can be automated safely, with review
   steps, instead of someone manually running commands from their laptop.

This repo combines both intentionally, in one project, because in real jobs
they're not separate skills — Terraform defines *what* to build, and the
pipeline automates *how* it gets built and kept up to date.

## Architecture

- **Amazon S3** — stores the static website files. The bucket itself is
  fully private (no public access at all).
- **Amazon CloudFront** — a CDN that sits in front of the S3 bucket, serves
  the site over HTTPS globally, and is the *only* thing allowed to read from
  the bucket.
- **Origin Access Control (OAC)** — the modern, secure way to let CloudFront
  read from a private S3 bucket, instead of making the bucket public.

```
Visitor → CloudFront (HTTPS) → S3 bucket (private)
```

### Why S3 + CloudFront instead of an EC2 server?

- No server to patch, manage, or leave running (and accidentally get billed
  for).
- S3 storage costs fractions of a cent for a small site; CloudFront's free
  tier covers plenty of traffic for a portfolio project.
- It's the standard, recommended AWS pattern for static sites — showing
  awareness of this matters more to reviewers than knowing how to spin up a
  bare EC2 instance.

### Why keep the S3 bucket private + use OAC?

A public S3 bucket is a common real-world misconfiguration and security
risk. Using CloudFront + OAC to be the only path to the bucket reflects
current AWS best practice, not an outdated pattern (like the older, now
discouraged Origin Access Identity or public bucket policies).

## Repository structure

```
terraform-cicd-project/
├── terraform/
│   ├── providers.tf     # Which provider (AWS) and version constraints
│   ├── variables.tf     # Reusable input values (region, project name, environment)
│   ├── main.tf          # The actual infrastructure: S3 bucket + CloudFront
│   └── outputs.tf       # Useful info printed after deployment (site URL, bucket name)
├── .gitignore           # Prevents committing Terraform state/secrets
└── README.md
```

## File-by-file explanation

### `terraform/providers.tf`
Declares that this project uses the AWS provider (pinned to `~> 5.0`, so a
future major version can't silently break the code) and a minimum Terraform
version (`>= 1.5.0`) to avoid "works on my machine" issues.

### `terraform/variables.tf`
Defines reusable, named values instead of hardcoding them throughout the
code:
- `aws_region` — defaults to `eu-central-1` (Frankfurt), the closest AWS
  region to Germany.
- `project_name` — used to consistently name and tag every resource.
- `environment` — lets the same code deploy a `dev` or `prod` copy later
  just by changing one value, without duplicating files.

### `terraform/main.tf`
The actual infrastructure:
- An S3 bucket, named uniquely per project/environment, with **all public
  access explicitly blocked**.
- A CloudFront Origin Access Control (OAC), which is what lets CloudFront
  read from the private bucket securely.
- A CloudFront distribution in front of the bucket, forcing HTTPS
  (`redirect-to-https`) and using CloudFront's free default SSL certificate.

### `terraform/outputs.tf`
Prints the site's CloudFront URL and the S3 bucket name after a successful
deploy, so there's no need to dig through the AWS Console to find them.

### `.gitignore`
Excludes Terraform's local cache (`.terraform/`) and state files
(`*.tfstate`). State files can contain sensitive details about real
infrastructure and should never be committed to a public repo — in a
production setup, state is stored in a secure remote backend instead (a
planned future step in this project, see Roadmap).

## Project log

Chronological record of what was done and why, kept up to date as the
project progresses.

1. **Repo created** — `terraform-cicd-project` on GitHub, separate from
   other repos, scoped specifically to this Terraform + CI/CD project.
2. **Local Git setup** — connected a work PC to GitHub over HTTPS;
   configured Git identity (name/email) locally per-repo due to a
   corporate-network home-directory permission quirk (`HOME` pointed to a
   non-writable network share).
3. **Core Terraform files written** — `providers.tf`, `variables.tf`,
   `main.tf`, `outputs.tf` — defining the private S3 bucket + CloudFront
   static site architecture described above.
4. **`.gitignore` added** — to keep Terraform state and cache files out of
   version control.
5. **First commit pushed** — "Add core Terraform config: S3 + CloudFront
   static site infrastructure."
6. **AWS account set up** — a real AWS account was created (separate from
   an existing free AWS Builder ID, which only covers learning content and
   cannot run real infrastructure), with a **zero-spend budget alert** so
   any unexpected cost triggers an email immediately.
7. **A dedicated, restricted IAM user was created** (`terraform-deployer`)
   for Terraform to use, instead of the AWS root account. It has:
   - No AWS Console (website) login — programmatic access only, via keys.
   - Only two permissions attached: `AmazonS3FullAccess` and
     `CloudFrontFullAccess` — nothing else.

   **Why not just use the root account?** This follows the *principle of
   least privilege* — a core cloud security concept. If these specific
   keys were ever leaked, an attacker could only touch S3 and CloudFront in
   this account, not billing, not other services, not account settings.
   Every real cloud team works this way.
8. **Credentials stored as GitHub Secrets** — the IAM user's access key ID
   and secret access key were added as encrypted repository secrets
   (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) under the repo's
   Settings → Secrets and variables → Actions. GitHub encrypts these,
   never displays them again once saved, and automatically masks them in
   any workflow log output. The actual key values are **never** written to
   any file in this repository — only their names are referenced from the
   pipeline.
9. **GitHub Actions pipeline written** — `.github/workflows/terraform.yml`.
   Explained in detail below.
10. **First pipeline run succeeded** — triggered automatically by a push to
    `main`. The pipeline checked out the code, installed Terraform, logged
    into AWS using the stored secrets, and ran `terraform plan`, which
    reported `Plan: 4 to add, 0 to change, 0 to destroy` — confirming the
    whole chain (code → pipeline → AWS credentials) works correctly.
    **Nothing has been deployed to AWS yet** — `plan` only simulates what
    *would* happen; no `apply` step exists in the pipeline yet by design
    (see Roadmap).

## The CI/CD pipeline, explained

File: `.github/workflows/terraform.yml`

In plain terms: every time code is pushed to the `main` branch, GitHub
automatically spins up a temporary Linux machine and runs these steps in
order:

1. **Checkout code** — downloads the repo's current code onto that machine.
2. **Set up Terraform** — installs the Terraform CLI.
3. **Configure AWS credentials** — logs into AWS using the
   `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets (never visible in
   any log).
4. **Terraform fmt -check** — verifies the code is formatted consistently.
5. **Terraform init** — downloads the AWS provider plugin.
6. **Terraform validate** — checks the code is syntactically correct.
7. **Terraform plan** — simulates what would change in AWS, without
   changing anything for real.

**Why stop at `plan` and not also run `apply`?** `apply` is the only step
that creates or changes real infrastructure. Deliberately leaving it out
for now means every push is 100% safe to test — nothing can accidentally
get created or cost money yet. Adding `apply` with a required manual
approval step is a planned next step (see Roadmap) — this human checkpoint
before touching real infrastructure is a standard, safety-conscious CI/CD
pattern.

## Roadmap (not yet done)

- [ ] Add a manual-approval `apply` step to the pipeline, so pushing code
      can — after a human clicks approve — actually create the real AWS
      infrastructure.
- [ ] Move Terraform state to a remote backend (S3 + DynamoDB locking)
      instead of local state, so state is shared and safe for team/CI use.
- [ ] Add the actual static site content to deploy.
- [ ] Add cost/security scanning tools to the pipeline (e.g. `tflint`,
      `checkov`) as an extra quality gate.

## How to reproduce this project

1. Clone this repo.
2. Install [Terraform](https://developer.hashicorp.com/terraform/downloads)
   and configure AWS credentials locally (`aws configure`, or environment
   variables).
3. `cd terraform`
4. `terraform init` — downloads the AWS provider.
5. `terraform plan` — shows what would be created, without creating it.
6. `terraform apply` — creates the real infrastructure (this will incur
   minimal AWS costs — see the Roadmap for the free-tier/budget-alert
   safeguard being added).
