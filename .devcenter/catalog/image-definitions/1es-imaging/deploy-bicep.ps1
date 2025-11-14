Write-Host "Testing Azure CLI installation..."
az --version

Write-Host "`nGetting VM metadata from IMDS endpoint..."

# Get VM metadata from Azure Instance Metadata Service (IMDS)
try {
    $imdsUri = "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
    $headers = @{ "Metadata" = "true" }
    
    Write-Host "Querying IMDS endpoint..." -ForegroundColor Cyan
    $metadata = Invoke-RestMethod -Uri $imdsUri -Headers $headers -TimeoutSec 10
    
    $vmName = $metadata.compute.name
    $resourceGroup = $metadata.compute.resourceGroupName
    $subscriptionId = $metadata.compute.subscriptionId
    
    Write-Host "VM Name: $vmName" -ForegroundColor Green
    Write-Host "Resource Group: $resourceGroup" -ForegroundColor Green
    Write-Host "Subscription ID: $subscriptionId" -ForegroundColor Green
}
catch {
    Write-Host "Failed to get metadata from IMDS endpoint: $_" -ForegroundColor Red
    Write-Host "This script must be run from within an Azure VM" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nAuthenticating with Azure CLI..."
az login --service-principal --username 9ef659b0-64dd-48e0-b7ae-c0be90db26d6 --password {{https://kv-canadacentral.vault.azure.net/secrets/sppassword}} --tenant 8ab2df1c-ed88-4946-a8a9-e1bbb3e4d1fd

Write-Host "`nSetting subscription context..."
az account set --subscription $subscriptionId

Write-Host "`nShowing VM details..."
az vm show --name $vmName --resource-group $resourceGroup --output table