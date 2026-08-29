variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "log_group_arns" {
  description = "CloudWatch Log Group ARNs the app instances must write to"
  type        = list(string)
}

variable "github_account" {
  description = "GitHub org/user that owns the repo, for the OIDC trust condition"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name, for the OIDC trust condition"
  type        = string
}

