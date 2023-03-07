# api-ai-prototype

A prototype API for generating content from AI

## Setting up State storage

After you set `config/backend-dev.conf` and `config/dev.tfvars` properly (for each environment). You can easily run terraform as below:

```
env=dev
terraform get -update=true
terraform init -reconfigure -backend-config=config/backend-${env}.conf
terraform plan -var-file=config/${env}.tfvars
terraform apply -var-file=config/${env}.tfvars
```

If you encountered any unexpected issues, delete the cache folder, and try again.

`rm -rf .terraform`

## Lambda Integration

see (tips to deal with lambda functions)[https://github.com/johnmccuk/terraform-best-practices#tips-to-deal-with-lambda-functions] explaing how to use Lambda's properly.

See `lambda.tf.example` for an example of how to use this method to zip up Lambda code.

A base template for building Terraform projects based on (terraform best practices
)[https://github.com/johnmccuk/terraform-best-practices.git]
