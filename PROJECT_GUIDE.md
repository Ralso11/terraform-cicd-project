# The Complete Guide to This Project
### (Written so anyone, even with zero background, can understand it)

This document explains everything about this project: what it is, why
every single piece exists, what all the tools and words mean, exactly
what commands were run and what they did, every mistake that happened
and why, and how to redo it all from scratch. Read it top to bottom once,
then keep it as a reference forever.

---

## Part 1 — The absolute basics (skip if you already know these)

### What is "the cloud"?
"The cloud" just means: computers owned by a company (like Amazon),
sitting in a warehouse somewhere, that you rent time/space on instead of
owning the computer yourself. AWS (Amazon Web Services) is Amazon's cloud
— it rents out storage, servers, databases, and hundreds of other things,
usually billed by how much you actually use.

### What is Git?
Git is a tool that tracks every change ever made to a set of files, like
an infinite "undo history" with labeled checkpoints. Every checkpoint
(called a "commit") has a message explaining what changed and why. This
lets you go back in time, see exactly what changed and when, and lets
multiple people work on the same files without overwriting each other.

### What is GitHub?
GitHub is a website that hosts your Git project online, so it's backed
up, shareable, and viewable by anyone (if public). Your local Git history
lives on your PC; GitHub is where you "push" (upload) that history to.
It's also where employers/recruiters actually look at your code.

### What is a "repository" (repo)?
Just the name for one project's folder, tracked by Git, hosted on GitHub.
This project's repo is called `terraform-cicd-project`.

### What is Terraform?
Terraform is a tool that lets you describe infrastructure (servers,
storage, networking, etc.) as plain text files, instead of manually
clicking through a website to create each thing by hand. You write "I
want a storage bucket named X," run one command, and Terraform goes and
creates exactly that in AWS (or any other supported cloud). This is
called **Infrastructure as Code (IaC)**.

**Why does IaC matter?** Because:
- It's reproducible — anyone can recreate your exact setup from the code
- It's reviewable — changes can be checked before they happen, like
  proofreading an essay before publishing it
- It's version-controlled — every infrastructure change has a history,
  just like code changes do

### What is CI/CD?
- **CI (Continuous Integration):** automatically checking that new code
  is valid every time it's added — catching mistakes early, automatically.
- **CD (Continuous Deployment/Delivery):** automatically taking validated
  code and actually deploying/publishing it, without a human manually
  running the deployment commands each time.

In this project, GitHub Actions is the tool doing both — it's a robot
that watches your repo and runs a checklist of commands every time you
push new code.

---

## Part 2 — What this specific project builds

In one sentence: **a small website, hosted securely on AWS, built and
published completely automatically whenever you push code.**

### The architecture — plain-language version

Imagine a library:
- **The S3 bucket** is a locked storage room in the back, holding the
  actual books (your website files). The public can't just walk in.
- **CloudFront** is the front desk / librarian. Visitors talk to the
  librarian, never to the storage room directly. The librarian has the
  only key, fetches what's needed, and hands it to the visitor —
  quickly, and over a secure line (HTTPS).
- **The bucket policy** is the written rule at the storage room door:
  "Only the librarian (and specifically THIS librarian, not just anyone
  claiming to be one) is allowed in."

### Why not simpler alternatives?

| Alternative | Why we didn't use it |
|---|---|
| Public S3 bucket (no CloudFront) | Anyone could directly access/enumerate your files; a common real-world security mistake |
| A traditional web server (EC2) | Needs constant patching/maintenance, and costs money even with zero visitors, since it's always "on" |
| Manually uploading files via AWS website | Not reproducible, not automated, nothing recruiters can review as "skill evidence" |

---

## Part 3 — Every tool and account involved, and why

| Tool/Account | What it is | Why we needed it |
|---|---|---|
| Git | Change-tracking tool | To save and organize every step of the project |
| GitHub | Hosts the repo online | So the code is backed up, visible, and can trigger automation |
| GitHub Actions | Automation robot | Runs Terraform automatically on every push |
| AWS account (real, not Builder ID) | Where the actual infrastructure lives | Builder ID is course-only and can't create real resources |
| AWS Budgets | A spending watchdog | Alerts immediately if anything might cost money |
| IAM (Identity and Access Management) | AWS's permissions system | Lets us create a limited login just for this project, instead of using the all-powerful root login |
| Terraform | Infrastructure-as-code tool | Describes and builds the AWS resources from text files |
| S3 (Simple Storage Service) | File storage | Holds the website's files |
| CloudFront | Content Delivery Network (CDN) | Serves the site fast, worldwide, over HTTPS, and is the only thing allowed to read the bucket |

---

## Part 4 — The full step-by-step story, with every command explained

### Step 1 — Fixing Git on the work PC

**Problem:** the work PC's home folder pointed to a company network
drive that wasn't accessible, so Git couldn't save your name/email
settings (needed so every change is credited to you).

**What we ran:**
```
git config --file "/c/Users/<your-user>/.gitconfig" user.name "Ralso11"
```
**In plain words:** "Git, please write the setting `user.name = Ralso11`
directly into this specific file, instead of trying to find the default
settings file yourself" (which was failing because that default location
was the broken network path).

### Step 2 — Creating the GitHub repo and connecting to it

**What we did:** created a new, empty repository on github.com named
`terraform-cicd-project`, then ran:
```
git clone https://github.com/Ralso11/terraform-cicd-project.git
```
**In plain words:** "download a copy of this (currently empty) online
project onto my computer, so I can add files to it locally and then send
them back up."

### Step 3 — Writing the Terraform files

Four files were created inside a `terraform/` folder:

**`providers.tf`** — tells Terraform which cloud to talk to (AWS) and
which version of the AWS toolkit to use.
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = var.aws_region
}
```
*Why pin a version range (`~> 5.0`)?* So that if AWS releases a new major
version of their toolkit later, it can't silently change behavior and
break this project without you noticing.

**`variables.tf`** — reusable, named settings:
```hcl
variable "aws_region" {
  default = "eu-central-1"
}
variable "project_name" {
  default = "terraform-cicd-project"
}
variable "environment" {
  default = "dev"
}
```
*Why use variables instead of typing values directly everywhere?*
Change the region once here, and every resource that uses
`var.aws_region` updates automatically — instead of hunting through every
file to change it in ten places.

**`main.tf`** — the actual blueprint. Key resources:
- `aws_s3_bucket` — creates the storage bucket
- `aws_s3_bucket_public_access_block` — explicitly locks it from any
  public access
- `aws_cloudfront_origin_access_control` (OAC) — creates a secure
  "identity" that CloudFront will use to prove it's really CloudFront
  when reading from the bucket
- `aws_cloudfront_distribution` — the actual CDN sitting in front of
  the bucket
- `aws_s3_bucket_policy` (added later, see Step 10) — the door rule that
  actually lets CloudFront in

**`outputs.tf`** — prints useful info after building, like the site's
web address, so you don't have to hunt for it manually in the AWS
website.

### Step 4 — `.gitignore`

A file that tells Git "never track these." We excluded:
- Terraform's local cache folder (`.terraform/`)
- Terraform's `state` file (explained in Step 9) — this can contain
  sensitive details and should never be public

### Step 5 — First commit and push

```
git add .
git commit -m "Add core Terraform config: S3 + CloudFront static site infrastructure"
git push
```
- `git add .` — "include every changed file in the next checkpoint"
- `git commit -m "..."` — "create that checkpoint, with this description"
- `git push` — "upload this checkpoint from my PC to GitHub"

### Step 6 — Setting up the real AWS account

1. Created a real AWS account (separate from the free "Builder ID" used
   for courses, which has no billing and can't build real infrastructure).
2. Set up a **zero-spend budget alert** — an email that fires the moment
   anything would cost money, so surprises are caught within hours.
3. Created a dedicated IAM user, `terraform-deployer`:
   - No AWS website (console) login — only programmatic access via keys
   - Only two permissions: `AmazonS3FullAccess` and `CloudFrontFullAccess`
   - **Why not just use the root account (which can do literally
     everything)?** This is called the *principle of least privilege*.
     If these specific keys were ever stolen or leaked, the damage is
     limited to only S3 and CloudFront — not your entire AWS account,
     billing settings, or anything else.
4. Generated an Access Key ID + Secret Access Key for this user (a
   username/password pair, essentially) and stored them as **GitHub
   Secrets** (Settings → Secrets and variables → Actions) — never
   written into any file in the actual code.

### Step 7 — Writing the CI/CD pipeline

File: `.github/workflows/terraform.yml`. In plain words, this file tells
GitHub: "every time someone pushes to `main`, do this checklist
automatically, on a temporary computer you spin up just for this."

**The `plan` stage (always runs, always safe):**
1. Download the code
2. Install Terraform
3. Log into AWS (using the stored secret keys)
4. Check formatting (`terraform fmt -check`)
5. Download the AWS plugin (`terraform init`)
6. Check the code is valid (`terraform validate`)
7. Show exactly what *would* be built or changed (`terraform plan`) —
   without actually doing it

**The `apply` stage (only runs after a human approves):**
1. Actually build/update the real infrastructure (`terraform apply`)
2. Upload the website file to S3

**The approval pause** comes from a GitHub "Environment" named
`production`, configured with a "required reviewer" (you). This is what
makes GitHub stop and wait for a click before anything real happens —
a deliberate safety design, standard in real companies.

### Step 8 — First real problem: "bucket already exists"

**What happened:** the second time the pipeline ran, it tried to create
the same S3 bucket and security settings again — and AWS refused, saying
they already existed.

**Why:** Terraform keeps a memory file (the **state file**) of exactly
what it has already built, so it never tries to duplicate things. But
this memory was only being stored temporarily, on the throwaway computer
GitHub spins up for each run — once that computer was destroyed after
the run finished, the memory was gone too.

**The fix:** we created one more, separate S3 bucket
(`ralso11-terraform-state-2026`) whose only job is to permanently store
this memory file. We added a `backend.tf` file telling Terraform to use
it:
```hcl
terraform {
  backend "s3" {
    bucket = "ralso11-terraform-state-2026"
    key    = "terraform-cicd-project/terraform.tfstate"
    region = "eu-central-1"
  }
}
```
Now every pipeline run — no matter which temporary computer executes it —
reads and writes the same shared memory, so it always knows what already
exists.

We also had to manually delete the half-created resources from the
failed run (via the AWS website) so the pipeline could rebuild everything
cleanly with the new shared memory tracking it correctly from the start.

### Step 9 — Second real problem: "Access Denied" on the live site

**What happened:** everything deployed successfully, but visiting the
website showed an `AccessDenied` XML error instead of the page.

**Why:** we had created the Origin Access Control (an "identity card" for
CloudFront), but we never actually told the S3 bucket "trust this
identity card and let it read files." It's the difference between
issuing someone a key and actually registering that key with the lock —
without registering it, the lock still refuses entry even to the correct
key.

**The fix:** added a new resource to `main.tf`:
```hcl
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipal"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
        }
      }
    }]
  })
}
```
**In plain words:** "allow anything claiming to be CloudFront to read
files from this bucket — but only if it's genuinely coming from THIS
exact CloudFront distribution (checked via its unique ID), not any
CloudFront distribution anywhere."

After this deployed, the site worked.

---

## Part 5 — Command glossary (every command used, explained)

| Command | Plain-language meaning |
|---|---|
| `git clone <url>` | Download a copy of an online repo to your computer |
| `git add .` | Mark all changed files to be included in the next save point |
| `git commit -m "..."` | Create that save point, with a description |
| `git push` | Upload your save points to GitHub |
| `git status` | Show what's changed and what's staged |
| `git log -1` | Show the most recent save point's details |
| `mkdir <name>` | Create a new folder |
| `cd <name>` | Move into a folder |
| `touch <file>` | Create a new, empty file |
| `nano <file>` | Open a file in a simple text editor inside the terminal |
| `cat <file>` | Print a file's contents to the screen |
| `cat > file << 'EOF' ... EOF` | Write a whole block of text into a file in one go |
| `terraform init` | Download the plugins Terraform needs (e.g. the AWS toolkit) |
| `terraform plan` | Show what would change, without changing anything |
| `terraform apply` | Actually make the real changes |
| `terraform fmt -check` | Check the code is formatted consistently |
| `terraform validate` | Check the code is written correctly (no typos/syntax errors) |

---

## Part 6 — How to explain this project in your own words (for interviews)

A short version you could say out loud:

> "I built a static website hosted on AWS using S3 and CloudFront, with
> the infrastructure fully defined as code using Terraform. I set up a
> GitHub Actions pipeline that automatically validates and plans any
> infrastructure change on every push, and requires manual approval
> before actually deploying — so nothing risky happens without a human
> checkpoint. Along the way I dealt with real issues like managing
> Terraform state remotely so multiple pipeline runs share the same
> memory, and fixing an access-control gap between CloudFront and S3."

That one paragraph demonstrates: IaC, CI/CD, cloud security awareness,
and real debugging experience — exactly what gets you noticed.

---

## Part 7 — How to reproduce this entire project from zero

1. Install Git and Terraform on your computer.
2. Create a new GitHub repository, then `git clone` it locally.
3. Create a real AWS account (not a Builder ID), set a budget alert.
4. In IAM, create a limited user with only S3 + CloudFront permissions,
   generate its access keys.
5. Add those keys as GitHub repo secrets (`AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY`).
6. Create a separate S3 bucket to hold Terraform's state; write a
   `backend.tf` pointing to it.
7. Write `providers.tf`, `variables.tf`, `main.tf` (including the bucket
   policy from the start this time!), and `outputs.tf`.
8. Write `.github/workflows/terraform.yml` with a `plan` job and an
   `apply` job gated behind a protected GitHub Environment.
9. Push, approve the deployment, and visit your new CloudFront URL.

---

*This document, together with the repo's README.md, is meant to be
everything you need to fully understand, explain, and rebuild this
project — even after months away from it.*
