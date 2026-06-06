output "function_uri" {
  description = "Direct invocation URL of the rotator function."
  value       = google_cloudfunctions2_function.rotator.service_config[0].uri
}

output "secret_name" {
  description = "Secret Manager secret ID to populate with your xoxp- token."
  value       = google_secret_manager_secret.slack_token.secret_id
}

output "set_secret_command" {
  description = "Copy-paste this (with your token) to load the secret after first apply."
  value       = "printf 'xoxp-YOUR-TOKEN' | gcloud secrets versions add ${google_secret_manager_secret.slack_token.secret_id} --project=${var.project_id} --data-file=-"
}

output "manual_invoke_command" {
  description = "Trigger the function manually with the scheduler's identity (for smoke testing)."
  value       = "gcloud scheduler jobs run ${google_cloud_scheduler_job.rotator.name} --location=${var.region} --project=${var.project_id}"
}
