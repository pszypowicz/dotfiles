function spn-login --description "Login to Azure using a service principal" --description "This function logs in to Azure using a service principal." --description "Usage: spn-login --spn <spn_name>"
  argparse 's/spn=' 'export-env' -- $argv

  # Check if the secret name is provided
  if not set -ql _flag_spn[1]
    echo "Usage: op-spn --spn <spn_name>"
    return 1
  end

  op-spn --spn "$_flag_spn[1]" --export-env
  az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID --only-show-errors --output none
  az account set --subscription $ARM_SUBSCRIPTION_ID

  if not set -ql _flag_export_env
    set --unexport ARM_SUBSCRIPTION_ID
    set --unexport ARM_CLIENT_ID
    set --unexport ARM_TENANT_ID
    set --unexport ARM_CLIENT_SECRET
  end
end
