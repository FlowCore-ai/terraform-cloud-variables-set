# Create a Terraform variable or update an existing one in a specific Terraform Cloud Workspace

This action checks whether a variable or a set of variables exist in the specified Terraform Cloud Workspace. In case of existence, the value and/or attributes are updated in accordance to the user input. In case of non-existance, the action will create a new variable in accordance to the key, value and attribute parameters specified by the user.

## Usage

### `workflow.yml` Example

Place in a `.yml` file such as this one in your `.github/workflows` folder. [Refer to the documentation on workflow YAML syntax here.](https://help.github.com/en/articles/workflow-syntax-for-github-actions)

```yaml
---
name: Deployment on Development Infrastructure

on:
  push:
    branches:
      - development
    paths:
      - 'src/**'
      - 'azure-ad-b2c-templates/**'
      - 'azure-ad-b2c/**'

permissions:
  contents: read
  statuses: write
jobs:
  provision_infrastructure:
    runs-on: ubuntu-latest
    name: Provision development infrastructure
    permissions:
      contents: read
    steps:
    - name: Checkout repo
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        repository: <my-org>/<my-perository>

    - name: Install terraform
      uses: hashicorp/setup-terraform@v3
      with:
        cli_config_credentials_token: ${{ secrets.TERRAFORM_ACCESS_TOKEN }}

    - name: Terraform Init
      id: init
      run: terraform init

    - name: Run Terraform Plan
      id: plan
      run: terraform plan

    - name: Apply Terraform
      id: apply
      run: terraform apply --auto-approve | tee apply_output.log
      env:
        TF_API_TOKEN: ${{ secrets.TERRAFORM_ACCESS_TOKEN }}

    - name: Extract Terraform Outputs
      run: |
        azure_ad_tenant_id=$(terraform output -raw azure_ad_tenant_id)
        azured_ad_client_id=$(terraform output azured_ad_client_id)
        azured_ad_client_secret=$(terraform output -raw azured_ad_client_secret)

        jq -n --arg azure_ad_tenant_id "$azure_ad_tenant_id" \
              --arg azured_ad_client_id "$azured_ad_client_id" \
              --arg azured_ad_client_secret "$azured_ad_client_secret" \
              '[
                {
                  "key": "azure_ad_tenant_id",
                  "value": $azure_ad_tenant_id,
                  "category": "terraform",
                  "hcl": false,
                  "sensitive": false
                },
                {
                  "key": "azured_ad_client_id",
                  "value": $azured_ad_client_id,
                  "category": "terraform",
                  "hcl": false,
                  "sensitive": false
                },
                {
                  "key": "azured_ad_client_secret",
                  "value": $azured_ad_client_secret,
                  "category": "terraform",
                  "hcl": false,
                  "sensitive": true
                }
              ]' > terraform-vars.json
        echo "JSON file 'terraform-vars.json' created successfully."
        

    - name: Set up Terraform environment variables
      uses: FlowCore-ai/tf-cloud-var-set@v1.0.0
      with:
          TERRAFORM_WORKSPACE_ID: ${{ env.TERRAFORM_WORKSPACE_ID }}
          TERRAFORM_ACCESS_TOKEN: ${{ secrets.TERRAFORM_ACCESS_TOKEN }}
          TERRAFORM_VARIABLES_FILE: './terraform-vars.json'
```

## Action inputs

The following settings must be passed as environment variables as shown in the example. Sensitive information, especially `AWS_ACCESS_KEY` and `AWS_SECRET_KEY`, should be [set as encrypted secrets](https://help.github.com/en/articles/virtual-environments-for-github-actions#creating-and-using-secrets-encrypted-variables) — otherwise, they'll be public to anyone browsing your repository's source code

| name                    | description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| `TERRAFORM_WORKSPACE_ID`| (Required) The ID of the Terraform Cloud Worspace.           |
| `TERRAFORM_ACCESS_TOKEN`| (Required) Your Terraform Cloud API Token.                   |
| `TERRAFORM_VARIABLES_FILE`   | (Required) The file where the variables, along with all the attributes have been stored. Only JSON files are accepted. |
