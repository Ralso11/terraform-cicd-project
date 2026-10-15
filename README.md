# Terraform CI/CD Project

**Live site:** check CloudFront → Distributions in the AWS Console for the
current URL (see note at the bottom on why this URL can change).

📖 Want the full, beginner-friendly walkthrough of every step, command,
and decision made in this project? See
[PROJECT_GUIDE.md](./PROJECT_GUIDE.md).

## What is this project, in one sentence?

A small website that gets built and published automatically: you write
code describing what you want, you push it to GitHub, and a robot
(GitHub Actions) builds it for real on Amazon's servers — safely, and
only after you click "approve."

## Why does this project exist?

To learn and prove two real job skills, using the smallest possible
example:

1. **Infrastructure as Code (Terraform):** instead of clicking around in
   a website (the AWS Console) to create things by hand, you write a text
   file describing what you want, and a tool builds exactly that. This is
   reproducible (anyone can build the same thing from your file) and
   reviewable (you can see exactly what changed, like editing a Word doc
   with Track Changes on).
2. **CI/CD (Continuous Integration / Continuous Deployment):** instead of
   you personally running commands from your laptop every time something
   changes, a robot does it automatically, every time you push code —
   but with a safety pause before anything real happens.

Real cloud/DevOps jobs are built around exactly these two skills. This
project is a small, honest example of both, done the "real" way, not a
shortcut version.

## The big picture — how it all connects

```
You write code  ->  You push to GitHub  ->  GitHub Actions wakes up
       ->  It checks your code is valid (safe, automatic)
       ->  It shows you EXACTLY what would be built (safe, automatic)
       ->  It PAUSES and waits for you to click "Approve"
       ->  Only then does it actually build things in AWS
       ->  It uploads your website files
       ->  Your site is live
```

Nothing expensive or risky happens without you personally clicking
"approve" at least once. That pause is intentional and is a real-world
best practice.

## What actually got built (the architecture)

- **Amazon S3** — think of this as a private storage locker. It holds
  your website's files (just an `index.html` for now). By itself, nobody
  on the internet can see inside this locker — it's locked.
- **Amazon CloudFront** — this is the "front desk." It's the only thing
  with a key to that locker, and it's what visitors actually talk to. It
  also makes the site load fast worldwide and forces secure HTTPS.
- **A security policy connecting them** — a written rule that says
  "CloudFront (and only this specific CloudFront) is allowed to open this
  locker and read files from it." Without this rule, even CloudFront
  gets refused — which is a mistake we actually hit and fixed (see the
  Problems & Fixes section — it's a really common real-world gotcha).

```
Visitor's browser -> (HTTPS) -> CloudFront -> (secure permission) -> S3 (private)
```

### Why build it this way instead of simpler options?

- **Why not just make the S3 bucket public?** A public storage bucket is
  one of the most common real-world security mistakes companies make
  (accidentally exposing private files to the whole internet). Keeping it
  private and only letting CloudFront read it is the responsible,
  professional pattern.
- **Why not a regular web server (EC2)?** A server needs constant
  maintenance, security updates, and keeps costing money while it's
  running, even with no visitors. S3 + CloudFront costs a tiny fraction of
  a cent for a small site and there's no server to babysit.

## Step-by-step: everything we did, in order, and why

### 1. Set up Git identity on the work PC
We told Git "who you are" (name + email), so every change you make is
correctly credited to you.

- **Problem we hit:** the work PC's `HOME` folder pointed at a company
  network drive that wasn't accessible, so Git
  couldn't save settings there.
- **Fix:** we manually pointed Git's config to a real, writable folder on
  the local `C:` drive instead
  (`git config --file "/c/Users/<your-user>/.gitconfig" ...`).
- **Lesson:** company laptops sometimes have unusual folder setups —
  this isn't a sign anything is broken, just something to work around
  once.

### 2. Created a new, dedicated GitHub repository
A repository ("repo") is just a project folder that lives on GitHub and
tracks every change ever made to it. We made a fresh one
(`terraform-cicd-project`), separate from other projects, so this one
stays focused and easy to review on its own.

### 3. Connected the local project folder to GitHub
```
git clone https://github.com/Ralso11/terraform-cicd-project.git
```
This downloaded an empty copy of the repo onto the PC, so local changes
can be tracked and then sent ("pushed") back up to GitHub.

### 4. Wrote the core Terraform files
Four files, each with one job:

| File | What it's for |
|---|---|
| `providers.tf` | Tells Terraform "we're using AWS," and locks a version range so future AWS tool updates don't silently break things. |
| `variables.tf` | Defines reusable settings (region, project name, environment) in one place instead of repeating them everywhere. |
| `main.tf` | The actual blueprint: the S3 bucket, the security settings, the CloudFront setup. |
| `outputs.tf` | After building, prints useful info (like the site's web address) instead of making you hunt for it in the AWS website. |

### 5. Added a `.gitignore`
A `.gitignore` file tells Git "never track these files." We excluded
Terraform's temporary cache folder and its `state` file (explained in
step 8) — these can contain sensitive info and shouldn't be shared
publicly on GitHub.

### 6. First commit and push
```
git add .
git commit -m "Add core Terraform config: S3 + CloudFront static site infrastructure"
git push
```
- `git add .` — stages all the changed files, meaning "include these in
  the next save point."
- `git commit -m "..."` — creates that save point, with a message
  explaining what changed and why. Good messages are themselves part of
  what makes a project look professional.
- `git push` — uploads that save point from the local PC up to GitHub.

### 7. Set up the real AWS account safely
- Created a real AWS account (separate from an existing free "Builder
  ID," which is only for taking courses and can't build real
  infrastructure).
- Immediately set up a **zero-spend budget alert** — an early-warning
  email that fires the instant anything would cost money. This is a
  safety net, not a guarantee, but it means surprises get caught within
  hours, not discovered on a bill weeks later.
- Created a separate, limited login just for this project
  (`terraform-deployer`), instead of using the all-powerful root account.
  This login can only touch S3 and CloudFront — nothing else — and can't
  even log into the AWS website, only use command-line tools. This way,
  if these specific keys were ever leaked, the damage is very limited.
  This is called the "principle of least privilege" and is a standard
  professional security habit.
- Stored that login's two secret keys inside **GitHub Secrets**
  (Settings -> Secrets and variables -> Actions) instead of writing them
  in any file. GitHub encrypts these and never shows them again once
  saved — this is the standard, safe way to hand credentials to
  automation.

### 8. Wrote the CI/CD pipeline (`.github/workflows/terraform.yml`)
This file tells GitHub: "every time someone pushes code to `main`, do
these steps automatically." It has two stages:

**Stage 1 — `plan` (always runs, 100% safe):**
1. Download the code onto a temporary computer
2. Install Terraform
3. Log into AWS using the stored secret keys
4. Check the code is formatted and written correctly
5. Show exactly what *would* be built or changed — without actually
   doing it

**Stage 2 — `apply` (only runs after you approve):**
1. Actually build/update the real infrastructure in AWS
2. Upload the website file into the S3 storage locker

The pause between these two stages is created by a **GitHub
Environment** named `production`, with "required reviewers" turned on —
this is what makes GitHub stop and wait for a human click before
anything real happens.

### 9. Added a state "backend" (shared memory for Terraform)
Terraform needs to remember what it already built, so it doesn't try to
build the same thing twice. This memory is called the **state file**.

- **Problem we hit:** at first, this memory only existed temporarily on
  whatever computer ran Terraform. Once GitHub's temporary computer was
  thrown away after each run, the memory was gone too — so the next run
  tried to create the S3 bucket and security settings *again*, and AWS
  correctly refused ("this already exists").
- **Fix:** we created one extra, dedicated S3 bucket
  (`ralso11-terraform-state-2026`) whose only job is to store this memory
  file permanently, so every run — no matter which computer executes it —
  reads and writes the same shared memory.
- We also had to manually delete the partially-created resources from
  the failed run and let the pipeline rebuild them cleanly with the new
  shared memory in place from the start. In a company setting with real
  users, you'd instead carefully "import" existing resources into the
  new memory instead of deleting them — we chose the simpler path here
  since nothing real depended on those resources yet.

### 10. Fixed the final "Access Denied" error
After everything deployed, visiting the site showed an **Access Denied**
error. The cause: we told CloudFront it's *allowed* to be the only reader
of the bucket (via something called an Origin Access Control), but we
never actually wrote the matching permission rule *on the S3 bucket
itself* granting that access. It's like giving someone a key without
ever registering it with the lock — the key exists, but the lock doesn't
recognize it yet.

**Fix:** added one more resource, an `aws_s3_bucket_policy`, that
explicitly grants read access — but *only* to this exact CloudFront
distribution, not to CloudFront in general and not to the public. After
this deployed, the site worked correctly.

## Problems & fixes — quick reference

| Problem | Why it happened | How we fixed it |
|---|---|---|
| Git couldn't save name/email | Work PC's home folder pointed to an inaccessible network drive | Pointed Git's config file directly to a local folder |
| Pipeline failed: "bucket already exists" | Terraform's memory of what it built only lived temporarily, and got lost between runs | Added a permanent, shared S3 backend to store that memory |
| Site showed "Access Denied" | CloudFront was never actually granted a matching permission on the S3 bucket | Added an S3 bucket policy scoped to that one CloudFront distribution |

## How to reproduce this project yourself

1. Install [Git](https://git-scm.com) and [Terraform](https://developer.hashicorp.com/terraform/downloads).
2. Create a GitHub repo and clone it locally.
3. Create an AWS account, set a budget alert, and create a limited IAM
   user with S3 + CloudFront permissions only.
4. Create a separate S3 bucket to hold Terraform's state, and reference
   it in a `backend.tf` file.
5. Write `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf` as shown
   in this repo.
6. Store your AWS keys as GitHub Secrets.
7. Write a GitHub Actions workflow with a `plan` stage (always runs) and
   an `apply` stage (gated behind a protected "environment" requiring
   manual approval).
8. Push, approve, and check your CloudFront URL.

## A note on the live URL

Every time a CloudFront distribution is destroyed and recreated (which
happened once here, during cleanup), AWS assigns it a **brand new**
`.cloudfront.net` address — the old one stops working permanently. This
is normal and expected; always get the current URL from the AWS Console
rather than relying on ones mentioned earlier in a project's history.

## What's next (possible future additions)

- [ ] Automatically invalidate CloudFront's cache after each deploy, so
      updates show up immediately instead of waiting for the cache to
      expire.
- [ ] Point a real custom domain name at the CloudFront distribution.
- [ ] Add automated security/cost-scanning tools to the pipeline
      (`tflint`, `checkov`).
- [ ] Add a `staging` environment alongside `production`.
