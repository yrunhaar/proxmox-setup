#!/bin/bash

# Color output for readability
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Constants
BACKUP_DIR="/var/backups/postgresql"
CREDENTIALS_DIR="/var/credentials"

# Globals for cloud
CLOUD_PROVIDER=""
CLOUD_COMMAND=""
BUCKET_PATH=""
CREDENTIALS_FILE=""

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
    " || { red "Failed to install PostgreSQL on VM $vm_id"; exit 1; }

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
        su - postgres -c \"psql -c \\\"CREATE USER $user_name WITH PASSWORD '$password';\\\"\" &&
        su - postgres -c \"psql -c \\\"CREATE DATABASE $db_name OWNER $user_name;\\\"\" &&
        su - postgres -c \"psql -c \\\"GRANT ALL PRIVILEGES ON DATABASE $db_name TO $user_name;\\\"\"
    " || { red "Failed to configure PostgreSQL on VM $vm_id"; exit 1; }

    green "PostgreSQL configured in LXC VM $vm_id for database $db_name with user $user_name as owner."
}

# Function to enable external connections
enable_external_connections() {
    local vm_id=$1
    local network_cidr=$2
    blue "Enabling external connections for PostgreSQL in LXC VM $vm_id..."

    pct exec $vm_id -- bash -c "
        sed -i \"s/^#listen_addresses = 'localhost'/listen_addresses = '*'/\" /etc/postgresql/*/main/postgresql.conf &&
        echo \"host all all $network_cidr md5\" >> /etc/postgresql/*/main/pg_hba.conf &&
        systemctl restart postgresql
    " || { red "Failed to enable external connections on VM $vm_id"; exit 1; }

    green "External connections enabled for PostgreSQL in LXC VM $vm_id."
}

# Function to install CLI tools for cloud providers
install_cloud_cli() {
    local vm_id=$1
    local cloud_provider=$2

    blue "Installing prerequisites in VM $vm_id..."
    pct exec $vm_id -- bash -c "
        apt update &&
        apt install -y apt-transport-https ca-certificates gnupg curl
    " || { red "Failed to install prerequisites on VM $vm_id"; exit 1; }
    green "Prerequisites installed in VM $vm_id."

    case $cloud_provider in
        aws)
            blue "Installing AWS CLI in VM $vm_id..."
            pct exec $vm_id -- bash -c "apt install -y awscli" || { red "Failed to install AWS CLI on VM $vm_id"; exit 1; }
            green "AWS CLI installed in VM $vm_id."
            ;;
        gcp)
            blue "Installing Google Cloud SDK in VM $vm_id..."
            pct exec $vm_id -- bash -c "
                if [ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]; then
                    echo \"deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main\" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
                    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
                    apt update
                fi
                apt install -y google-cloud-cli
            " || { red "Failed to install Google Cloud SDK on VM $vm_id"; exit 1; }
            green "Google Cloud SDK installed in VM $vm_id."
            ;;
        azure)
            blue "Installing Azure CLI in VM $vm_id..."
            pct exec $vm_id -- bash -c "curl -sL https://aka.ms/InstallAzureCLIDeb | bash" || { red "Failed to install Azure CLI on VM $vm_id"; exit 1; }
            green "Azure CLI installed in VM $vm_id."
            ;;
        *)
            red "Unknown cloud provider: $cloud_provider. Skipping CLI installation."
            ;;
    esac
}

# Function to configure backups and cloud integration
configure_backups_and_auth() {
    local vm_id=$1
    local db_name=$2

    install_cloud_cli $vm_id $CLOUD_PROVIDER

    blue "Configuring backups for PostgreSQL in LXC VM $vm_id with cloud integration..."

    # Ensure credentials directory exists in LXC before pushing
    pct exec $vm_id -- mkdir -p $CREDENTIALS_DIR

    blue "Pushing credential file, $CREDENTIALS_FILE :"
    pct push $vm_id "$CREDENTIALS_FILE" "$CREDENTIALS_DIR/$(basename "$CREDENTIALS_FILE")" || { red "Failed to push credentials to VM $vm_id"; exit 1; }
    green "Credential file stored in LXC VM $vm_id."

    # Backup filename contains vm_id and db_name for traceability
    local backup_file="backup_\$(date +\\\"%Y%m%d_%H%M%S\\\")_vm${vm_id}_${db_name}.sql"

    # Compose cloud upload command
    local upload_cmd=""
    case $CLOUD_PROVIDER in
        aws)
            upload_cmd="$CLOUD_COMMAND $BACKUP_DIR/$backup_file $BUCKET_PATH/"
            ;;
        gcp)
            upload_cmd="GOOGLE_APPLICATION_CREDENTIALS=$CREDENTIALS_DIR/$(basename "$CREDENTIALS_FILE") $CLOUD_COMMAND $BACKUP_DIR/$backup_file $BUCKET_PATH/"
            ;;
        azure)
            upload_cmd="$CLOUD_COMMAND --file $BACKUP_DIR/$backup_file --container-name $(basename $BUCKET_PATH) --name $backup_file"
            ;;
    esac

    pct exec $vm_id -- bash -c "
        mkdir -p $BACKUP_DIR &&
        chown postgres:postgres $BACKUP_DIR &&
        echo \"0 2 * * * postgres pg_dumpall > $BACKUP_DIR/$backup_file && $upload_cmd\" > /etc/cron.d/postgresql_backup
    " || { red "Failed to configure backups with cloud integration on VM $vm_id"; exit 1; }

    green "Backups and cloud integration configured for PostgreSQL in LXC VM $vm_id."
}

# Function to authenticate with cloud provider (sets globals)
configure_cloud_authentication() {
    read -p "Enter the number corresponding to your choice: " choice

    case $choice in
        1)
            CLOUD_PROVIDER="aws"
            blue "AWS Instructions:" >&2
            blue "- IAM user should have S3FullAccess permissions." >&2
            blue "- Ensure you create a bucket or use an existing one." >&2
            blue "- Generate Access Key ID and Secret Access Key." >&2
            read -p "Enter your AWS S3 bucket path (e.g., s3://my-bucket/path): " BUCKET_PATH
            read -p "Enter AWS Access Key ID: " aws_access_key
            read -p "Enter AWS Secret Access Key: " aws_secret_key
            CREDENTIALS_FILE="$CREDENTIALS_DIR/aws_credentials"

            echo "[default]" > "$CREDENTIALS_FILE"
            echo "aws_access_key_id = $aws_access_key" >> "$CREDENTIALS_FILE"
            echo "aws_secret_access_key = $aws_secret_key" >> "$CREDENTIALS_FILE"
            CLOUD_COMMAND="aws s3 cp --profile default"

            green "AWS credentials saved to $CREDENTIALS_FILE." >&2
            ;;
        2)
            CLOUD_PROVIDER="gcp"
            blue "GCS Instructions:" >&2
            blue "- Service account should have 'Storage Admin' role." >&2
            blue "- Download the service account JSON file from the GCP Console." >&2
            read -p "Enter your GCS bucket path (e.g., gs://my-bucket/path): " BUCKET_PATH
            read -p "Enter the path to your GCS service account key JSON file (e.g. /root/credentials.json): " CREDENTIALS_FILE
            # Expand ~ to full path
            CREDENTIALS_FILE=$(eval echo "$CREDENTIALS_FILE")
            if [ ! -f "$CREDENTIALS_FILE" ]; then
                red "Credential file $CREDENTIALS_FILE does not exist!"
                exit 1
            fi
            chmod 600 "$CREDENTIALS_FILE"
            CLOUD_COMMAND="gsutil cp"
            green "Using GCS service account file: $CREDENTIALS_FILE." >&2
            ;;
        3)
            CLOUD_PROVIDER="azure"
            blue "Azure Instructions:" >&2
            blue "- Storage account should have Blob Contributor role." >&2
            blue "- Generate account name and key from the Azure portal." >&2
            read -p "Enter your Azure blob path (e.g., az://my-container/path): " BUCKET_PATH
            read -p "Enter Azure Storage Account Name: " azure_account_name
            read -p "Enter Azure Storage Account Key: " azure_account_key
            CREDENTIALS_FILE="$CREDENTIALS_DIR/azure_credentials"

            echo "accountName=$azure_account_name" > "$CREDENTIALS_FILE"
            echo "accountKey=$azure_account_key" >> "$CREDENTIALS_FILE"
            CLOUD_COMMAND="az storage blob upload --account-name $azure_account_name --account-key $azure_account_key"
            green "Azure credentials saved to $CREDENTIALS_FILE." >&2
            ;;
        *)
            red "Invalid choice. Exiting..." >&2
            exit 1
            ;;
    esac
}

# Function to create Proxmox snapshots with a timestamp
create_snapshot() {
    local vm_id=$1
    local snapshot_name=$2
    timestamp=$(date +"%Y%m%d_%H%M%S")
    snapshot_name="${snapshot_name}_${timestamp}"

    blue "Creating snapshot $snapshot_name for LXC VM $vm_id..."
    pct snapshot $vm_id $snapshot_name
    green "Snapshot $snapshot_name created for LXC VM $vm_id."
}

# Function to save credentials to Bytebase VM
store_credentials_in_bytebase() {
    local db_name=$1
    local user_name=$2
    local password=$3

    blue "Storing database credentials in Bytebase VM ($BYTEBASE_VM_ID)..."
    pct exec $BYTEBASE_VM_ID -- bash -c "
        mkdir -p /var/bytebase &&
        echo \"Database: $db_name\" >> /var/bytebase/db_credentials.txt &&
        echo \"User: $user_name\" >> /var/bytebase/db_credentials.txt &&
        echo \"Password: $password\" >> /var/bytebase/db_credentials.txt &&
        echo \"---\" >> /var/bytebase/db_credentials.txt
    "
    green "Credentials stored successfully in Bytebase VM."
}

# Main script
main() {
    # Prompt user for input
    read -p "Enter Production Environment VM ID (default: 400): " VM_PROD_ID
    VM_PROD_ID=${VM_PROD_ID:-400}
    read -p "Enter Test Environment VM ID (default: 401): " VM_TEST_ID
    VM_TEST_ID=${VM_TEST_ID:-401}
    read -p "Enter Bytebase VM ID (default: 201): " BYTEBASE_VM_ID
    BYTEBASE_VM_ID=${BYTEBASE_VM_ID:-201}
    read -p "Enter Database Name: " DB_NAME
    read -p "Enter Database User: " DB_USER
    read -p "Enter Internal Network CIDR (default: 192.168.1.0/24): " NETWORK_CIDR
    NETWORK_CIDR=${NETWORK_CIDR:-"192.168.1.0/24"}

    # Generate passwords for the test and production databases
    TEST_PASSWORD=$(generate_password)
    PROD_PASSWORD=$(generate_password)

    # Configure cloud authentication
    blue "Configuring cloud authentication for PostgreSQL backups..."
    green "Choose your cloud storage provider:"
    green "1. Amazon S3 (AWS)"
    green "2. Google Cloud Storage"
    green "3. Azure Blob Storage"
    configure_cloud_authentication

    # Set up Test Environment
    blue "Setting up PostgreSQL Test Environment..."
    install_postgresql $VM_TEST_ID
    configure_postgresql $VM_TEST_ID "${DB_NAME}_test" "${DB_USER}_test" "$TEST_PASSWORD"
    enable_external_connections $VM_TEST_ID "$NETWORK_CIDR"
    configure_backups_and_auth $VM_TEST_ID "${DB_NAME}_test"
    create_snapshot $VM_TEST_ID "initial-setup"
    store_credentials_in_bytebase "${DB_NAME}_test" "${DB_USER}_test" "$TEST_PASSWORD"

    # Set up Production Environment
    blue "Setting up PostgreSQL Production Environment..."
    install_postgresql $VM_PROD_ID
    configure_postgresql $VM_PROD_ID $DB_NAME $DB_USER "$PROD_PASSWORD"
    enable_external_connections $VM_PROD_ID "$NETWORK_CIDR"
    configure_backups_and_auth $VM_PROD_ID "$DB_NAME"
    create_snapshot $VM_PROD_ID "initial-setup"
    store_credentials_in_bytebase $DB_NAME $DB_USER "$PROD_PASSWORD"

    green "PostgreSQL Test and Production Environments are set up successfully with cloud backup and authentication!"
}

# Run the main script
main