# Define Variables
[string]$WORKSPACE = "$env:WORKSPACE"
[string]$BUILD_NUMBER = 600 + "$env:BUILD_NUMBER"
[string]$ENV_FILE = "C:\Temp\.env"
[string]$SSH_KEY = "C:\Users\QAVM\Documents\git-hub\id_rsa"
[string]$SOURCE_SERVER = "ubuntu@100.110.120.71:/nanolock/deployment-scripts/.env"

# Define Deployment Targets
$deployments = @{
    FROM_DEV30_QA30  = @{ target = "ubuntu@100.110.120.83:/nanolock/deployment-scripts"; replace = @("dev-30", "qa") }
    FROM_DEV30_DEV40 = @{ target = "ubuntu@100.110.120.79:/nanolock/deployment-scripts"; replace = @("dev-30", "dev-40") }
    FROM_DEV30_DEV21 = @{ target = "ubuntu@100.110.120.73:/nanolock/deployment-scripts"; replace = @("dev-30", "dev-21") }
    FROM_DEV30_DEMO  = @{ target = "ubuntu@34.141.6.169:/nanolock/deployment-scripts"; replace = @("dev-30", "mot30-demo") }
}

# Function to Deploy
function Deploy-Environment {
    param (
        [string]$EnvFlag,
        [hashtable]$DeployData
    )

    if ( [bool] (Get-Variable -Name $EnvFlag -ValueOnly -ErrorAction SilentlyContinue) ) {
        Write-Host "Starting deployment for $EnvFlag..."

        # Fetch the .env file
        & scp -i $SSH_KEY -r $SOURCE_SERVER C:\Temp

        # Update the .env file
        $content = Get-Content -Path $ENV_FILE
        $newContent = $content -replace $DeployData.replace[0], $DeployData.replace[1]
        $newContent | Set-Content -Path $ENV_FILE

        # Upload the modified .env file
        & scp -i $SSH_KEY -r $ENV_FILE $DeployData.target

        Write-Host "Deployment to $EnvFlag completed."
    }
    else {
        Write-Host "$EnvFlag [status - False] flag is not set. Skipping deployment."
    }
}

# Iterate Over Deployment Targets
foreach ($envFlag in $deployments.Keys) {
    Deploy-Environment -EnvFlag $envFlag -DeployData $deployments[$envFlag]
}

# Stop SSH Service
try {
    Write-Host "Stopping SSH service..."
    Stop-Process -Name ssh -ErrorAction Stop
}
catch {
    Write-Host "Error stopping SSH service: $_"
    exit 0
}

# Final Deployment Cleanup if FROM_DEV30_QA30 is true
if ($FROM_DEV30_QA30 -eq $true) {
    Write-Host "Performing final cleanup for FROM_DEV30_QA30..."
    sudo docker image prune -a --force
    sudo docker system prune --force
    Write-Host "-------- Deploying to FROM_DEV30_QA30 environment --------"
    cd /nanolock/deployment-scripts
    sudo docker-compose up -d
}
