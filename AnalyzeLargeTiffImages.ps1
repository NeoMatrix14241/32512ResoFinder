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

# Get all TIFF files
Write-Host "[$((Get-Timestamp))] Scanning for TIFF files..."
$tiffFiles = @(Get-ChildItem -Path $sourceFolder -Recurse -Filter *.tif)
$totalFiles = $tiffFiles.Count
Write-Host "[$((Get-Timestamp))] Found $totalFiles TIFF files to process"

$processedFiles = 0
$copiedFiles = 0
$errorFiles = 0

# Process files in batches
$currentJobs = @()

foreach ($file in $tiffFiles) {
    # Wait if we have reached max concurrent jobs
    while ($currentJobs.Count -ge $maxConcurrentJobs) {
        $completedJobs = @($currentJobs | Where-Object { $_.State -eq 'Completed' })
        
        foreach ($job in $completedJobs) {
            $result = Receive-Job -Job $job
            if ($result.Status -eq "Copied") {
                $copiedFiles++
                Write-Host "[$((Get-Timestamp))] Copied: $($result.File) ($($result.Dimensions))"
            }
            elseif ($result.Status -eq "Error") {
                $errorFiles++
                Write-Warning "[$((Get-Timestamp))] Error: $($result.File) - $($result.Error)"
            }
            Remove-Job -Job $job
            $processedFiles++
        }
        
        $currentJobs = @($currentJobs | Where-Object { $_.State -eq 'Running' })
        
        if ($currentJobs.Count -ge $maxConcurrentJobs) {
            Start-Sleep -Milliseconds 500
        }
        
        $progress = [math]::Round(($processedFiles / $totalFiles) * 100, 2)
        Write-Progress -Activity "Processing TIFF files" -Status "$progress% Complete ($processedFiles of $totalFiles)" -PercentComplete $progress
    }
    
    # Start new job
    $job = Start-Job -ScriptBlock {
        param($filePath, $sourceFolder, $destinationFolder, $maxWidth, $maxHeight)
        
        try {
            $dimensions = magick identify -format "%w %h" $filePath 2>$null
            if ($LASTEXITCODE -eq 0 -and $dimensions) {
                $width, $height = $dimensions -split " "
                
                if ([int]$width -gt $maxWidth -or [int]$height -gt $maxHeight) {
                    $relativePath = $filePath.Substring($sourceFolder.Length)
                    $destinationPath = Join-Path $destinationFolder $relativePath
                    
                    $destinationDir = Split-Path $destinationPath
                    if (-not (Test-Path -Path $destinationDir)) {
                        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
                    }
                    
                    Copy-Item -Path $filePath -Destination $destinationPath -Force
                    return @{
                        Status = "Copied"
                        File = $filePath
                        Dimensions = "${width}x${height}"
                    }
                }
            }
            else {
                return @{
                    Status = "Error"
                    File = $filePath
                    Error = "Could not read dimensions"
                }
            }
        }
        catch {
            return @{
                Status = "Error"
                File = $filePath
                Error = $_.Exception.Message
            }
        }
        
        return @{
            Status = "Skipped"
            File = $filePath
        }
    } -ArgumentList $file.FullName, $sourceFolder, $destinationFolder, $maxWidth, $maxHeight
    
    $currentJobs += $job
}

# Wait for remaining jobs to complete
while ($currentJobs.Count -gt 0) {
    $completedJobs = @($currentJobs | Where-Object { $_.State -eq 'Completed' })
    
    foreach ($job in $completedJobs) {
        $result = Receive-Job -Job $job
        if ($result.Status -eq "Copied") {
            $copiedFiles++
            Write-Host "[$((Get-Timestamp))] Copied: $($result.File) ($($result.Dimensions))"
        }
        elseif ($result.Status -eq "Error") {
            $errorFiles++
            Write-Warning "[$((Get-Timestamp))] Error: $($result.File) - $($result.Error)"
        }
        Remove-Job -Job $job
        $processedFiles++
    }
    
    $currentJobs = @($currentJobs | Where-Object { $_.State -eq 'Running' })
    
    if ($currentJobs.Count -gt 0) {
        Start-Sleep -Milliseconds 500
    }
    
    $progress = [math]::Round(($processedFiles / $totalFiles) * 100, 2)
    Write-Progress -Activity "Processing TIFF files" -Status "$progress% Complete ($processedFiles of $totalFiles)" -PercentComplete $progress
}

Write-Progress -Activity "Processing TIFF files" -Completed

Write-Host ""
Write-Host "[$((Get-Timestamp))] Processing complete!"
Write-Host "[$((Get-Timestamp))] Total files processed: $processedFiles"
Write-Host "[$((Get-Timestamp))] Files copied: $copiedFiles"
Write-Host "[$((Get-Timestamp))] Files with errors: $errorFiles"