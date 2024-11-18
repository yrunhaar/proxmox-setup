#!/bin/bash

# Color output for readability
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Constants
BACKUP_DIR="/var/backups/postgresql"
CREDENTIALS_DIR="/var/credentials"

# Function to generate a random secure password
generate_password() {
    openssl rand -base64 16
}

# Function to install PostgreSQL in the LXC
install_postgresql() {
    local vm_id=$1
    blue "Installing PostgreSQL in LXC VM $vm_id..."

    pct exec $vm_id -- bash -c "
        apt update &&
        apt install -y postgresql postgresql-contrib &&
        systemctl enable postgresql &&
        systemctl start postgresql
    "

    green "PostgreSQL installed in LXC VM $vm_id."
}

# Function to configure PostgreSQL
configure_postgresql() {
    local vm_id=$1
    local db_name=$2
    local user_name=$3
    local password=$4
    blue "Configuring PostgreSQL in LXC VM $vm_id for database $db_name..."

    pct exec $vm_id -- bash -c "
        sudo -i -u postgres bash -c \"
        psql -c \\\"CREATE DATABASE $db_name;\\\" &&
        psql -c \\\"CREATE USER $user_name WITH PASSWORD '$password';\\\" &&
        psql -c \\\"GRANT ALL PRIVILEGES ON DATABASE $db_name TO $user_name;\\\"
        \"
    "

    green "PostgreSQL configured in LXC VM $vm_id for database $db_name."
}

# Function to enable external connections
enable_external_connections() {
    local vm_id=$1
    local network_cidr=$2
    blue "Enabling external connections for PostgreSQL in LXC VM $vm_id..."

    pct exec $vm_id -- bash -c "
        sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'\" /etc/postgresql/*/main/postgresql.conf &&
        echo \\\"host all all $network_cidr md5\\\" >> /etc/postgresql/*/main/pg_hba.conf &&
        systemctl restart postgresql
    "

    green "External connections enabled for PostgreSQL in LXC VM $vm_id."
}

# Function to install CLI tools for cloud providers
install_cloud_cli() {
    local vm_id=$1
    local cloud_provider=$2

    case $cloud_provider in
        aws)
            blue "Installing AWS CLI in VM $vm_id..."
            pct exec $vm_id -- bash -c "
                apt update &&
                apt install -y awscli
            "
            green "AWS CLI installed in VM $vm_id."
            ;;
        gcp)
            blue "Installing Google Cloud SDK in VM $vm_id..."
            pct exec $vm_id -- bash -c "
                apt update &&
                apt install -y google-cloud-sdk
            "
            green "Google Cloud SDK installed in VM $vm_id."
            ;;
        azure)
            blue "Installing Azure CLI in VM $vm_id..."
            pct exec $vm_id -- bash -c "
                apt update &&
                apt install -y curl &&
                curl -sL https://aka.ms/InstallAzureCLIDeb | bash
            "
            green "Azure CLI installed in VM $vm_id."
            ;;
        *)
            red "Unknown cloud provider: $cloud_provider. Skipping CLI installation."
            ;;
    esac
}

# Function to configure backups and authentication
configure_backups_and_auth() {
    local vm_id=$1
    local cloud_provider=$2
    local bucket_path=$3
    local credentials_file=$4

    install_cloud_cli $vm_id $cloud_provider

    blue "Configuring backups for PostgreSQL in LXC VM $vm_id..."

    pct exec $vm_id -- bash -c "
        mkdir -p $BACKUP_DIR &&
        mkdir -p $CREDENTIALS_DIR &&
        chown postgres:postgres $BACKUP_DIR &&
        echo \\\"0 2 * * * postgres pg_dumpall > $BACKUP_DIR/backup_\$(date +\\\"%Y%m%d_%H%M%S\\\").sql && \\
        $cloud_provider $bucket_path/backup_\$(date +\\\"%Y%m%d_%H%M%S\\\").sql\\\" > /etc/cron.d/postgresql_backup
    "

    blue "Copying credentials to VM $vm_id..."
    pct push $vm_id "$credentials_file" "$CREDENTIALS_DIR/$(basename "$credentials_file")"
    green "Backups and authentication configured for PostgreSQL in LXC VM $vm_id."
}

# Function to authenticate with cloud provider
configure_cloud_authentication() {
    green "Choose your cloud storage provider:"
    echo "1. Amazon S3 (AWS)"
    echo "2. Google Cloud Storage (GCS)"
    echo "3. Azure Blob Storage"
    read -p "Enter the number corresponding to your choice: " choice

    local credentials_file
    local cloud_command

    case $choice in
        1)
            echo "AWS Instructions:"
            echo "- IAM user should have S3FullAccess permissions."
            echo "- Ensure you create a bucket or use an existing one."
            echo "- Generate Access Key ID and Secret Access Key."
            read -p "Enter your AWS S3 bucket path (e.g., s3://my-bucket/path): " bucket_path
            read -p "Enter AWS Access Key ID: " aws_access_key
            read -p "Enter AWS Secret Access Key: " aws_secret_key
            credentials_file="$CREDENTIALS_DIR/aws_credentials"

            echo "[default]" > "$credentials_file"
            echo "aws_access_key_id = $aws_access_key" >> "$credentials_file"
            echo "aws_secret_access_key = $aws_secret_key" >> "$credentials_file"
            cloud_command="aws s3 cp --profile default"

            green "AWS credentials saved to $credentials_file."
            ;;
        2)
            echo "GCS Instructions:"
            echo "- Service account should have 'Storage Admin' role."
            echo "- Download the service account JSON file from the GCP Console."
            read -p "Enter your GCS bucket path (e.g., gs://my-bucket/path): " bucket_path
            read -p "Enter the path to your GCS service account key JSON file: " service_account_path
            credentials_file="$service_account_path"
            cloud_command="gsutil cp"

            green "Using GCS service account file: $credentials_file."
            ;;
        3)
            echo "Azure Instructions:"
            echo "- Storage account should have Blob Contributor role."
            echo "- Generate account name and key from the Azure portal."
            read -p "Enter your Azure blob path (e.g., az://my-container/path): " bucket_path
            read -p "Enter Azure Storage Account Name: " azure_account_name
            read -p "Enter Azure Storage Account Key: " azure_account_key
            credentials_file="$CREDENTIALS_DIR/azure_credentials"

            echo "accountName=$azure_account_name" > "$credentials_file"
            echo "accountKey=$azure_account_key" >> "$credentials_file"
            cloud_command="az storage blob upload --account-name $azure_account_name --account-key $azure_account_key"

            green "Azure credentials saved to $credentials_file."
            ;;
        *)
            red "Invalid choice. Exiting..."
            exit 1
            ;;
    esac

    echo "$cloud_command $bucket_path $credentials_file"
}

# Main script
main() {
    # Prompt user for input
    read -p "Enter Production Environment VM ID (default: 400): " VM_PROD_ID
    VM_PROD_ID=${VM_PROD_ID:-400}
    read -p "Enter Test Environment VM ID (default: 401): " VM_TEST_ID
    VM_TEST_ID=${VM_TEST_ID:-401}

    # Configure cloud authentication
    cloud_config=$(configure_cloud_authentication)
    IFS=' ' read -r cloud_provider bucket_path credentials_file <<< "$cloud_config"

    # Configure backups and authentication
    blue "Configuring backups for Test Environment..."
    configure_backups_and_auth $VM_TEST_ID "$cloud_provider" "$bucket_path" "$credentials_file"

    blue "Configuring backups for Production Environment..."
    configure_backups_and_auth $VM_PROD_ID "$cloud_provider" "$bucket_path" "$credentials_file"

    green "PostgreSQL Test and Production Environments are set up successfully with cloud backup and authentication!"
}

# Run the main script
main