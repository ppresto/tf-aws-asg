#!/bin/bash
# Script that clones Terraform configuration from a git repository
# creates a workspace if it does not already exist, uploads the
# Terraform configuration to it, adds variables to the workspace,
# triggers a run, checks the results of Sentinel policies (if any)
# checked against the workspace, and if $override=true and there were
# no hard-mandatory violations of Sentinel policies, does an apply.
# If an apply is done, the script waits for it to finish and then
# downloads the apply log and the before and after state files.

# Make sure ATLAS_TOKEN environment variable is set
# to owners team token for organization

# Set address if using private Terraform Enterprise server.
# Set organization and workspace to create.
# You should edit these before running.
address="app.terraform.io"
organization="Patrick"
# workspace name should not have spaces
workspace="ADMIN-TFE-Workspaces"

# Set git_url
if [ ! -z $1 ]; then
  git_url=$1
  echo "Using Github repo: $git_url"
else
  git_url="https://github.com/ppresto/tfe-create-workspaces.git"
  echo "Using Github repo: $git_url"
fi

# You can change sleep duration if desired
sleep_duration=5
save_plan="false"
applied="false"

if [ -z ${OAUTH_TOKEN_ID} ]; then
  echo "ERROR:  Set your Github Env variable OAUTH_TOKEN_ID to your oauth token for github integration to work"
  exit 1
fi

if [ -z ${ATLAS_TOKEN} ]; then
  echo "ERROR:  Set your TFE Env variable ATLAS_TOKEN to connect to TFE"
  exit 1
fi

# Get first argument.
# If not "", Set to git clone URL
# and clone the git repository
# If "", then load code from config directory

# Setup GitHub, Config Dir, and Repo
  config_dir=$(echo $git_url | cut -d "/" -f 5 | cut -d "." -f 1)
  repository=$(echo $git_url | cut -d "/" -f 4,5 | cut -d "." -f 1)

# Set workspace if provided as the second argument
if [ ! -z "$2" ]; then
  workspace=$2
  echo "Using workspace provided as argument: " $workspace
else
  echo "Using default workspace name:  ${workspace}"
fi

# Make sure $workspace does not have spaces
if [[ "${workspace}" != "${workspace% *}" ]] ; then
    echo "The workspace name cannot contain spaces."
    echo "Please pick a name without spaces and run again."
    exit
fi

# build compressed tar file from configuration directory
#echo "Tarring configuration directory."
#tar -czf ${config_dir}.tar.gz -C ${config_dir} --exclude .git .

#Set name of workspace in workspace.json
sed "s/workspace_name/${workspace}/" < workspace.template.json > workspace.json
#Set githib repo for workspace
sed -i.backup "s/org\/workspace_repo/${repository/\//\\/}/g" ./workspace.json
#Set my github org oauth token
sed -i.backup "s/oauth_token_id/${OAUTH_TOKEN_ID}/g" ./workspace.json

# Check to see if the workspace already exists
echo "Checking to see if workspace exists"
check_workspace_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" "https://${address}/api/v2/organizations/${organization}/workspaces/${workspace}")

# Parse workspace_id from check_workspace_result
workspace_id=$(echo $check_workspace_result | python -c "import sys, json; print(json.load(sys.stdin)['data']['id'])")
echo "Workspace ID: " $workspace_id

# Create workspace if it does not already exist
if [ -z "$workspace_id" ]; then
  echo "Workspace did not already exist; will create it."
  workspace_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --request POST --data @workspace.json "https://${address}/api/v2/organizations/${organization}/workspaces")

  echo "Checking Workspace Result: $workspace_result"
  # Parse workspace_id from workspace_result
  workspace_id=$(echo $workspace_result | python -c "import sys, json; print(json.load(sys.stdin)['data']['id'])")
  echo "Workspace ID: " $workspace_id
else
  echo "Workspace already existed."
fi

# Check if a variables.csv file is in the configuration directory
# If so, use it. Otherwise, use the one in the current directory.
#if [ -f "${config_dir}/variables.csv" ]; then
#  echo "Found variables.csv in ${config_dir}."
#  echo "Will load variables from it."
#  variables_file=${config_dir}/variables.csv
#else
#  echo "Will load variables from ./variables.csv"
#  variables_file=variables.csv
#fi


# Add variables to workspace
#while IFS=',' read -r key value category hcl sensitive
#do
#  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/$key/" -e "s/my-value/$value/" -e "s/my-category/$category/" -e "s/my-hcl/$hcl/" -e "s/my-sensitive/$sensitive/" < variable.template.json  > variable.json
#  echo "Adding variable $key with value $value in category $category with hcl $hcl and sensitive $sensitive"
#  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
#done < ${variables_file}

# Set CONFIRM_DESTROY as a default Environment variable
sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/CONFIRM_DESTROY/" -e "s/my-value/1/" -e "s/my-category/env/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
echo "Adding CONFIRM_DESTROY"
upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")


if [ ! -z ${OAUTH_TOKEN_ID} ]; then
  # OAUTH_TOKEN_ID
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/oauth_token_id/" -e "s/my-value/${OAUTH_TOKEN_ID}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding OAUTH_TOKEN_ID"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
fi

if [ ! -z ${ATLAS_TOKEN} ]; then
  # ATLAS_TOKEN
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/tfe_token/" -e "s/my-value/${ATLAS_TOKEN}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding ATLAS_TOKEN"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
fi

if [ ! -z ${organization} ]; then
  # organization
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/organization/" -e "s/my-value/${organization}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding organization"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
fi

if [ ! -z ${repository} ]; then
  # repository
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/repo_org/" -e "s/my-value/${repository%/*}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding Github org ${repository%/*}"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
fi

# Build Azure Credentials
# example template replacement
# sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/$key/" -e "s/my-value/$value/" -e "s/my-category/$category/" -e "s/my-hcl/$hcl/" -e "s/my-sensitive/$sensitive/" < variable.template.json  > variable.json

if [[ ! -z ${ARM_CLIENT_ID} && ! -z ${ARM_SUBSCRIPTION_ID} && ! -z ${ARM_CLIENT_SECRET} && ! -z ${ARM_TENANT_ID} ]]; then
  # ARM_CLIENT_ID
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/arm_client_id/" -e "s/my-value/${ARM_CLIENT_ID}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding ARM_CLIENT_ID"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

  # ARM_SUBSCRIPTION_ID
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/arm_subscription_id/" -e "s/my-value/${ARM_SUBSCRIPTION_ID}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding ARM_SUBSCRIPTION_ID"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

  # ARM_CLIENT_SECRET
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/arm_client_secret/" -e "s/my-value/${ARM_CLIENT_SECRET}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding ARM_CLIENT_SECRET"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

  # ARM_TENANT_ID
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/arm_tenant_id/" -e "s/my-value/${ARM_TENANT_ID}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding ARM_TENANT_ID"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

fi

# Build GCP Project Credentials
if [[ ! -z ${GOOGLE_CREDENTIALS} && ! -z ${GOOGLE_PROJECT} ]]; then
  # GOOGLE_CREDENTIALS
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/gcp_credentials/" -e "s/my-value/placeholder/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo -e "ACTION REQUIRED!! \nGOOGLE_CREDENTIAL Can't be added with this script. \nPlease update the placeholder in your workspace manually with the following \n\n"
  echo ${GOOGLE_CREDENTIALS} | tr -d '\n'
  echo ""
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

  # GOOGLE_PROJECT
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/gcp_project/" -e "s/my-value/${GOOGLE_PROJECT}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding GOOGLE_PROJECT"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
fi
# Set Default Region for GCP if Available
if [[ ! -z ${GOOGLE_REGION} && ! -z ${GOOGLE_ZONE} ]]; then
  # GOOGLE_REGION
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/gcp_region/" -e "s/my-value/${GOOGLE_REGION}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding GOOGLE_REGION"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

  # GOOGLE_ZONE
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/gcp_zone/" -e "s/my-value/${GOOGLE_ZONE}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding GOOGLE_ZONE"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
fi

# Build AWS Credentials
if [[ ! -z ${AWS_ACCESS_KEY} && ! -z ${AWS_SECRET_ACCESS_KEY} ]]; then
  # AWS_ACCESS_KEY
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/aws_access_key_id/" -e "s/my-value/${AWS_ACCESS_KEY}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding AWS_ACCESS_KEY"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

  # AWS_SECRET_ACCESS_KEY
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/aws_secret_access_key/" -e "s/my-value/${AWS_SECRET_ACCESS_KEY}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding AWS_SECRET_ACCESS_KEY"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")

fi

# Set Default AWS Region if Available
if [[ ! -z ${AWS_DEFAULT_REGION} ]]; then
  # AWS_DEFAULT_REGION
  sed -e "s/my-organization/$organization/" -e "s/my-workspace/${workspace}/" -e "s/my-key/aws_default_region/" -e "s/my-value/${AWS_DEFAULT_REGION}/" -e "s/my-category/terraform/" -e "s/my-hcl/false/" -e "s/my-sensitive/false/" < variable.template.json  > variable.json
  echo "Adding AWS_DEFAULT_REGION"
  upload_variable_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" --data @variable.json "https://${address}/api/v2/vars?filter%5Borganization%5D%5Bname%5D=${organization}&filter%5Bworkspace%5D%5Bname%5D=${workspace}")
fi

# List Sentinel Policies
sentinel_list_result=$(curl -s --header "Authorization: Bearer $ATLAS_TOKEN" --header "Content-Type: application/vnd.api+json" "https://${address}/api/v2/organizations/${organization}/policies")
sentinel_policy_count=$(echo $sentinel_list_result | python -c "import sys, json; print(json.load(sys.stdin)['meta']['pagination']['total-count'])")
echo "Number of Sentinel policies: " $sentinel_policy_count


#DEBUG=true
# cleanup
if [[ ! ${DEBUG} ]]; then
  #find ./ -type d -maxdepth 1 -exec rm -rf {} \;
  #find ./ -name "*.tar.gz" -exec rm -rf {} \;
  find ./ -name "*.json.backup" -exec rm -rf {} \;
  rm variable.json workspace.json
fi

echo "Finished"
