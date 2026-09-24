# terraform-aws-backup-plan

Terraform module for an AWS Backup plan — the schedules that write
recovery points into a vault, and the selections deciding what gets
backed up.

## Cost

Plans carry no charge of their own. Recovery points bill per
gigabyte-month in the vault they land in, and each `copy_action`
destination is a second full copy billed separately. See AWS's
[Backup pricing](https://aws.amazon.com/backup/pricing/) page for
current rates.

## Design

Pair with
[`terraform-aws-backup-vault`](https://github.com/kn47ytv9mv/terraform-aws-backup-vault),
whose `name` output goes in each rule's `target_vault_name`. They are
separate modules because one vault commonly receives from several
plans.

Selections are bundled into this module rather than split out: a
selection is meaningless without its plan, they are homogeneous, and
nothing outside references one specifically.

**A plan with rules but no selections runs on schedule and backs up
nothing.** This is the most common way a backup setup looks complete
and protects nothing — the plan exists, the schedule fires, and no
resource was ever selected. At least one rule is required and enforced
at plan time; selections are not required by AWS, so the emptiness is
silent.

`iam_role_arn` on each selection is a role from
[`terraform-aws-iam-role`](https://github.com/kn47ytv9mv/terraform-aws-iam-role)
trusting `backup.amazonaws.com` and carrying AWS's
`AWSBackupServiceRolePolicy`. Backup can only reach what that role
permits, so `resources = ["*"]` selects everything the *role* can see,
not everything in the account.

### Retention

`lifecycle.delete_after` is the retention in days. **Without it,
recovery points are kept forever and bill forever** — AWS applies no
default expiry. `cold_storage_after` moves a point to cheaper storage
first, and AWS requires `delete_after` to be at least 90 days beyond
it, which this module validates at plan time rather than letting the
apply fail.

`copy_action_destination_vault_arns` copies each recovery point into
other vaults. This is what makes a backup survive losing the region or
the account holding the original — a backup sitting only in the same
account as the thing it protects is not protection against that account
being compromised.

## Usage

```hcl
module "plan" {
  source = "kn47ytv9mv/backup-plan/aws"

  name = "production"

  rules = [
    {
      rule_name         = "daily"
      target_vault_name = module.vault.name
      schedule          = "cron(0 5 * * ? *)"
      lifecycle         = { delete_after = 35 }
    },
  ]

  selections = [
    {
      name         = "tagged"
      iam_role_arn = module.backup_role.arn
      resources    = ["*"]

      selection_tags = [
        { key = "Backup", value = "true" },
      ]
    },
  ]
}
```

Or directly from this repository, with monthly points aged into cold
storage and copied to a second region:

```hcl
module "plan" {
  source = "github.com/kn47ytv9mv/terraform-aws-backup-plan"

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
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the plan. If null, a unique name is generated. | `null` | no |
| rules | Backup rules, each a schedule writing into a vault. At least one is required. `lifecycle.delete_after` is the retention — without it, points are kept and billed forever. | `[]` | no |
| selections | What each run actually backs up. A plan with no selections backs up nothing. | `[]` | no |
| advanced_backup_settings | Per-resource-type options. The only one AWS offers is Windows VSS on EC2. | `[]` | no |
| tags | A map of tags to assign to the plan. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the plan. |
| arn | The ARN of the plan. |
| version | Version ID of the plan, which changes on every modification. |
| selection_ids | Map of selection name to its ID. |
| name | The name of the plan. |

## License

MIT — see [LICENSE.md](LICENSE.md).
