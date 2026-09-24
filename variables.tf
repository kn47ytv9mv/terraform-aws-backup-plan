variable "name" {
  default     = null
  description = "Name of the plan. If null, a unique name is generated."
}

variable "rules" {
  default     = []
  description = "Backup rules, each a schedule writing recovery points into a vault. schedule is a cron or rate expression in UTC unless schedule_expression_timezone says otherwise (e.g. 'cron(0 5 * * ? *)' for daily at 05:00). lifecycle.delete_after is the retention in days — without it recovery points are kept forever and bill forever. cold_storage_after moves a point to cheaper cold storage first, and AWS requires delete_after to be at least 90 days beyond it. enable_continuous_backup turns on point-in-time restore for the resource types that support it. copy_action_destination_vault_arns copy each recovery point into other vaults, which is how a backup survives losing the region or account holding the original."
  type = list(object({
    rule_name                    = string
    target_vault_name            = string
    schedule                     = optional(string)
    schedule_expression_timezone = optional(string)
    start_window                 = optional(number)
    completion_window            = optional(number)
    enable_continuous_backup     = optional(bool)
    recovery_point_tags          = optional(map(string))
    lifecycle = optional(object({
      delete_after                              = optional(number)
      cold_storage_after                        = optional(number)
      opt_in_to_archive_for_supported_resources = optional(bool)
    }))
    copy_action_destination_vault_arns = optional(list(string), [])
  }))

  validation {
    condition     = length(var.rules) > 0
    error_message = "A backup plan requires at least one rule — AWS rejects a plan with none, and a plan with no rules would back nothing up regardless."
  }

  validation {
    condition = alltrue([
      for r in var.rules :
      r.lifecycle == null || r.lifecycle.cold_storage_after == null || r.lifecycle.delete_after == null ||
      r.lifecycle.delete_after >= r.lifecycle.cold_storage_after + 90
    ])
    error_message = "A rule's lifecycle delete_after must be at least 90 days beyond its cold_storage_after, which is AWS's own minimum time in cold storage."
  }
}

variable "selections" {
  default     = []
  description = "What each backup run actually backs up. iam_role_arn is a role Backup assumes, from terraform-aws-iam-role, trusting backup.amazonaws.com and carrying AWS's AWSBackupServiceRolePolicy. Select resources by ARN in resources (['*'] selects everything the role can reach), exclude with not_resources, and narrow further with selection_tags. A plan with no selections runs on schedule and backs up nothing."
  type = list(object({
    name          = string
    iam_role_arn  = string
    resources     = optional(list(string))
    not_resources = optional(list(string))
    selection_tags = optional(list(object({
      type  = optional(string, "STRINGEQUALS")
      key   = string
      value = string
    })), [])
  }))
}

variable "advanced_backup_settings" {
  default     = []
  description = "Per-resource-type options. The only one AWS currently offers is Windows VSS on EC2, enabling application-consistent snapshots of VSS-aware software: resource_type 'EC2' with backup_options { WindowsVSS = 'enabled' }."
  type = list(object({
    resource_type  = string
    backup_options = map(string)
  }))
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the plan."
}
