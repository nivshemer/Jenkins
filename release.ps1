# Define function to update .env file
function Update-EnvFile {
    param (
        [string]$envFilePath,
        [string]$buildNumber,
        [string]$replaceString
    )
    
    (Get-Content $envFilePath) -replace '\$BUILD_NUMBER', $buildNumber | Set-Content $envFilePath -Verbose
    (Get-Content $envFilePath) | ForEach-Object { $_ -replace $replaceString, "envvar" -replace 3.5, $buildNumber } | Out-File $envFilePath -Verbose
}

# Define function to SCP .env file from remote server
function Copy-EnvFileFromServer {
    param (
        [string]$remoteServer,
        [string]$remoteFilePath,
        [string]$localFilePath,
        [string]$privateKeyPath
    )
    
    & scp -i $privateKeyPath -r "ubuntu@$remoteServer:$remoteFilePath" $localFilePath
}

# Main script starts here
[string]$WORKSPACE = "$env:WORKSPACE"
[string]$BUILD_NUMBER = 650 + "$env:BUILD_NUMBER"
[string]$ENV_FILE = "$WORKSPACE\DeploymentScripts\docker\deployment-scripts\.env"
[string]$privateKeyPath = "C:\Users\QAVM\Documents\git-hub\id_rsa"

# Check build flags and perform actions accordingly
if ($BUILD_FROM_OTD21 -eq $true) {
    Write-Host "Processing for OTD21"
    Copy-EnvFileFromServer "100.110.120.73" "/nanolock/deployment-scripts/.env" $ENV_FILE $privateKeyPath
    Update-EnvFile $ENV_FILE $BUILD_NUMBER 'dev-21'
} else {
    Write-Host "BUILD_FROM_OTD21 [status - $BUILD_FROM_OTD21] flag is false"
}

if ($BUILD_FROM_OTD30 -eq $true) {
    Write-Host "Processing for OTD30"
    Copy-EnvFileFromServer "100.110.120.71" "/nanolock/deployment-scripts/.env" $ENV_FILE $privateKeyPath
    Update-EnvFile $ENV_FILE $BUILD_NUMBER 'dev-30'
} else {
    Write-Host "BUILD_FROM_OTD30 [status - $BUILD_FROM_OTD30] flag is false"
}

if ($BUILD_FROM_OTD40 -eq $true) {
    Write-Host "Processing for OTD40"
    Copy-EnvFileFromServer "100.110.120.79" "/nanolock/deployment-scripts/.env" $ENV_FILE $privateKeyPath
    Update-EnvFile $ENV_FILE $BUILD_NUMBER 'dev-40'
} else {
    Write-Host "BUILD_FROM_OTD40 [status - $BUILD_FROM_OTD40] flag is false"
}

if ($BUILD_FROM_QA_OTD30 -eq $true) {
    Write-Host "Processing for QA_OTD30"
    Copy-EnvFileFromServer "100.110.120.83" "/nanolock/deployment-scripts/.env" $ENV_FILE $privateKeyPath
    Update-EnvFile $ENV_FILE $BUILD_NUMBER 'qa'
} else {
    Write-Host "BUILD_FROM_QA_OTD30 [status - $BUILD_FROM_QA_OTD30] flag is false"
}

if ($BUILD_FROM_PROD_30 -eq $true) {
    Write-Host "Processing for PROD_30"
    Copy-EnvFileFromServer "100.110.120.82" "/nanolock/deployment-scripts/.env" $ENV_FILE $privateKeyPath
    Update-EnvFile $ENV_FILE $BUILD_NUMBER 'qa-21'
} else {
    Write-Host "BUILD_FROM_PROD_30 [status - $BUILD_FROM_PROD_30] flag is false"
}



# Set environment variables and paths
[string]$WORKSPACE = "$env:WORKSPACE"
[string]$BRANCH_NAME = "$env:BRANCH_NAME"
[string]$BUILD_NUMBER = "$env:BUILD_NUMBER"
[string]$BUILD_NUMBER_REL = 650 + "$env:BUILD_NUMBER"
[string]$MAJOR = 3
[string]$MINOR = 1
[string]$Release = "MoT_$($BRANCH_NAME)_$($BUILD_NUMBER_REL).zip"
[string]$ReleasePack = "OTDefender_$MAJOR.$MINOR.$BUILD_NUMBER_REL.zip"
[string]$ReleasePackMoT = "MachineDefender_$MAJOR.$MINOR.$BUILD_NUMBER_REL.zip"
[string]$ENV_FILE = "$WORKSPACE\DeploymentScripts\docker\deployment-scripts\.env"
[string]$PUBLISH_TO_CLOUD = "$env:PUBLISH_TO_CLOUD"
[string]$BUILD_FROM_OTD21 = "$env:BUILD_FROM_OTD21"
[string]$BUILD_FROM_OTD30 = "$env:BUILD_FROM_OTD30"
[string]$BUILD_FROM_OTD40 = "$env:BUILD_FROM_OTD40"
[string]$BUILD_FROM_QA_OTD30 = "$env:BUILD_FROM_QA_OTD30"
[string]$BUILD_FROM_PROD_30 = "$env:BUILD_FROM_PROD_30"

Write-Host "Debug: $WORKSPACE, $PRODUCT_MNGT, $BRANCH_NAME, $BUILD_NUMBER, $Release"
Write-Host "Debug: Set-location $WORKSPACE"
Set-location $WORKSPACE

# Function to copy items from source to destination
function CopyMultipleItems {
    param (
        [string[]]$binaries,
        [string]$Destination
    )

    Write-Host "Debug: Starting copy process from $binaries to $Destination"
    if (Test-Path -Path $binaries) {
        if (!(Test-Path -Path $Destination)) {
            New-Item -ItemType directory -Path $Destination
        }
        $binaries | ForEach-Object { 
            copy-item -path $_ -Destination $Destination -Container -Force -Recurse
            Write-Output "Copying $_ to $Destination" 
        }
    } else {
        Write-Host "Debug: Source - $binaries doesn't exist"
    }
}

# Function to stop processes gracefully or forcefully
function Stop-Processes {
    param (
        [parameter(Mandatory=$true)] $processName,
        $timeout = 5
    )
    [System.Diagnostics.Process[]]$processList = Get-Process $processName -ErrorAction SilentlyContinue

    ForEach ($Process in $processList) {
        $Process.CloseMainWindow() | Out-Null
    }

    for ($i = 0; $i -le $timeout; $i++) {
        $AllHaveExited = $True
        $processList | ForEach-Object {
            If (-NOT $_.HasExited) {
                $AllHaveExited = $False
            }                    
        }
        If ($AllHaveExited -eq $true) {
            Return
        }
        Start-Sleep 1
    }

    $processList | ForEach-Object {
        If (Get-Process -ID $_.ID -ErrorAction SilentlyContinue) {
            Stop-Process -Id $_.ID -Force -Verbose
        }
    }
}

# Function to handle SSH and SCP operations
function CopyFilesFromRemote {
    param (
        [string]$serverIP,
        [string]$sourcePath,
        [string]$destinationPath
    )

    Write-Host "Copying files from $serverIP"
    & ssh -i "C:\Users\QAVM\Documents\git-hub\id_rsa" ubuntu@$serverIP '/home/ubuntu/save-docker-as-tar.sh'
    & scp -i "C:\Users\QAVM\Documents\git-hub\id_rsa" -r ubuntu@$serverIP:$sourcePath $destinationPath
}

# Create necessary directory if it doesn't exist
$dropDirectory = "C:\DROP\OTDefender\OTDefender_$MAJOR.$MINOR.$BUILD_NUMBER_REL\1-Mot-app\images-otd"
if (-not (Test-Path -Path $dropDirectory)) {
    New-Item -Path $dropDirectory -ItemType Directory -Force
}

# Copy files based on flags
if ($BUILD_FROM_OTD21 -eq $true) {
    Write-Host "Copying files BUILD_FROM_OTD21 $BUILD_FROM_OTD21 to IL drop"
    CopyFilesFromRemote "100.110.120.73" "/home/ubuntu/images/*" $dropDirectory
} else {
    Write-Host "BUILD_FROM_OTD21 is false"
}

if ($BUILD_FROM_OTD30 -eq $true) {
    Write-Host "Copying files BUILD_FROM_OTD30 $BUILD_FROM_OTD30 to IL drop"
    CopyFilesFromRemote "100.110.120.71" "/home/ubuntu/images/*" $dropDirectory
} else {
    Write-Host "BUILD_FROM_OTD30 is false"
}

if ($BUILD_FROM_OTD40 -eq $true) {
    Write-Host "Copying files BUILD_FROM_OTD40 $BUILD_FROM_OTD40 to IL drop"
    CopyFilesFromRemote "100.110.120.79" "/home/ubuntu/images/*" $dropDirectory
} else {
    Write-Host "BUILD_FROM_OTD40 is false"
}

if ($BUILD_FROM_QA_OTD30 -eq $true) {
    Write-Host "Copying files BUILD_FROM_QA_OTD30 $BUILD_FROM_QA_OTD30 to IL drop"
    CopyFilesFromRemote "100.110.120.83" "/home/ubuntu/images/*" $dropDirectory
} else {
    Write-Host "BUILD_FROM_QA_OTD30 is false"
}

if ($BUILD_FROM_PROD_30 -eq $true) {
    Write-Host "Copying files BUILD_FROM_PROD_30 $BUILD_FROM_PROD_30 to IL drop"
    CopyFilesFromRemote "100.110.120.82" "/home/ubuntu/images/*" $dropDirectory
} else {
    Write-Host "BUILD_FROM_PROD_30 is false"
}

# Copy and compress files
CopyMultipleItems "C:\DROP\images-otd\*" "C:\DROP\OTDefender\OTDefender_$MAJOR.$MINOR.$BUILD_NUMBER_REL\1-Mot-app\images-otd"

# Create directories and compress
New-Item -ItemType directory -Path "$WORKSPACE\1-Mot-app" -Verbose
New-Item -ItemType directory -Path "$WORKSPACE\1-Mot-app\change-ip" -Verbose
New-Item -ItemType directory -Path "$WORKSPACE\2-Enforcer-EWS" -Verbose
Copy-Item "$WORKSPACE\DeploymentScripts\change-server-ip.sh" "$WORKSPACE\1-Mot-app\change-ip" -Force -Verbose

$compress = @{
    Path = "$WORKSPACE\DeploymentScripts\docker\*"
    CompressionLevel = "Fastest"
    DestinationPath = "$WORKSPACE\$Release"
}

Compress-Archive @compress

# Handle file copying for packages
$package = @{
    Path = "$WORKSPACE\1-Mot-app", "$WORKSPACE\2-Enforcer-EWS"
    CompressionLevel = "Fastest"
    DestinationPath = "$WORKSPACE\$ReleasePack"
}
Copy-Item "$WORKSPACE\*.zip" "$WORKSPACE"

# Publish to Cloud
if ($PUBLISH_TO_CLOUD -eq $true) {
    Write-Host "PUBLISH_TO_CLOUD is true"
    CopyMultipleItems "$WORKSPACE\1-Mot-app" "C:\DROP\OTDefender\OTDefender_$MAJOR.$MINOR.$BUILD_NUMBER_REL"
    CopyMultipleItems "$WORKSPACE\2-Enforcer-EWS" "C:\DROP\OTDefender\OTDefender_$MAJOR.$MINOR.$BUILD_NUMBER_REL"
    Remove-Item -Path "C:\DROP\OTDefender\OTDefender_$MAJOR.$MINOR.$BUILD_NUMBER_REL\1-Mot-app\images-otd\*" -Recurse -Force -Exclude *.tar
}
else {
    Write-Host "PUBLISH_TO_CLOUD is false"
}








try
{
  Write-Host "Stopping ssh service"	
  Stop-Processes -processName ssh
}
catch
{
  $ErrorMessage = $_.Exception.Message
  Out-Null
  exit 0	
}