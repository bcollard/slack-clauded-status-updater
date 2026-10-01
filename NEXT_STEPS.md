
  Next steps for you:
  1. Submit the Slack app for admin approval (README §1).
  2. While waiting, edit terraform/terraform.tfvars with your project_id and terraform apply — everything will deploy with an empty secret; nothing will run usefully until step 3.
  3. Once approved, load the xoxp-… token with the command from terraform output set_secret_command, then smoke-test with terraform output manual_invoke_command.
