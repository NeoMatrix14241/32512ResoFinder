param (
    [string]$sourceFolder,
    [string]$destinationFolder,
    [int]$maxWidth = 32512,
    [int]$maxHeight = 32512,
    [int]$maxConcurrentJobs = 12  # Default to 12 concurrent jobs
)

# Function to get formatted timestamp
function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

Write-Host "[$((Get-Timestamp))] Starting TIFF analysis script"
Write-Host "[$((Get-Timestamp))] Source folder: $sourceFolder"
Write-Host "[$((Get-Timestamp))] Destination folder: $destinationFolder"
Write-Host "[$((Get-Timestamp))] Maximum concurrent jobs: $maxConcurrentJobs"

# Create the destination folder if it doesn't exist
if (-not (Test-Path -Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
}

# Get all folders containing TIFF files
Write-Host "[$((Get-Timestamp))] Scanning for folders containing TIFF files..."
$tiffFolders = @(Get-ChildItem -Path $sourceFolder -Recurse -Filter *.tif | Select-Object -ExpandProperty Directory -Unique)
$totalFolders = $tiffFolders.Count
Write-Host "[$((Get-Timestamp))] Found $totalFolders folders with TIFF files to process"

$processedFolders = 0
$movedFolders = 0
$errorFolders = 0

# Process folders in batches
$currentJobs = @()

foreach ($folder in $tiffFolders) {
    # Wait if we have reached max concurrent jobs
    while ($currentJobs.Count -ge $maxConcurrentJobs) {
        $completedJobs = @($currentJobs | Where-Object { $_.State -eq 'Completed' })
        
        foreach ($job in $completedJobs) {
            $result = Receive-Job -Job $job
            if ($result.Status -eq "Moved") {
                $movedFolders++
                Write-Host "[$((Get-Timestamp))] Moved folder: $($result.Folder)"
                Write-Host "[$((Get-Timestamp))] Trigger file: $($result.TriggerFile) ($($result.Dimensions))"
            }
            elseif ($result.Status -eq "Error") {
                $errorFolders++
                Write-Warning "[$((Get-Timestamp))] Error: $($result.Folder) - $($result.Error)"
            }
            Remove-Job -Job $job
            $processedFolders++
        }
        
        $currentJobs = @($currentJobs | Where-Object { $_.State -eq 'Running' })
        
        if ($currentJobs.Count -ge $maxConcurrentJobs) {
            Start-Sleep -Milliseconds 500
        }
        
        $progress = [math]::Round(($processedFolders / $totalFolders) * 100, 2)
        Write-Progress -Activity "Processing folders" -Status "$progress% Complete ($processedFolders of $totalFolders)" -PercentComplete $progress
    }
    
    # Start new job
    $job = Start-Job -ScriptBlock {
        param($folderPath, $sourceFolder, $destinationFolder, $maxWidth, $maxHeight)
        
        try {
            # Check all TIFF files in the folder
            $tiffFiles = Get-ChildItem -Path $folderPath -Filter *.tif
            $needsMoving = $false
            $triggerFile = $null
            $triggerDimensions = ""

            foreach ($file in $tiffFiles) {
                $dimensions = magick identify -format "%w %h" $file.FullName 2>$null
                if ($LASTEXITCODE -eq 0 -and $dimensions) {
                    $width, $height = $dimensions -split " "
                    
                    if ([int]$width -ge $maxWidth -or [int]$height -ge $maxHeight) {
                        $needsMoving = $true
                        $triggerFile = $file.FullName
                        $triggerDimensions = "${width}x${height}"
                        break
                    }
                }
            }

            if ($needsMoving) {
                # Calculate relative path to maintain folder structure
                $relativePath = $folderPath.Substring($sourceFolder.Length)
                $destinationPath = Join-Path $destinationFolder $relativePath

                # Create destination directory if it doesn't exist
                if (-not (Test-Path -Path $destinationPath)) {
                    New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
                }

                # Move all files from the source folder to destination
                Get-ChildItem -Path $folderPath | ForEach-Object {
                    Move-Item -Path $_.FullName -Destination $destinationPath -Force
                }

                return @{
                    Status = "Moved"
                    Folder = $folderPath
                    TriggerFile = $triggerFile
                    Dimensions = $triggerDimensions
                }
            }
        }
        catch {
            return @{
                Status = "Error"
                Folder = $folderPath
                Error = $_.Exception.Message
            }
        }
        
        return @{
            Status = "Skipped"
            Folder = $folderPath
        }
    } -ArgumentList $folder.FullName, $sourceFolder, $destinationFolder, $maxWidth, $maxHeight
    
    $currentJobs += $job
}

# Wait for remaining jobs to complete
while ($currentJobs.Count -gt 0) {
    $completedJobs = @($currentJobs | Where-Object { $_.State -eq 'Completed' })
    
    foreach ($job in $completedJobs) {
        $result = Receive-Job -Job $job
        if ($result.Status -eq "Moved") {
            $movedFolders++
            Write-Host "[$((Get-Timestamp))] Moved folder: $($result.Folder)"
            Write-Host "[$((Get-Timestamp))] Trigger file: $($result.TriggerFile) ($($result.Dimensions))"
        }
        elseif ($result.Status -eq "Error") {
            $errorFolders++
            Write-Warning "[$((Get-Timestamp))] Error: $($result.Folder) - $($result.Error)"
        }
        Remove-Job -Job $job
        $processedFolders++
    }
    
    $currentJobs = @($currentJobs | Where-Object { $_.State -eq 'Running' })
    
    if ($currentJobs.Count -gt 0) {
        Start-Sleep -Milliseconds 500
    }
    
    $progress = [math]::Round(($processedFolders / $totalFolders) * 100, 2)
    Write-Progress -Activity "Processing folders" -Status "$progress% Complete ($processedFolders of $totalFolders)" -PercentComplete $progress
}

Write-Progress -Activity "Processing folders" -Completed

Write-Host ""
Write-Host "[$((Get-Timestamp))] Processing complete!"
Write-Host "[$((Get-Timestamp))] Total folders processed: $processedFolders"
Write-Host "[$((Get-Timestamp))] Folders moved: $movedFolders"
Write-Host "[$((Get-Timestamp))] Folders with errors: $errorFolders"