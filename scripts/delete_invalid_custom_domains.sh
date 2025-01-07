#!/bin/bash

# Define subscriptions and their resource groups
SUBSCRIPTIONS=(
    "a8140a9e-f1b0-481f-a4de-09e2ee23f7ab:sds-platform-shutter-webapp-sbox-rg"
    "b72ab7b7-723f-4b18-b6f6-03b0f2c6a1bb:cft-platform-shutter-webapp-sbox-rg"
    "5ca62022-6aa2-4cee-aaa7-e7536c8d566c:sds-platform-shutter-webapp-prod-rg"
    "8cbc6f36-7c56-4963-9d36-739db5d00b27:cft-platform-shutter-webapp-prod-rg"
    "ed302caf-ec27-4c64-a05e-85731c3ce90e:MTA-STS-Site"
)

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
         -d '{"resources": {}}' \
         "https://dev.azure.com/hmcts/PlatformOperations/_apis/pipelines/$pipeline_id/runs?api-version=6.0-preview.1"
}

DOMAIN_DELETED=false

# Iterate through subscriptions
for SUBSCRIPTION_PAIR in "${SUBSCRIPTIONS[@]}"; do
    IFS=":" read -r SUBSCRIPTION RESOURCE_GROUP <<< "$SUBSCRIPTION_PAIR"
    echo "========================================"
    echo "Setting subscription to: $SUBSCRIPTION"
    az account set --subscription $SUBSCRIPTION
    
    echo "Processing resource group: $RESOURCE_GROUP"
    
    # Get list of static web apps in resource group
    STATIC_WEB_APPS=$(az staticwebapp list --resource-group $RESOURCE_GROUP --query "[].name" -o tsv)
    
    # Iterate through static web apps
    for APP in $STATIC_WEB_APPS; do
        echo "----------------------------------------"
        echo "Processing static web app: $APP in resource group: $RESOURCE_GROUP"

        # Reset DOMAIN_DELETED for each static web app
        DOMAIN_DELETED=false
        
        # Get tags for the current static web app
        TAGS=$(az staticwebapp show --name $APP --resource-group $RESOURCE_GROUP --query "tags" -o json)
        BUILT_FROM=$(echo $TAGS | jq -r '.builtFrom')
        
        # Get list of custom domains in current static web app
        CUSTOM_DOMAINS=$(az staticwebapp hostname list --resource-group $RESOURCE_GROUP --name $APP --query "[].{name:name, status:status}" -o tsv)
        
        # Iterate through custom domains and delete if status is "Failed"
        while IFS=$'\t' read -r DOMAIN STATUS; do
            if [[ $STATUS == "Failed" ]]; then
                echo "  [FAILED] Deleting custom domain: $DOMAIN"
                # Uncomment the line below to actually delete the domain
                # az staticwebapp hostname delete --resource-group $RESOURCE_GROUP --name $APP --hostname $DOMAIN
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
                    # Uncomment the line below to actually run the pipeline
                    # trigger_pipeline $PIPELINE_ID
                fi
            done
        fi
    done
done

if [ "$DOMAIN_DELETED" = false ]; then
    echo "No failed custom domains were deleted."
fi

echo "========================================"
echo "Custom domain deletion process completed for all static web apps in all resource groups."
