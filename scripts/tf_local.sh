#!/bin/bash
set -Eeuo pipefail
shopt -s inherit_errexit

# init and defaults
# project base name for use-case projects can be derived from the git repo root usually, e.g. axach-cicd-projects
project_base_name=the-co2-shifter
script_name=$(basename "$0")
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
terraform_dir="${scripts_dir}/../terraform"
cleanup="false"
tf_refresh="true"
tf_init="true"
tf_action="plan"
tf_actions=(plan apply import)

echo "Run $script_name..."

usage() {
  echo ""
  echo "Local Terraform plan/apply for use-case projects."
  echo ""
  echo "  Usage: ./$script_name [-c] [-i <true|false>] [-r <true|false>] [-a <plan|apply|import>] [-s <dev|ppd|prd|exp>] [-h]"
  echo ""
  echo "  Options:"
  echo "    -c : Clean-up .terraform folder + .terraform.lock.hcl file"
  echo "    -i : Set Terraform init to true or false (note: init happens in plan phase only); default=true"
  echo "    -r : Set Terraform refresh to true or false; default=true"
  echo "    -a : Specify the Terraform action, must be one of [ ${tf_actions[*]} ]; default=plan"
  echo "         Apply expects the plan 'myplan'. Import needs customization of the import statement in code below."
  echo "    -h : Print help"
  echo ""
  echo "  Example: ./$script_name -c -a plan -s ppd -i false -r false"
  echo ""
}

# see https://stackoverflow.com/a/14367368
array_contains() {
  local array="$1[@]"
  local seeking="$2"
  local in=1
  for element in "${!array}"; do
    if [[ $element == "$seeking" ]]; then
      in=0
      break
    fi
  done
  return $in
}

# read opts
while getopts ":ci:r:a:h" opt; do
  case ${opt} in
  c) # clean-up
    cleanup="true"
    ;;
  i) # tf init
    if [ "$OPTARG" != "true" ] && [ "$OPTARG" != "false" ]; then
      echo "INVALID ARGUMENT '$OPTARG' for -$opt" >&2 && usage >&2 && exit 1
    fi
    tf_init="$OPTARG"
    ;;
  r) # tf refresh
    if [ "$OPTARG" != "true" ] && [ "$OPTARG" != "false" ]; then
      echo "INVALID ARGUMENT '$OPTARG' for -$opt" >&2 && usage >&2 && exit 1
    fi
    tf_refresh="$OPTARG"
    ;;
  a) # tf action
    if [ "$(array_contains tf_actions "$OPTARG" || echo -n "no")" = "no" ]; then
      echo "INVALID ARGUMENT '$OPTARG' for -$opt" >&2 && usage >&2 && exit 1
    fi
    tf_action="$OPTARG"
    ;;
  h) # help
    usage && exit 0
    ;;
  :) # missing argument
    echo "INVALID USAGE: Option -$OPTARG requires an argument" >&2 && usage >&2 && exit 1
    ;;
  \?) # unsupported option
    echo "INVALID USAGE: Unknown option -$OPTARG" >&2 && usage >&2 && exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

access_token=$(gcloud auth print-access-token)
export GOOGLE_OAUTH_ACCESS_TOKEN="$access_token"
export TF_VAR_sa_secret_id="$GOOGLE_OAUTH_ACCESS_TOKEN"
export TF_LOG="INFO"
export TF_LOG_PATH="terraform.log"

cd "${terraform_dir}" || (echo "Error: Could not cd into ${terraform_dir}. Does it exist?" && exit 1)

# project id might depends on user input
project_id="${project_base_name}"

# tf vars and configs
tf_var_workspace=$(dirname "$(pwd)")
tf_var_project_base="$project_base_name"
tf_var_project_id="$project_id"
tf_backend_config_bucket="${project_id}-tfstate"

echo "--------------------------------------------------------------------------------"
echo "Project details:"
echo "  project_base_name=$project_base_name"
echo "  project_id=$project_id"
echo ""
echo "TF vars:"
echo "  var.project_id=$tf_var_project_id"
echo "  var.project_name=$tf_var_project_base"
echo "  var.workspace=$tf_var_workspace"
echo ""
echo "TF configs:"
echo "  TF_LOG=$TF_LOG"
echo "  TF_LOG_PATH=$TF_LOG_PATH"
echo "  tf_backend_config_bucket=$tf_backend_config_bucket"
echo "  TF_VAR_sa_secret_id=$([ -z "$TF_VAR_sa_secret_id" ] || echo "*****")"
echo "--------------------------------------------------------------------------------"

if [ -v cleanup ] && [ "$cleanup" = "true" ]; then
  echo "Cleanup existing .terraform folder and the .terraform.lock.hcl file"
  rm -rf ".terraform" && rm -f ".terraform.lock.hcl"
fi

if [ "$tf_action" = "plan" ]; then
  if [ "$tf_init" = "true" ]; then
    echo "Terraform init"
    terraform init -backend-config="bucket=$tf_backend_config_bucket"
  fi
  echo "Terraform plan"
  terraform plan -out myplan -refresh="$tf_refresh" -var project_id="$tf_var_project_id" \
    -var project_name="$tf_var_project_base" -var workspace="$tf_var_workspace" \

# targets
#    -target module.cloudfunctions.google_storage_bucket_object.cf_zip[\"cf_api_bridge\"] \
#    -target module.cloudfunctions.google_cloudfunctions_function.cf_deploy_http[\"cf_api_bridge\"] \

elif [ "$tf_action" = "apply" ]; then
  echo "Terraform apply"
  terraform apply myplan
elif [ "$tf_action" = "import" ]; then
  echo "Terraform import"
  echo "CUSTOMIZATION required!"
#  terraform import -var project_id="$tf_var_project_id" -var project_name="$tf_var_project_base" \
#    -var workspace="$tf_var_workspace" \
#    module.cloudfunctions.google_cloudfunctions_function.cf_deploy_http[\"cf_github_repo\"] axach-cicd-projects-prd/europe-west6/cf_github_repo
else # does actually never happen, default is plan
  echo "ERROR: Unsupported action '$tf_action'." >&2 && exit 1
fi

echo ""
echo "Cleanup env vars"
unset GOOGLE_OAUTH_ACCESS_TOKEN
unset TF_VAR_sa_secret_id
unset TF_LOG
unset TF_LOG_PATH
echo ""
echo "$script_name completed."
