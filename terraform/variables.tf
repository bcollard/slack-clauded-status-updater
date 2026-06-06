variable "project_id" {
  description = "GCP project ID where the function, scheduler, and secret live."
  type        = string
}

variable "region" {
  description = "GCP region for the function and scheduler job."
  type        = string
  default     = "europe-west9"
}

variable "schedule" {
  description = "Cron schedule for the rotator. Default: every 5 minutes, 09:00-18:55, Mon-Fri."
  type        = string
  default     = "*/5 9-18 * * 1-5"
}

variable "schedule_time_zone" {
  description = "IANA time zone for the schedule."
  type        = string
  default     = "Europe/Paris"
}

variable "status_emoji" {
  description = "Slack emoji shortcode shown next to the rotating word."
  type        = string
  default     = ":brain:"
}

variable "name_prefix" {
  description = "Prefix used for resource names (function, secret, service accounts, bucket)."
  type        = string
  default     = "slack-clauded-status"
}
