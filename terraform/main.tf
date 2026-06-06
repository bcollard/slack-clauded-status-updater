locals {
  required_apis = [
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.required_apis)
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Source archive uploaded to GCS for Cloud Functions Gen 2 to build from.
# ---------------------------------------------------------------------------

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/../function"
  output_path = "${path.module}/.build/function.zip"
}

resource "google_storage_bucket" "source" {
  name                        = "${var.project_id}-${var.name_prefix}-src"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_object" "source" {
  name   = "function-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.source.output_path
}

# ---------------------------------------------------------------------------
# Secret Manager: Slack xoxp- token (populated out-of-band; see README).
# ---------------------------------------------------------------------------

resource "google_secret_manager_secret" "slack_token" {
  secret_id = "${var.name_prefix}-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Function runtime identity + secret access.
# ---------------------------------------------------------------------------

resource "google_service_account" "function_sa" {
  account_id   = "${var.name_prefix}-fn"
  display_name = "Slack status rotator function runtime"
}

resource "google_secret_manager_secret_iam_member" "fn_accessor" {
  secret_id = google_secret_manager_secret.slack_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_sa.email}"
}

# ---------------------------------------------------------------------------
# Cloud Function (Gen 2).
# ---------------------------------------------------------------------------

resource "google_cloudfunctions2_function" "rotator" {
  name        = var.name_prefix
  location    = var.region
  description = "Rotates Slack status with a Clauded-thinking-mode word."

  build_config {
    runtime     = "go122"
    entry_point = "RotateStatus"
    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "128Mi"
    timeout_seconds       = 30
    service_account_email = google_service_account.function_sa.email

    environment_variables = {
      STATUS_EMOJI = var.status_emoji
    }

    secret_environment_variables {
      key        = "SLACK_TOKEN"
      project_id = var.project_id
      secret     = google_secret_manager_secret.slack_token.secret_id
      version    = "latest"
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.fn_accessor,
  ]
}

# ---------------------------------------------------------------------------
# Scheduler identity + permission to invoke the function (Cloud Run under the hood).
# ---------------------------------------------------------------------------

resource "google_service_account" "scheduler_sa" {
  account_id   = "${var.name_prefix}-sched"
  display_name = "Slack status rotator scheduler"
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invoker" {
  location = google_cloudfunctions2_function.rotator.location
  name     = google_cloudfunctions2_function.rotator.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

# ---------------------------------------------------------------------------
# Cloud Scheduler job.
# ---------------------------------------------------------------------------

resource "google_cloud_scheduler_job" "rotator" {
  name        = "${var.name_prefix}-rotator"
  region      = var.region
  description = "Triggers Slack status rotation on a cron schedule."
  schedule    = var.schedule
  time_zone   = var.schedule_time_zone

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.rotator.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.scheduler_sa.email
      audience              = google_cloudfunctions2_function.rotator.service_config[0].uri
    }
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_service_iam_member.scheduler_invoker,
  ]
}
