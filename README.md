# slack-clauded-status-updater

Rotates your Slack status with a random word from Claude Code's "thinking mode"
vocabulary (e.g. `Flibbertigibbeting`, `Razzmatazzing`, `Spelunking`), on a
schedule, from a small Cloud Function in GCP.

## Architecture

```
Cloud Scheduler ──(OIDC)──▶ Cloud Function (Gen 2, Go) ──▶ Slack users.profile.set
                                       │
                                       └──▶ Secret Manager (xoxp- token)
```

- **Schedule**: `*/5 9-18 * * 1-5` Europe/Paris (every 5 min, 09:00–18:55, weekdays).
- **Auth**: Slack User OAuth token (`xoxp-…`) with the `users.profile:write` scope.
- **Cost**: ~2,500 invocations/month — well inside the GCP free tier.

## Prerequisites

- A GCP project with billing enabled.
- `gcloud` authenticated against that project.
- Terraform ≥ 1.6.
- Go ≥ 1.22 (only used locally to run `go mod tidy`).
- A Slack `xoxp-…` token (see below).

## 1. Get a Slack token

Your workspace requires admin approval for apps, so:

1. Visit <https://api.slack.com/apps> → **Create New App** → **From scratch**.
2. Name it (e.g. *Clauded Status*) and pick your workspace.
3. **OAuth & Permissions** → **User Token Scopes** → add `users.profile:write`.
4. Click **Install to Workspace**. You'll be redirected to a "Request approval"
   screen — write a one-line justification ("Personal status rotator. Only
   writes my own profile status. No data is read.") and submit.
5. Once approved, finish the install and copy the **User OAuth Token**
   (starts with `xoxp-`).

## 2. Deploy

```bash
# 2a. Tidy Go deps so go.sum is part of the build archive
cd function && go mod tidy && cd ..

# 2b. Configure your project
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
$EDITOR terraform/terraform.tfvars   # set project_id

# 2c. Apply
cd terraform
terraform init
terraform apply
```

Terraform will create:

- the GCS source bucket and function archive,
- the Cloud Function (Gen 2, Go 1.22),
- the Cloud Scheduler job,
- a Secret Manager secret (empty for now),
- two service accounts with least-privilege IAM bindings.

## 3. Load your Slack token

The secret is created empty. Add a version with your token:

```bash
printf 'xoxp-YOUR-TOKEN' | \
  gcloud secrets versions add slack-clauded-status-token \
  --project=<PROJECT_ID> --data-file=-
```

(`terraform output set_secret_command` prints the exact command for you.)

## 4. Smoke test

```bash
gcloud scheduler jobs run slack-clauded-status-rotator \
  --location=europe-west9 --project=<PROJECT_ID>
```

Check your Slack status. Logs:

```bash
gcloud functions logs read slack-clauded-status \
  --region=europe-west9 --project=<PROJECT_ID> --gen2 --limit=20
```

## Tweaks

| What                         | Where                              |
|------------------------------|------------------------------------|
| Schedule cadence             | `var.schedule` in `terraform.tfvars` |
| Emoji shown with the word    | `var.status_emoji`                 |
| Word list                    | `function/words.go`                |
| Time zone                    | `var.schedule_time_zone`           |

After editing Go code, re-run `go mod tidy` then `terraform apply` — the source
hash changes, the function redeploys automatically.

## Tear down

```bash
cd terraform && terraform destroy
```

(The Slack app itself you delete from <https://api.slack.com/apps>.)
