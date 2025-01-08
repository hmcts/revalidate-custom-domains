#!/bin/bash

# Define the specific subscription and resource group for testing
SUBSCRIPTION="a8140a9e-f1b0-481f-a4de-09e2ee23f7ab"
RESOURCE_GROUP="sds-platform-shutter-webapp-sbox-rg"
APP="toffee"

# Define your Azure DevOps pipelines
PIPELINES=(
    "hmcts/azure-platform-terraform:765" # azure-platform-terraform pipeline
    "hmcts/sds-azure-platform:543" # sds-azure-platform pipeline
)

# Personal Access Token (PAT)
PAT="$AZURE_DEVOPS_PAT"

# Function to trigger a pipeline
trigger_pipeline() {
    local pipeline_id=$1
    echo "Triggering pipeline: $pipeline_id"
    curl -u :$PAT \
         -X POST \
         -H "Content-Type: application/json" \
         -d '{
                "resources": {
                    "repositories": {
                    "self": {
                        "refName": "refs/heads/master"
                    }
                    }
                },
                "variables": {
                    "DEPLOYMENT_SBOX": {
                    "value": "sbox shutter webapp environment: sbox component: shutter static webapp service connection: dcd-cftapps-sbox storage account rg: core-infra-sbox-rg storage account name: cftappssbox dependsOn: Precheck pipeline tests: false"
                    },
                    "DEPLOYMENT_PROD": {
                    "value": "prod shutter webapp environment: prod component: shutter static webapp service connection: dcd-cftapps-prod storage account rg: core-infra-prod-rg storage account name: cftappsprod dependsOn: sbox shutter webapp"
                    }
                }
            }' \
         "https://dev.azure.com/hmcts/PlatformOperations/_apis/pipelines/$pipeline_id/runs?api-version=6.0-preview.1"
}

echo "========================================"
echo "Setting subscription to: $SUBSCRIPTION"
az account set --subscription $SUBSCRIPTION

echo "----------------------------------------"
echo "Processing static web app: $APP in resource group: $RESOURCE_GROUP"

# Reset DOMAIN_DELETED for the static web app
DOMAIN_DELETED=true

# Get tags for the current static web app
TAGS=$(az staticwebapp show --name $APP --resource-group $RESOURCE_GROUP --query "tags" -o json)
BUILT_FROM=$(echo $TAGS | jq -r '.builtFrom')

# Get list of custom domains in current static web app
CUSTOM_DOMAINS=$(az staticwebapp hostname list --resource-group $RESOURCE_GROUP --name $APP --query "[].{name:name, status:status}" -o tsv)

# Iterate through custom domains and delete if status is "Failed"
while IFS=$'\t' read -r DOMAIN STATUS; do
    if [[ $STATUS == "Failed" ]]; then
        echo "  [FAILED] Deleting custom domain: $DOMAIN"
        az staticwebapp hostname delete --resource-group $RESOURCE_GROUP --name $APP --hostname $DOMAIN --yes
        DOMAIN_DELETED=true
    else
        echo "  [READY] Skipping custom domain: $DOMAIN"
    fi
done <<< "$CUSTOM_DOMAINS"

# Trigger the appropriate pipeline if any domain was deleted
if [ "$DOMAIN_DELETED" = true ]; then
    for PIPELINE_PAIR in "${PIPELINES[@]}"; do
        IFS=":" read -r PIPELINE_TAG PIPELINE_ID <<< "$PIPELINE_PAIR"
        if [ "$PIPELINE_TAG" = "$BUILT_FROM" ]; then
            echo "Triggering pipeline with ID: $PIPELINE_ID"
            trigger_pipeline $PIPELINE_ID
        fi
    done
fi

if [ "$DOMAIN_DELETED" = false ]; then
    echo "No failed custom domains were deleted."
fi

echo "========================================"
echo "Custom domain deletion process completed for the static web app: $APP."
