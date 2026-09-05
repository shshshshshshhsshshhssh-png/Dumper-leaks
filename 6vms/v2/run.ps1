# 69ms - unveilr logger runner
# Usage:  .\run.ps1 <input.lua> [out.lua] [extra settings...]
# Example: .\run.ps1 sample.lua out.lua debug
param(
    [Parameter(Mandatory = $true)] [string]$Input,
    [string]$Out = "out.lua",
    [Parameter(ValueFromRemainingArguments = $true)] [string[]]$Extra
)

# lute.exe (runs hookOp) must be referenced by absolute path; process.exec does
# not search the current directory on Windows.
$env:HOOKOP_BIN = Join-Path $PSScriptRoot "lute.exe"

Set-Location $PSScriptRoot
lune run main.luau $Input "out=$Out" @Extra
Write-Host "Done -> $Out"
