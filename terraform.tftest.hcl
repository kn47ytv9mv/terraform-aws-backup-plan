mock_provider "aws" {}

run "cold_storage_requires_ninety_days_before_delete" {
  command = plan

  variables {
    rules = [
      {
        rule_name         = "daily"
        target_vault_name = "production"
        schedule          = "cron(0 5 * * ? *)"
        lifecycle         = { cold_storage_after = 30, delete_after = 60 }
      },
    ]
  }

  expect_failures = [var.rules]
}

run "a_plan_with_no_rules_is_rejected" {
  command = plan

  expect_failures = [var.rules]
}

run "name_defaults_to_random_uuid" {
  command = apply

  variables {
    rules = [
      {
        rule_name         = "daily"
        target_vault_name = "production"
        schedule          = "cron(0 5 * * ? *)"
      },
    ]
  }

  assert {
    condition     = aws_backup_plan.resource.name == random_uuid.resource.id
    error_message = "Leaving name unset should fall back to the generated random_uuid."
  }
}

run "no_selections_by_default" {
  command = plan

  variables {
    rules = [
      {
        rule_name         = "daily"
        target_vault_name = "production"
        schedule          = "cron(0 5 * * ? *)"
      },
    ]
  }

  assert {
    condition     = length(aws_backup_selection.resource) == 0
    error_message = "Leaving selections unset should create no selection resources, so the plan runs on schedule and backs nothing up until one is added."
  }
}

run "rules_and_selections_create_one_each" {
  command = apply

  variables {
    rules = [
      {
        rule_name         = "daily"
        target_vault_name = "production"
        schedule          = "cron(0 5 * * ? *)"
        lifecycle         = { delete_after = 35 }
      },
      {
        rule_name         = "monthly"
        target_vault_name = "production"
        schedule          = "cron(0 5 1 * ? *)"
        lifecycle         = { cold_storage_after = 30, delete_after = 365 }
      },
    ]

    selections = [
      {
        name         = "tagged"
        iam_role_arn = "arn:aws:iam::123456789012:role/backup"
        resources    = ["*"]
        selection_tags = [
          { key = "Backup", value = "true" },
        ]
      },
    ]
  }

  assert {
    condition     = length(aws_backup_plan.resource.rule) == 2
    error_message = "Each rules entry should produce one rule block."
  }

  assert {
    condition     = length(aws_backup_selection.resource) == 1
    error_message = "Each selections entry should produce one selection resource."
  }

  assert {
    condition     = one(aws_backup_selection.resource["tagged"].selection_tag).type == "STRINGEQUALS"
    error_message = "A selection tag's type should default to STRINGEQUALS rather than making every caller state it."
  }
}

run "copy_actions_create_one_block_each" {
  command = plan

  variables {
    rules = [
      {
        rule_name         = "daily"
        target_vault_name = "production"
        schedule          = "cron(0 5 * * ? *)"
        copy_action_destination_vault_arns = [
          "arn:aws:backup:eu-west-1:123456789012:backup-vault:dr",
          "arn:aws:backup:us-west-2:123456789012:backup-vault:dr",
        ]
      },
    ]
  }

  assert {
    condition     = length(one(aws_backup_plan.resource.rule).copy_action) == 2
    error_message = "Each copy destination should produce one copy_action block, so a backup can survive losing its own region."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    name = "production"

    rules = [
      {
        rule_name         = "daily"
        target_vault_name = "production"
        schedule          = "cron(0 5 * * ? *)"
        lifecycle         = { delete_after = 35 }
      },
    ]

    selections = [
      {
        name         = "tagged"
        iam_role_arn = "arn:aws:iam::123456789012:role/backup"
        resources    = ["*"]
        selection_tags = [
          { key = "Backup", value = "true" },
        ]
      },
    ]
  }
}

run "readme_cold_storage_and_copy_example" {
  command = plan

  variables {
    rules = [
      {
        rule_name         = "monthly"
        target_vault_name = "production"
        schedule          = "cron(0 5 1 * ? *)"
        lifecycle         = { cold_storage_after = 30, delete_after = 365 }

        copy_action_destination_vault_arns = [
          "arn:aws:backup:eu-west-1:123456789012:backup-vault:dr",
        ]
      },
    ]

    selections = [
      {
        name         = "databases"
        iam_role_arn = "arn:aws:iam::123456789012:role/backup"
        resources    = ["arn:aws:rds:*:*:db:*"]
      },
    ]
  }
}
