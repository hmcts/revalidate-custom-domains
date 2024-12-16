# revalidate-custom-domains

## Overview

The `revalidate-custom-domains` repository contains a script designed to automate the process of checking and revalidating custom domains for static web apps in Azure. This script iterates through specified Azure subscriptions and resource groups, identifies static web apps, and performs necessary actions based on the status of custom domains.

## Features

- **Subscription and Resource Group Management**: Iterates through multiple Azure subscriptions and resource groups.
- **Static Web App Processing**: Identifies and processes static web apps within the specified resource groups.
- **Custom Domain Validation**: Checks the status of custom domains and performs actions based on their status.
- **Pipeline Execution**: Determines and runs the appropriate pipeline based on the `builtFrom` tag of each static web app.

## Prerequisites

- Azure CLI installed and configured.
- Appropriate permissions to access and manage Azure subscriptions, resource groups, and static web apps.
- Personal Access Token (PAT) for Azure DevOps or GitHub if pipeline execution is required.

## Default run hours

Runs at midnight (00:00) every Sunday

## Usage

### Setting Up

**Clone the Repository**:
   `git clone https://github.com/yourusername/revalidate-custom-domains.git`

**Running the Script Locally**:

Set Your Personal Access Token: `export AZURE_DEVOPS_PAT="your_pat_here"`

Make the Script Executable: `chmod +x delete_invalid_custom_domains.sh`

Execute the Script: `./delete_invalid_custom_domains.sh`
   
