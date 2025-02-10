## Commands

- Run fmt: `tofu fmt -recursive`
- List the current internal state: `tofu state list`
- Check the current configuration: `tofu plan -out=tfplan`
- Provision the current configuration: `tofu apply -var "profile=foo"`
- Provision the current configuration with auto approve: `tofu apply -var "profile=aws-personal" -auto-approve`
- Provision the current configuration with logs: ` TF_LOG=TRACE tofu apply -var "profile=foo"`
- Import state resource from AWS to local state: `tofu import aws_iam_role.ecs_instance_role ecsInstanceRole`
- Remove the local state: `tofu state list | xargs -I {} tofu state rm {}`