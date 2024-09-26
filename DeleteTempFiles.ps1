# Log file location
$logDir = "C:/temp"
$logFile = [System.IO.Path]::Combine($logDir, "temp_cleanup.log")

# Ensure the log directory exists
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Function to write to log
function Write-Log {
    param (
        [string]$message,
        [string]$logLevel = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$logLevel] $message"

    # Write to console
    switch ($logLevel) {
        "INFO" { Write-Host $logEntry -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
    }

    # Write to log file
    Add-Content -Path $logFile -Value $logEntry
}

# Function to check if a file is in use
function Test-FileInUse {
    param (
        [string]$FilePath
    )
    try {
        $stream = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'Read')
        $stream.Close()
        return $false # File is not in use
    } catch {
        return $true  # File is in use
    }
}

# Function to delete files and directories with error handling
function Remove-TempFiles {
    param (
        [string]$path
    )
    if (Test-Path -Path $path) {
        Write-Log "Cleaning directory: $path"

        # Remove files
        Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not (Test-FileInUse $_.FullName)) {
                try {
                    Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                    Write-Log "Deleted: $($_.FullName)" "SUCCESS"
                } catch {
                    Write-Log "Failed to delete: $($_.FullName) - $_" "ERROR"
                }
            } else {
                Write-Log "Skipping file in use: $($_.FullName)" "WARN"
            }
        }

        # Remove empty directories after files have been processed
        Get-ChildItem -Path $path -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                if (-not (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue)) {
                    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
                    Write-Log "Deleted empty directory: $($_.FullName)" "SUCCESS"
                } else {
                    Write-Log "Directory not empty: $($_.FullName)" "WARN"
                }
            } catch {
                Write-Log "Failed to delete directory: $($_.FullName) - $_" "ERROR"
            }
        }
    } else {
        Write-Log "Directory does not exist: $path" "WARN"
    }
}

# Define the directories to clean
$directories = @(
    "$env:TEMP",
    [System.IO.Path]::Combine($env:WINDIR, "Temp"),
    [System.IO.Path]::Combine($env:WINDIR, "%Temp%"),
    [System.IO.Path]::Combine($env:WINDIR, "Prefetch")
)

# Loop through each directory and clean
foreach ($dir in $directories) {
    Remove-TempFiles -path $dir
}

# Final success message
Write-Log "Temporary file cleanup completed successfully." "SUCCESS"

# Freeze window and wait for keypress
Read-Host -Prompt "Press Enter to exit"
