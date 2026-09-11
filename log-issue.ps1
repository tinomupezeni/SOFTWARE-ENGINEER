<#
.SYNOPSIS
    Quick issue logger for dev-logs repository

.DESCRIPTION
    Creates a new issue log from template and opens it in your default editor.
    Automatically determines project from current directory and groups by technical area.

.PARAMETER Project
    Project name (CRM, HBEC, SMEPULSE, etc.). Auto-detected if not specified.

.PARAMETER Title
    Brief description for filename (e.g., "backend-crash-loop")

.PARAMETER Severity
    Issue severity: Critical, High, Medium, or Low

.PARAMETER Category
    Technical category (e.g., Backend_and_API). Auto-prompted if not specified.

.EXAMPLE
    .\log-issue.ps1 -Title "backend-crash-loop" -Severity Critical -Category Backend_and_API
    .\log-issue.ps1 -Project CRM -Title "nginx-not-starting" -Severity High -Category DevOps_and_Infrastructure
#>

param(
    [Parameter(Position = 0)]
    [string]$Project = "",

    [Parameter(Position = 1, Mandatory = $true)]
    [string]$Title,

    [Parameter(Position = 2)]
    [ValidateSet("Critical", "High", "Medium", "Low")]
    [string]$Severity = "High",

    [Parameter(Position = 3)]
    [ValidateSet("Architecture_and_Design", "Database_and_State", "DevOps_and_Infrastructure", "Backend_and_API", "Frontend_and_UI", "Mobile_Apps", "Integrations_and_Auth")]
    [string]$Category = ""
)

$DEV_LOGS_DIR = "C:\Users\Dell\Documents\projects\dev-logs"
$TEMPLATE = "$DEV_LOGS_DIR\templates\issue-template.md"

# Categories
$CATEGORIES = @(
    "Architecture_and_Design",
    "Database_and_State",
    "DevOps_and_Infrastructure",
    "Backend_and_API",
    "Frontend_and_UI",
    "Mobile_Apps",
    "Integrations_and_Auth"
)

# Project mapping
$PROJECT_MAP = @{
    "CRM" = @{ Name = "CRM Professional"; Path = "*\CRM\*" }
    "HBEC" = @{ Name = "HBEC Student"; Path = "*\HBEC\*" }
    "SMEPULSE" = @{ Name = "SMEPulse"; Path = "*\SMEPULSE\*" }
    "Tese" = @{ Name = "Tese Marketplace"; Path = "*\New Tesee\*" }
    "ZCHPC-ERP" = @{ Name = "ZCHPC ERP"; Path = "*\ZCHPC-ERP\*" }
    "Market-Link" = @{ Name = "Market Link"; Path = "*\Market-Link\*" }
}

# Auto-detect project if not specified
if (-not $Project) {
    $currentPath = Get-Location
    foreach ($key in $PROJECT_MAP.Keys) {
        if ($currentPath -like $PROJECT_MAP[$key].Path) {
            $Project = $key
            break
        }
    }

    if (-not $Project) {
        Write-Host "Could not auto-detect project. Please specify with -Project parameter." -ForegroundColor Red
        Write-Host "Available projects: $($PROJECT_MAP.Keys -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

# Validate project
if (-not $PROJECT_MAP.ContainsKey($Project)) {
    Write-Host "Unknown project: $Project" -ForegroundColor Red
    Write-Host "Available projects: $($PROJECT_MAP.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

# Prompt for category if not provided
if (-not $Category) {
    Write-Host "Please select a technical category for this log:" -ForegroundColor Cyan
    for ($i=0; $i -lt $CATEGORIES.Length; $i++) {
        Write-Host "  [$($i+1)] $($CATEGORIES[$i])"
    }
    
    $selection = 0
    while ($selection -lt 1 -or $selection -gt $CATEGORIES.Length) {
        $selection = Read-Host "Enter number (1-$($CATEGORIES.Length))"
    }
    $Category = $CATEGORIES[$selection-1]
}

# Create category folder if it doesn't exist
$categoryDir = "$DEV_LOGS_DIR\$Category"
if (-not (Test-Path $categoryDir)) {
    New-Item -ItemType Directory -Path $categoryDir -Force | Out-Null
    Write-Host "Created new category folder: $categoryDir" -ForegroundColor Green
}

# Generate filename with project prefix
$date = Get-Date -Format "yyyy-MM-dd"
$filename = "$Project-$date-$($Title.ToLower() -replace '\s+', '-').md"
$logPath = "$categoryDir\$filename"

# Check if file already exists
if (Test-Path $logPath) {
    Write-Host "Error: Log file already exists: $logPath" -ForegroundColor Red
    exit 1
}

# Copy template
Copy-Item $TEMPLATE $logPath

# Replace placeholders
$content = Get-Content $logPath -Raw
$content = $content -replace '\[Brief Issue Title\]', ($Title -replace '-', ' ')
$content = $content -replace 'YYYY-MM-DD', $date
$content = $content -replace '\[Project Name\]', $PROJECT_MAP[$Project].Name
$content = $content -replace '\[Critical/High/Medium/Low\]', $Severity
$content = $content -replace '\[Resolved/Investigating/Workaround Applied\]', 'Resolved'
$content = $content -replace '\[Production/Staging/Development\]', 'Production'

Set-Content $logPath $content

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Issue Log Created Successfully" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project:  " -NoNewline
Write-Host $PROJECT_MAP[$Project].Name -ForegroundColor Green
Write-Host "Category: " -NoNewline
Write-Host $Category -ForegroundColor Cyan
Write-Host "File:     " -NoNewline
Write-Host $logPath -ForegroundColor Yellow
Write-Host "Severity: " -NoNewline
Write-Host $Severity -ForegroundColor $(if ($Severity -eq "Critical") { "Red" } else { "Yellow" })
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit the file and fill in all sections"
Write-Host "  2. Commit: git add $Category\$filename"
Write-Host "  3. Push:   git commit -m 'Docs: Add log for $Title in $Category'"
Write-Host ""

# Open in default editor
Start-Process $logPath

# Return to dev-logs directory
Set-Location $DEV_LOGS_DIR
