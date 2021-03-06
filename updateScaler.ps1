#################################################################################
#
#
# Bellhop Update Scaler Script
# Created by CSA's: Matthew Garrett, Nills Franssens, and Tyler Peterson 
#
#
##################################################################################

$rgName = Read-Host "Enter resource group name where Bellhop is deployed"
$logFile = "./logs/update_$(get-date -format `"yyyyMMddhhmmsstt`").log"

$funcName = $($rgName.Replace("-rg", "") + "-function-scaler")

$resourceGroup = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
$functionApp = Get-AzFunctionApp -ResourceGroupName $rgName -Name $funcName -ErrorAction SilentlyContinue

if ($resourceGroup -and $functionApp) {
    # Upload Azure Function contents via Zip-Deploy
    # Bellhop Scaler Function Upload First
    Write-Host "INFO: Creating staging folder for updated function archives..." -ForegroundColor green
    Remove-Item .\staging\ -Recurse -Force -ErrorAction Ignore
    New-Item -Name "staging" -ItemType "directory" -ErrorAction Ignore | Out-Null

    try {
        Write-Host "INFO: Zipping up scaler function content updates" -ForegroundColor Green
        Write-Verbose -Message "Zipping up scaler function..."

        $scalerFolder = ".\functions\scaler"
        $scalerZipFile = ".\staging\scaler.zip"
        $scalerExcludeDir = @(".vscode")
        $scalerExcludeFile = @("local.settings.json")
        $scalerDirs = Get-ChildItem $scalerFolder -Directory | Where-Object { $_.Name -notin $scalerExcludeDir }
        $scalerFiles = Get-ChildItem $scalerFolder -File | Where-Object { $_.Name -notin $scalerExcludeFile }
        $scalerDirs | Compress-Archive -DestinationPath $scalerZipFile -Update
        $scalerFiles | Compress-Archive -DestinationPath $scalerZipFile -Update

        Write-Host "INFO: Updating scaler function via Zip-Deploy" -ForegroundColor Green
        Write-Verbose -Message "Updating scaler function via Azure CLI Zip-Deploy"
        Publish-AzWebapp -ResourceGroupName $rgName -Name $funcName -ArchivePath $(Resolve-Path $scalerZipFile) -Force | Out-Null
    }
    catch {
        $_ | Out-File -FilePath $logFile -Append
        Write-Host "ERROR: Bellhop function update failed due to an exception, please check $logfile for details."
        exit
    }

    Write-Host "INFO: Scaler Function has been updated!" -ForegroundColor Green
}
else {
    $_ | Out-File -FilePath $logFile -Append
    Write-Host "ERROR: Cannot find Resource Group ($rgName), or Function App ($funcName)."
    Write-Host "Please check AzContext and try again."
    exit
}
