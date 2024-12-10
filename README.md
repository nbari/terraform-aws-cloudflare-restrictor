# terraform-aws-cloudflare-restrictor

Automatically restrict security groups with designated tags to CloudFlare's known public IPs

Based on the original work by [rhythmictech](https://github.com/rhythmictech/terraform-aws-cloudflare-restrictor)

Changes:
- Python 3.11


This module will automatically manage the ingress rules for any security groups
that are appropriately tagged, only permitting CloudFlare IP addresses. The
module will create a Lambda that runs once per day, using the public CloudFlare
API for known IP addresses to pull the latest IPs and merge them into the
security group.

By default, the Lambda will update any security group with the tag key
`CLOUDFLARE_MANAGED` set to `true`, though this can be customized. Any existing
ingress rules will be removed when this tag key/value match. Since the Lambda
only runs once per day, it is recommended that it be manually triggered
whenever a new security group is added.

## Example
Here's what using the module will look like:

```hcl
resource "aws_security_group" "cloudflare" {
  vpc_id      = aws_vpc.main.id
  name        = "cloudflare"
  description = "Only port 443"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name               = "cloudflare"
    CLOUDFLARE_MANAGED = "true"
  }
}

output "sg_cloudflare" {
  value = aws_security_group.cloudflare.id
}

module "cloudflare-restrictor" {
  source        = "nbari/cloudflare-restrictor/aws"
  version       = "0.1.0"
  allowed_ports = [443]
}
```

if need port 80 and 443 you can use:

```hcl
allowed_ports = [80, 443]
```


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allowed\_ports | Ports to allow traffic from CloudFlare on (recommended to only use 443) | `list(number)` | <pre>[<br>  443<br>]</pre> | no |
| execution\_expression | cron expression for how frequently rules should be updated | `string` | `"rate(1 day)"` | no |
| name | Moniker to apply to all resources in the module | `string` | `"cloudflare-restrictor"` | no |
| tag\_key | Tag key to expect on security groups that will be managed by this module | `string` | `"CLOUDFLARE_MANAGED"` | no |
| tag\_value | Tag value to expect on security groups that will be managed by this module | `string` | `"true"` | no |

## Outputs

No output.
