<#
.SYNOPSIS
    Generates the library's object type classes into src/ from DancingGoat.

.DESCRIPTION
    The library's object types live in a module whose code name starts with "CMS.", which the code
    generator skips unless CMSDevelopmentMode is true. This script sets CMSDevelopmentMode for the
    generator process only, runs DancingGoat's --kxp-codegen for the library's classes, and restores
    "partial" on the generated types: in development mode the generator writes them without it, and
    the library configures TYPEINFO in partial classes.

    Stop DancingGoat first: dotnet run builds it. See "Custom object types" in docs/Contributing-Setup.md.

.EXAMPLE
    ./scripts/Update-ObjectTypeClasses.ps1
    ./scripts/Update-ObjectTypeClasses.ps1 -Include "KenticoRepoTemplate.Item"
#>
[CmdletBinding()]
param (
    # Class code names to generate; ';' separates names, '*' matches a prefix. Always the library's class namespace,
    # since development mode also turns off the filter for Xperience's own system classes
    [string]$Include = 'KenticoRepoTemplate.*',

    # C# namespace of the generated classes (the default is the module code name)
    [string]$Namespace = 'Kentico.Xperience.RepoTemplate',

    # Output folder, relative to the repository root; one subfolder per class
    [string]$OutputPath = 'src/Kentico.Xperience.RepoTemplate/Classes'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$project = Join-Path $root 'examples/DancingGoat'
$output = Join-Path $root $OutputPath

$previous = $env:CMSDevelopmentMode
$env:CMSDevelopmentMode = 'true'
try {
    Push-Location $project
    # No dedicated *InfoProvider classes: the library uses IInfoProvider<TInfo>
    dotnet run -- --kxp-codegen --type Classes --include $Include --namespace $Namespace --location "$output/{name}" --with-provider-class False --skip-confirmation
    if ($LASTEXITCODE -ne 0) { throw "Code generation failed (exit code $LASTEXITCODE)." }
}
finally {
    Pop-Location
    $env:CMSDevelopmentMode = $previous
}

if (-not (Test-Path $output)) {
    Write-Warning "Nothing generated: no class matches '$Include'."
    return
}

# Development mode drops "partial" from generated classes and interfaces; put it back
$pattern = '(?m)^(\s*public )(?!partial )(class|interface) '
foreach ($file in Get-ChildItem $output -Recurse -Filter '*.generated.cs') {
    $text = [IO.File]::ReadAllText($file.FullName)
    $fixed = [regex]::Replace($text, $pattern, '$1partial $2 ')
    if ($fixed -ne $text) {
        [IO.File]::WriteAllText($file.FullName, $fixed)
        Write-Host "Restored partial: $([IO.Path]::GetRelativePath($root, $file.FullName))"
    }
}
