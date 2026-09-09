<#
    PyKit Explorer - Board Provisioning Script (Windows)
    ------------------------------------------------------
    Fully provisions a fresh PyKit Explorer board by downloading the code
    modules from Bitbucket and copying the runtime content onto the CIRCUITPY
    drive. No local copy of the repo and no Python install on the host
    machine are required.

    This OVERWRITES code.py, README.md, pykit_explorer.py, and the API,
    AudioFiles, Fonts, Images, and lib folders on CIRCUITPY.
    Intended for provisioning a brand-new board, NOT for updating a board a
    student has already been working on (it will wipe their code.py).

    Usage:
      Double-click provision-board.bat - this is the supported way to run
      this script. It passes -ExecutionPolicy Bypass for you, which most
      Windows machines need (the default execution policy blocks .ps1
      files from running at all, including via right-click > Run with
      PowerShell, and that block happens before this script's own code -
      including its "press enter to close" prompt - ever runs).

      Advanced / command-line usage:
      powershell -ExecutionPolicy Bypass -File provision-board.ps1
      powershell -ExecutionPolicy Bypass -File provision-board.ps1 -Force
      powershell -ExecutionPolicy Bypass -File provision-board.ps1 -Ref v1.2.0

    Once this script is actually running, this window stays open and waits
    for a keypress when finished, whether it succeeds, fails, or is
    cancelled.
#>

param(
    [switch]$Force,
    [string]$Ref = "master"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is much faster with the progress bar off
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RepoHost    = "bitbucket.microchip.com"
$RepoProject = "~c52467"
$RepoSlug    = "pykit-explorer-code-modules"

# Content copied to the root of CIRCUITPY. Update these if the repo structure changes.
$FoldersToCopy = @("API", "AudioFiles", "Fonts", "Images", "lib")
$FilesToCopy   = @("README.md", "code.py", "pykit_explorer.py")

function Invoke-Provisioning {
    Write-Host "=== PyKit Explorer Board Provisioner ===" -ForegroundColor Cyan
    Write-Host "Source: $RepoHost/$RepoProject/$RepoSlug@$Ref"

    # --- 1. Find the CIRCUITPY drive -------------------------------------------
    $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel -eq "CIRCUITPY" }

    if (-not $volumes) {
        Write-Host "No CIRCUITPY drive found." -ForegroundColor Red
        Write-Host "Plug in the board and make sure it shows up as a drive named CIRCUITPY, then try again." -ForegroundColor Yellow
        return 1
    }
    if (@($volumes).Count -gt 1) {
        Write-Host "Warning: multiple CIRCUITPY drives detected. Using the first one found." -ForegroundColor Yellow
    }
    $DriveLetter = (@($volumes) | Select-Object -First 1).DriveLetter
    $DriveRoot   = "${DriveLetter}:\"

    if (-not (Test-Path (Join-Path $DriveRoot "boot_out.txt"))) {
        Write-Host "The drive $DriveRoot is labeled CIRCUITPY but doesn't look like a CircuitPython board (no boot_out.txt found)." -ForegroundColor Red
        Write-Host "Aborting so we don't touch the wrong drive." -ForegroundColor Yellow
        return 1
    }
    Write-Host "Found CircuitPython board at $DriveRoot"

    # --- 2. Confirm before doing anything destructive ---------------------------
    if (-not $Force) {
        Write-Host ""
        Write-Host "This will REPLACE the following on $DriveRoot with the version from Bitbucket:" -ForegroundColor Yellow
        Write-Host ("  Folders: " + ($FoldersToCopy -join ", "))
        Write-Host ("  Files:   " + ($FilesToCopy -join ", "))
        Write-Host "Any code or data currently in those folders/files on the board will be lost." -ForegroundColor Yellow
        $answer = Read-Host "Continue? (y/N)"
        if ($answer -notmatch '^[Yy]') {
            Write-Host "Cancelled. No changes made."
            return 0
        }
    }

    # --- 3. Clone the source repo -----------------------------------------------
    $TempDir    = Join-Path $env:TEMP ("pykit-provision-" + [guid]::NewGuid())
    $RepoDir    = Join-Path $TempDir "repo"
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    try {
        $RepoUrl = "https://$RepoHost/scm/$RepoProject/$RepoSlug.git"
        Write-Host "Cloning $RepoUrl@$Ref ..."
        & git clone --depth 1 --branch $Ref $RepoUrl $RepoDir
        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed. Confirm Git is installed and your Bitbucket credentials have read access."
        }

        # --- 4. Copy folders and files onto the drive ---------------------------
        foreach ($folder in $FoldersToCopy) {
            $src = Join-Path $RepoDir $folder
            $dst = Join-Path $DriveRoot $folder
            if (-not (Test-Path $src)) {
                Write-Host "Skipping '$folder' (not found in repo at $Ref)" -ForegroundColor Yellow
                continue
            }
            if (Test-Path $dst) {
                Remove-Item -Path $dst -Recurse -Force
            }
            Write-Host "Copying $folder ..."
            Copy-Item -Path $src -Destination $DriveRoot -Recurse -Force
        }

        foreach ($file in $FilesToCopy) {
            $src = Join-Path $RepoDir $file
            if (-not (Test-Path $src)) {
                Write-Host "Skipping '$file' (not found in repo at $Ref)" -ForegroundColor Yellow
                continue
            }
            Write-Host "Copying $file ..."
            Copy-Item -Path $src -Destination $DriveRoot -Force
        }

        # --- 5. Write provenance info (best-effort, never fails the run) --------
        try {
            $Sha  = (& git -C $RepoDir rev-parse HEAD).Substring(0, 7)
            $Line = "Provisioned from $RepoHost/$RepoProject/$RepoSlug@$Ref (commit $Sha) on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        } catch {
            $Line = "Provisioned from $RepoHost/$RepoProject/$RepoSlug@$Ref on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        }
        Set-Content -Path (Join-Path $DriveRoot "PROVISION_INFO.txt") -Value $Line

        Write-Host ""
        Write-Host "Done! Board provisioned at $DriveRoot" -ForegroundColor Green
        return 0
    }
    finally {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Run everything, then ALWAYS pause before the window closes. This matters most
# when the script is launched via right-click > "Run with PowerShell", which
# closes the window the instant the script ends - success, failure, or
# cancellation - with no chance to read the output otherwise.
$ExitCode = 1
try {
    $ExitCode = Invoke-Provisioning
} catch {
    Write-Host ""
    Write-Host "Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
    $ExitCode = 1
}

Write-Host ""
Read-Host "Press Enter to close this window"
exit $ExitCode
