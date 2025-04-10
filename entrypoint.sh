#!/bin/sh

set -e


# Get the file path from the input
INPUT_TERRAFORM_VARIABLES="$1"

# Check if the file exists
if [ ! -f "$INPUT_TERRAFORM_VARIABLES" ]; then
  echo "Error: file $INPUT_TERRAFORM_VARIABLES does not exist."
  exit 1
fi


# Validate the JSON file format
if ! jq empty "$INPUT_TERRAFORM_VARIABLES" >/dev/null 2>&1; then
  echo "Error: JSON file $INPUT_TERRAFORM_VARIABLES is not in valid format."
  exit 1
fi

# Check if JSON contains at least one key-value pair with required attributes
if [ "$(jq length "$INPUT_TERRAFORM_VARIABLES")" -eq 0 ]; then
  echo "Error: JSON file does not contain any key-value pairs."
  exit 1
fi

# Validate that each key-value pair contains the required attributes
if ! jq -e 'all(.[]; has("key") and has("value") and has("category") and has("hcl") and has("sensitive"))' "$INPUT_TERRAFORM_VARIABLES"; then
  echo "Error: JSON file does not contain all required attributes (key, value, category, hcl, sensitive)."
  exit 1
fi

# Set up Terraform environment variables
export TERRAFORM_WORKSPACE_ID="$INPUT_TERRAFORM_WORKSPACE_ID"
export TERRAFORM_ACCESS_TOKEN="$INPUT_TERRAFORM_ACCESS_TOKEN"


# Read the key-value pairs from the JSON file
KEY_VALUE_PAIRS=$(cat "$INPUT_TERRAFORM_VARIABLES")


response=$(curl -X GET "https://app.terraform.io/api/v2/workspaces/$TERRAFORM_WORKSPACE_ID/vars" \
	-H "Authorization: Bearer $TERRAFORM_ACCESS_TOKEN" \
	-w "%{http_code}" -o terraform-workspace-response.json)

if [ "$response" -eq 200 ]; then
	echo "Request successful. Response saved to terraform-workspace-response.json."

	# Parse the JSON and iterate over the key-value pairs
	echo "Processing key-value pairs..."
	echo "$KEY_VALUE_PAIRS" | jq -c '.[]' | while read -r pair; do
		key=$(echo "$pair" | jq -r '.key')
		key_value=$(echo "$pair" | jq -r '.value')
		key_category=$(echo "$pair" | jq -r '.category')
		key_hcl=$(echo "$pair" | jq -r '.hcl')
		key_sensitive=$(echo "$pair" | jq -r '.sensitive')
		echo "Key: $key, Value: $key_value, Category: $key_category, HCL: $key_hcl, Sensitive: $key_sensitive"

		echo "Check for existence of $key variable"
		# Check if $key variable exists
		exists=$(cat terraform-workspace-response.json | jq -r --arg var "$key" '.data[] | select(.attributes.key == $var) | .attributes.key')
		if [ "$exists" = "$key" ]; then
			echo "Variable $key exists. Will update it."
			# Extract the variable ID
			variable_id=$(cat terraform-workspace-response.json | jq -r --arg var "$key" '.data[] | select(.attributes.key == $var) | .id')
			echo "The id of variable $key is: $variable_id"
			curl \
				--header "Authorization: Bearer $TERRAFORM_ACCESS_TOKEN" \
				--header "Content-Type: application/vnd.api+json" \
				--request PATCH \
				--data "$(jq -n --arg id "$variable_id" --arg value "$key_value" --arg category "$key_category" --arg hcl "$key_hcl" --arg sensitive "$key_sensitive" '{
                data: {
                  type: "vars",
                  id: $id,
                  attributes: {
                    value: $value,
                    category: $category,
                    hcl: $hcl,
                    sensitive: $sensitive
                  }
                }
              }')" \
				"https://app.terraform.io/api/v2/workspaces/$TERRAFORM_WORKSPACE_ID/vars/$variable_id"
		else
			echo "Variable $key does not exist."
			curl \
				--header "Authorization: Bearer $TERRAFORM_ACCESS_TOKEN" \
				--header "Content-Type: application/vnd.api+json" \
				--request POST \
				--data "$(jq -n --arg key "$key" --arg value "$key_value" --arg category "$key_category" --arg hcl "$key_hcl" --arg sensitive "$key_sensitive" --arg workspace_id "$TERRAFORM_WORKSPACE_ID" '{
                data: {
                  type: "vars",
                  attributes: {
                    key: $key,
                    value: $value,
                    category: $category,
                    hcl: $hcl,
                    sensitive: $sensitive
                  }
                }
              }')" \
				"https://app.terraform.io/api/v2/workspaces/$TERRAFORM_WORKSPACE_ID/vars"
		fi
	done
else
	echo "Error: Failure to retrieve variables from the workspace. Request failed with status code $response."
	exit 1
fi
