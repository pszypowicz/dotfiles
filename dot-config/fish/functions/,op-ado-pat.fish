function ,op-ado-pat --description "Get Azure DevOps PAT token from 1Password CLI" --description "This function retrieves an Azure DevOps PAT token from 1Password CLI and optionally exports it to environment variables." --description "Usage: ,op-ado-pat --secret <secret_name> [--export-env]"
    argparse 's/secret=' export-env -- $argv

    # Default to "ADO PAT" if no secret name is provided
    if not set -ql _flag_secret[1]
        set _flag_secret "ADO PAT"
    end

    set item (op item get "$_flag_secret[1]" --format json)
    if test $status -ne 0
        echo "Error: Unable to read secret '$_flag_secret[1]' from 1Password."
        return 2
    end

    set ADO_ORG (echo $item | jq -r '.fields[] | select(.label == "ADO_ORG") | .value')
    set ADO_PROJECT (echo $item | jq -r '.fields[] | select(.label == "ADO_PROJECT") | .value')
    set AZURE_DEVOPS_EXT_PAT (echo $item | jq -r '.fields[] | select(.label == "credential") | .value')

    if set -ql _flag_export_env
        set -gx ADO_ORG $ADO_ORG
        set -gx ADO_PROJECT $ADO_PROJECT
        set -gx AZURE_DEVOPS_EXT_PAT $AZURE_DEVOPS_EXT_PAT
    end
end
