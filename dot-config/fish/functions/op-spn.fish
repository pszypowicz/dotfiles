function op-spn  --description "Get a secret from 1Password CLI" --description "This function retrieves a secret from 1Password CLI and prints it to the console." --description "Usage: op-spn --spn <spn_name>"
  argparse 's/spn=' 'export-env' -- $argv

  # Check if the secret name is provided
  if not set -ql _flag_spn[1]
    echo "Usage: op-spn --spn <spn_name>"
    return 1
  end

  set item (op item get "$_flag_spn[1]" --format json)
  if test $status -ne 0
    echo "Error: Unable to read secret from 1Password."
    return 2
  end

  set ARM_SUBSCRIPTION_ID (echo $item | jq -r '.fields[] | select(.label == "subscription id") | .value')
  set ARM_CLIENT_ID (echo $item | jq -r '.fields[] | select(.label == "client id") | .value')
  set ARM_TENANT_ID (echo $item | jq -r '.fields[] | select(.label == "tenant id") | .value')
  set ARM_CLIENT_SECRET (echo $item | jq -r '.fields[] | select(.label == "password") | .value')

  if set -ql _flag_export_env
    set -gx ARM_SUBSCRIPTION_ID $ARM_SUBSCRIPTION_ID
    set -gx ARM_CLIENT_ID $ARM_CLIENT_ID
    set -gx ARM_TENANT_ID $ARM_TENANT_ID
    set -gx ARM_CLIENT_SECRET $ARM_CLIENT_SECRET
  end
end
