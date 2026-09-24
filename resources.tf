resource "random_uuid" "resource" {}

resource "aws_backup_plan" "resource" {
  name = coalesce(var.name, random_uuid.resource.id)

  dynamic "rule" {
    for_each = var.rules

    content {
      rule_name                    = rule.value.rule_name
      target_vault_name            = rule.value.target_vault_name
      schedule                     = rule.value.schedule
      schedule_expression_timezone = rule.value.schedule_expression_timezone
      start_window                 = rule.value.start_window
      completion_window            = rule.value.completion_window
      enable_continuous_backup     = rule.value.enable_continuous_backup
      recovery_point_tags          = rule.value.recovery_point_tags

      dynamic "lifecycle" {
        for_each = rule.value.lifecycle[*]

        content {
          delete_after                              = lifecycle.value.delete_after
          cold_storage_after                        = lifecycle.value.cold_storage_after
          opt_in_to_archive_for_supported_resources = lifecycle.value.opt_in_to_archive_for_supported_resources
        }
      }

      dynamic "copy_action" {
        for_each = rule.value.copy_action_destination_vault_arns

        content {
          destination_vault_arn = copy_action.value
        }
      }
    }
  }

  dynamic "advanced_backup_setting" {
    for_each = var.advanced_backup_settings

    content {
      resource_type  = advanced_backup_setting.value.resource_type
      backup_options = advanced_backup_setting.value.backup_options
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "resource" {
  for_each = { for s in var.selections : s.name => s }

  name         = each.value.name
  plan_id      = aws_backup_plan.resource.id
  iam_role_arn = each.value.iam_role_arn

  resources     = each.value.resources
  not_resources = each.value.not_resources

  dynamic "selection_tag" {
    for_each = each.value.selection_tags

    content {
      type  = selection_tag.value.type
      key   = selection_tag.value.key
      value = selection_tag.value.value
    }
  }
}

output "id" {
  description = "The ID of the plan."
  value       = aws_backup_plan.resource.id
}

output "name" {
  description = "The name of the plan."
  value       = aws_backup_plan.resource.name
}

output "arn" {
  description = "The ARN of the plan."
  value       = aws_backup_plan.resource.arn
}

output "version" {
  description = "Version ID of the plan, which changes on every modification."
  value       = aws_backup_plan.resource.version
}

output "selection_ids" {
  description = "Map of selection name to its ID, one entry per entry in selections."
  value       = { for k, s in aws_backup_selection.resource : k => s.id }
}
