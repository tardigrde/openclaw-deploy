variable "environment" {
  description = "Environment name — used in the auth key description"
  type        = string
}

variable "enable_acl" {
  description = "Manage the tailnet ACL policy via Terraform. WARNING: replaces the entire ACL on apply. Set to false if you manage ACLs elsewhere."
  type        = bool
  default     = false
}
