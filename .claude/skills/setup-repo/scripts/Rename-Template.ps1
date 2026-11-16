<#
.SYNOPSIS
    Renames the repository template's sentinel tokens, files, and folders for a new project,
    and removes what the chosen family, example, and admin options do not use.

.DESCRIPTION
    One-time setup step. Replaces every template token (see ../references/naming.md)
    in tracked text files, renames files and folders, prunes files and marked blocks
    (see ../references/family-edits.md and ../references/remove-admin.md), regenerates
    local-only secrets and ports, and formats the renamed C# files.
    Fails if any template token or marker remains afterwards.

.EXAMPLE
    ./.claude/skills/setup-repo/scripts/Rename-Template.ps1 -Family Labs -Name CoolThing [-Example] [-NoAdmin]
    ./.claude/skills/setup-repo/scripts/Rename-Template.ps1 -Family Community -Name CoolThing -GitHubOrg jane-doe -Author "Jane Doe"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateSet('Kentico', 'Labs', 'Community')]
    [string]$Family,

    # PascalCase identifier, no spaces or periods, e.g. CoolThing
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Z][A-Za-z0-9]*$')]
    [string]$Name,

    # Human-readable name with spaces, e.g. "Cool Thing". Defaults to Name split on word boundaries
    [string]$DisplayName,

    # Example source code repository (not a published library). Labs examples get "labs" in the repository slug
    [switch]$Example,

    # The project has no administration UI: removes the .Admin project and everything that serves it
    [switch]$NoAdmin,

    # Defaults to xperience-by-kentico-<name> (Labs example: xperience-by-kentico-labs-<name>; Community: xperience-community-<name>)
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$RepoSlug,

    # GitHub user or organization that owns the repository. Defaults to Kentico; required for Community
    [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$')]
    [string]$GitHubOrg,

    # Community only, required: the author or company name for package metadata and LICENSE.md
    [string]$Author,

    # The repository's DancingGoat "administrator" password: committed as a hash in the CI repository,
    # used by every local database and the e2e tests. Local development only; no quotes, backticks, $, or spaces
    [ValidatePattern('^[^\s''"`$]{8,}$')]
    [string]$AdminPassword = 'Pass@12345',

    # Print the derived names and exit without changing files
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'

$root = (git rev-parse --show-toplevel).Trim()
Set-Location $root

$kebab = ($Name -creplace '(?<=[a-z])(?=[A-Z])|(?<=[A-Z0-9])(?=[A-Z][a-z])', '-').ToLowerInvariant()

$names = switch ($Family) {
    'Kentico' { @{ DotNet = "Kentico.Xperience.$Name"; AdminOrg = 'kentico'; AdminProject = "xperience-$kebab-admin"; Slug = "xperience-by-kentico-$kebab" } }
    'Labs' { @{ DotNet = "Kentico.Xperience.Labs.$Name"; AdminOrg = 'kentico'; AdminProject = "xperience-labs-$kebab-admin"; Slug = "xperience-by-kentico-$kebab" } }
    'Community' { @{ DotNet = "XperienceCommunity.$Name"; AdminOrg = 'xperience'; AdminProject = "community-$kebab-admin"; Slug = "xperience-community-$kebab" } }
}

if ($Example -and $Family -eq 'Labs') { $names.Slug = "xperience-by-kentico-labs-$kebab" }
if ($RepoSlug) { $names.Slug = $RepoSlug }

if ($Family -eq 'Community') {
    if (-not $GitHubOrg) { throw 'GitHubOrg is required for the Community family.' }
    if (-not $Author) { throw 'Author is required for the Community family.' }
}
elseif ($Author) {
    throw 'Author applies to the Community family only; Kentico and Labs keep Kentico Software.'
}
if (-not $GitHubOrg) { $GitHubOrg = 'Kentico' }

if (-not $DisplayName) { $DisplayName = $Name -creplace '(?<=[a-z])(?=[A-Z])|(?<=[A-Z0-9])(?=[A-Z][a-z])', ' ' }
$productPrefix = switch ($Family) {
    'Kentico' { 'Xperience by Kentico' }
    'Labs' { 'Xperience by Kentico Labs' }
    'Community' { 'Xperience Community' }
}

$dotNet = $names.DotNet
$moduleKey = "$($names.AdminOrg)-$($names.AdminProject)"
$publishing = if ($Example) { 'none (example)' } elseif ($Family -eq 'Community') { 'GitHub Actions (publish.yml)' } else { 'Azure DevOps (.azuredevops)' }

function Write-Names {
    Write-Host "Family:        $Family$(if ($Example) { ' (example)' })"
    Write-Host ".NET name:     $dotNet (+ $(if (-not $NoAdmin) { "$dotNet.Admin, " })$dotNet.Tests)"
    Write-Host "Repository:    $GitHubOrg/$($names.Slug)"
    Write-Host "Admin module:  $(if ($NoAdmin) { 'none (.Admin project removed)' } else { $moduleKey })"
    Write-Host "Product name:  $productPrefix`: $DisplayName"
    Write-Host "Publishing:    $publishing"
    if ($Author) { Write-Host "Author:        $Author" }
    Write-Host "Admin login:   administrator / $AdminPassword"
}

if ($Preview) {
    Write-Names
    return
}

# Ordered most-specific first; later tokens are substrings of earlier ones
$tokens = @(
    , @('Kentico/xperience-by-kentico-repotemplate', "$GitHubOrg/$($names.Slug)")
    , @('xperience-by-kentico-repotemplate', $names.Slug)
    , @('"@kentico/xperience-repotemplate-admin', "`"@$($names.AdminOrg)/$($names.AdminProject)")
    , @('RegisterClientModule("kentico", "xperience-repotemplate-admin")', "RegisterClientModule(`"$($names.AdminOrg)`", `"$($names.AdminProject)`")")
    , @("orgName: 'kentico'", "orgName: '$($names.AdminOrg)'")
    , @('<AdminOrgName>kentico</AdminOrgName>', "<AdminOrgName>$($names.AdminOrg)</AdminOrgName>")
    , @('kentico-xperience-repotemplate-admin', $moduleKey)
    , @('xperience-repotemplate-admin', $names.AdminProject)
    , @('Kentico-Xperience-RepoTemplate', $dotNet.Replace('.', '-'))
    , @('Kentico.Xperience.RepoTemplate', $dotNet)
    , @('kentico.xperience.repotemplate', $dotNet.ToLowerInvariant())
    , @('Xperience by Kentico: Repo Template', "$productPrefix`: $DisplayName")
    , @('Repo Template', $DisplayName)
    , @('RepoTemplate', $Name)
    , @('repotemplate', $kebab)
)

$textExtensions = @(
    '.cs', '.csproj', '.props', '.targets', '.slnx', '.sln', '.json', '.yml', '.yaml', '.md',
    '.js', '.mjs', '.ts', '.tsx', '.css', '.cshtml', '.razor', '.ps1', '.xml', '.config', '.txt'
)
$textNames = @('.editorconfig', '.gitignore', '.gitattributes', 'CODEOWNERS')

# Not renamed: this skill (template-only), and the Xperience CI repository (DancingGoat object data, no tokens)
$excluded = '^\.claude/skills/setup-repo/|/App_Data/CIRepository/'

function Get-TemplateFiles {
    git ls-files --cached --others --exclude-standard |
        Where-Object { $_ -notmatch $excluded -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Where-Object { $textExtensions -contains [IO.Path]::GetExtension($_) -or $textNames -contains [IO.Path]::GetFileName($_) }
}

# Writes UTF-8 text, keeping the byte order mark the file already has (or lacks)
function Set-Text($path, $text) {
    $bom = $false
    if (Test-Path -LiteralPath $path) {
        $stream = [IO.File]::OpenRead($path)
        try {
            $head = [byte[]]::new(3)
            $bom = $stream.Read($head, 0, 3) -eq 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF
        }
        finally { $stream.Dispose() }
    }
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($bom))
}

# Rewrites a file through a transform; missing files and unchanged content are left alone
function Update-File($path, [scriptblock]$transform) {
    $full = Join-Path $root $path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return }
    $content = [IO.File]::ReadAllText($full)
    $updated = [string](& $transform $content)
    if ($updated -cne $content) { Set-Text $full $updated }
}

function Remove-Path($path) {
    $full = Join-Path $root $path
    if (Test-Path -LiteralPath $full) {
        Remove-Item -LiteralPath $full -Recurse -Force
        Write-Host "Removed $path"
    }
}

# 1. Remove template-only CI
Remove-Path '.github/workflows/template-smoke.yml'

# 2. Replace tokens in file contents (case-sensitive, ordered)
foreach ($file in Get-TemplateFiles) {
    $full = Join-Path $root $file
    $content = [IO.File]::ReadAllText($full)
    $updated = $content
    foreach ($token in $tokens) {
        $updated = $updated.Replace($token[0], $token[1])
    }
    if ($updated -cne $content) {
        Set-Text $full $updated
        Write-Host "Updated $file"
    }
}

# 3. Rename files and folders, deepest first
$paths = git ls-files --cached --others --exclude-standard |
    Where-Object { $_ -notmatch $excluded } |
    ForEach-Object {
        $parts = $_ -split '/'
        for ($i = 1; $i -le $parts.Length; $i++) { ($parts[0..($i - 1)] -join '/') }
    } |
    Sort-Object -Unique |
    Where-Object { (Split-Path $_ -Leaf) -cmatch 'RepoTemplate' } |
    Sort-Object { ($_ -split '/').Length } -Descending

foreach ($path in $paths) {
    $leaf = Split-Path $path -Leaf
    $newLeaf = $leaf.Replace('Kentico.Xperience.RepoTemplate', $dotNet).Replace('RepoTemplate', $Name)
    if (Test-Path -LiteralPath $path) {
        Rename-Item -LiteralPath $path -NewName $newLeaf
        Write-Host "Renamed $path -> $newLeaf"
    }
}

# 4. Prune what the family, example, and admin choices do not use
$dg = 'examples/DancingGoat'
$usesAzure = $Family -ne 'Community' -and -not $Example

if (-not $usesAzure) {
    Remove-Path '.azuredevops'
    Remove-Path 'Directory.Build.targets' # code signing
    Update-File '.config/dotnet-tools.json' { param($c) $c -replace '\s*"azuresigntool":\s*\{[^}]*\},', '' }
}
if ($Family -ne 'Community' -or $Example) {
    Remove-Path '.github/workflows/publish.yml'
}
if ($Example) {
    Remove-Path "src/$dotNet.Libs.slnx"
    Update-File 'Directory.Build.props' {
        param($c)
        $c -replace '([ \t]*)(<TargetFramework>[^<]+</TargetFramework>)(\r?\n)', '$1$2$3$1<IsPackable>false</IsPackable>$3'
    }
}
if ($Family -eq 'Community') {
    Update-File 'Directory.Build.props' {
        param($c)
        $c = $c -replace '<Company>[^<]*</Company>', "<Company>$([Security.SecurityElement]::Escape($Author))</Company>"
        $c -replace '[ \t]*<Trademark>[^<]*</Trademark>\r?\n', ''
    }
    Update-File 'LICENSE.md' { param($c) $c -replace '(Copyright \(c\) \d{4}) [^\r\n]+', "`$1 $Author" }
    Update-File '.github/CODEOWNERS' { param($c) $c -replace '(?m)^\* @\S+', "* @$GitHubOrg" }
}
if ($NoAdmin) {
    Remove-Path "src/$dotNet.Admin"
    # The sample admin page these test is gone; admin sign-in and shell tests stay
    Remove-Path 'tests/e2e/admin/custom-template.spec.ts'
    Remove-Path 'tests/e2e/admin/customTemplatePage.ts'

    $adminProject = [regex]::Escape("$dotNet.Admin")
    foreach ($solution in "$dotNet.slnx", "src/$dotNet.Libs.slnx") {
        Update-File $solution { param($c) $c -replace "[ \t]*<Project Path=`"[^`"]*$adminProject\.csproj`" />\r?\n", '' }
    }
    Update-File "$dg/DancingGoat.csproj" { param($c) $c -replace "[ \t]*<ProjectReference Include=`"[^`"]*$adminProject\.csproj`" />\r?\n", '' }
    Update-File "$dg/appsettings.Development.json" {
        param($c) $c -replace ',\s*"CMSAdminClientModuleSettings":\s*\{[^{}]*\{[^{}]*\}[^{}]*\}', ''
    }
    Update-File '.vscode/tasks.json' { param($c) $c -replace '\s*\{[^{}]*"type":\s*"npm"[^{}]*\},?', '' }
    Update-File 'README.md' { param($c) $c.Replace("dotnet add package $dotNet.Admin", "dotnet add package $dotNet") }
}

# Marked blocks: the lines from "template:<tag>:start" through "template:<tag>:end".
# A removed tag loses its blocks; a kept tag loses only the marker lines.
$removedTags = @()
if ($NoAdmin) { $removedTags += 'admin' }
if (-not $usesAzure) { $removedTags += 'azure' }
if ($Example) { $removedTags += 'package' }

foreach ($file in Get-TemplateFiles) {
    Update-File $file {
        param($c)
        if ($c -notmatch 'template:\w+:(start|end)') { return $c }
        foreach ($tag in $removedTags) {
            $c = [regex]::Replace($c, "(?m)^[^\r\n]*template:${tag}:start[^\r\n]*\r?\n[\s\S]*?^[^\r\n]*template:${tag}:end[^\r\n]*(\r?\n|\z)", '')
        }
        [regex]::Replace($c, '(?m)^[^\r\n]*template:\w+:(start|end)[^\r\n]*(\r?\n|\z)', '')
    }
}

# 5. Regenerate local-only secrets, ports, and license year
$appPort = Get-Random -Minimum 40000 -Maximum 60000
$clientPort = Get-Random -Minimum 3010 -Maximum 3100
$secret = "mcp_secret_$([guid]::NewGuid().ToString().ToUpperInvariant())"

foreach ($project in "$dg/DancingGoat.csproj", 'examples/AppHost/AppHost.csproj') {
    Update-File $project { param($c) $c -replace '<UserSecretsId>[^<]+</UserSecretsId>', "<UserSecretsId>$([guid]::NewGuid())</UserSecretsId>" }
}

# Aspire dashboard / resource service / OTLP ports: each committed port gets one new random port
Update-File 'examples/AppHost/Properties/launchSettings.json' {
    param($c)
    $portMap = @{}
    [regex]::Replace($c, 'localhost:(\d+)', {
            param($match)
            $old = $match.Groups[1].Value
            if (-not $portMap.ContainsKey($old)) { $portMap[$old] = Get-Random -Minimum 15000 -Maximum 25000 }
            "localhost:$($portMap[$old])"
        })
}
Update-File "$dg/appsettings.Development.json" {
    param($c)
    $c = $c -replace '"Secret": "[^"]*"', "`"Secret`": `"$secret`""
    $c = $c -replace '(?s)("ManagementApi":\s*\{\s*"Port":\s*)\d+', "`${1}$appPort"
    $c = $c -replace '"ServiceDomain": "localhost:\d+"', "`"ServiceDomain`": `"localhost:$appPort`""
    $c -replace "(?s)(`"$([regex]::Escape($moduleKey))`":\s*\{[^}]*`"Port`":\s*)\d+", "`${1}$clientPort"
}
Update-File 'LICENSE.md' { param($c) $c -replace 'Copyright \(c\) \d{4}', "Copyright (c) $((Get-Date).Year)" }

# DancingGoat administrator password: where it is written, and its hash in the CI repository
# (ASP.NET Core Identity v3 format: PBKDF2 HMAC-SHA512, 100,000 iterations, 16-byte salt, 32-byte subkey)
if ($AdminPassword -cne 'Pass@12345') {
    Update-File 'scripts/Initialize-Database.ps1' { param($c) $c.Replace("[string]`$AdminPassword = 'Pass@12345'", "[string]`$AdminPassword = '$AdminPassword'") }
    Update-File 'tests/e2e/shared/config.ts' { param($c) $c.Replace('adminPassword = "Pass@12345"', "adminPassword = `"$AdminPassword`"") }
    foreach ($doc in 'docs/Contributing-Setup.md', '.claude/skills/setup-local/SKILL.md') {
        Update-File $doc { param($c) [regex]::Replace($c, '(`administrator`[^`\r\n]{1,30})`Pass@12345`', { param($m) "$($m.Groups[1].Value)``$AdminPassword``" }) }
    }

    $salt = [Security.Cryptography.RandomNumberGenerator]::GetBytes(16)
    $subkey = [Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2([Text.Encoding]::UTF8.GetBytes($AdminPassword), $salt, 100000, [Security.Cryptography.HashAlgorithmName]::SHA512, 32)
    $header = [byte[]](1, 0, 0, 0, 2, 0, 1, 0x86, 0xA0, 0, 0, 0, 16)
    $hash = [Convert]::ToBase64String([byte[]]($header + $salt + $subkey))
    Update-File "$dg/App_Data/CIRepository/@global/cms.user/administrator.xml" {
        param($c)
        $c = [regex]::Replace($c, '(<UserPassword>\s*<!\[CDATA\[)[^\]]*(\]\]>)', { param($m) "$($m.Groups[1].Value)$hash$($m.Groups[2].Value)" })
        $c -replace '<UserSecurityStamp>[^<]*</UserSecurityStamp>', "<UserSecurityStamp>$([guid]::NewGuid())</UserSecurityStamp>"
    }
}
Update-File "$dg/Properties/launchSettings.json" { param($c) $c -replace 'http://localhost:\d+', "http://localhost:$appPort" }
Update-File "$dg/appsettings.CI.json" { param($c) $c -replace '"ServiceDomain": "localhost:\d+"', "`"ServiceDomain`": `"localhost:$appPort`"" }
Update-File '.github/workflows/ci.yml' { param($c) $c -replace 'http://localhost:\d+', "http://localhost:$appPort" }
# Channel domains in the CI repository, so a restored database links emails to the local site
Get-ChildItem "$dg/App_Data/CIRepository" -Recurse -Filter *.xml -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Parent.Name -in 'cms.websitechannel', 'emaillibrary.emailchannel' } | ForEach-Object {
        Update-File ([IO.Path]::GetRelativePath($root, $_.FullName)) {
            param($c) $c -replace '(<(WebsiteChannelDomain|EmailChannelServiceDomain)>)localhost:\d+', "`${1}localhost:$appPort"
        }
    }
Update-File '.mcp.json' {
    param($c)
    $c = $c -replace '"MANAGEMENT_API_SECRET": "[^"]*"', "`"MANAGEMENT_API_SECRET`": `"$secret`""
    $c -replace 'http://localhost:\d+/kentico-api', "http://localhost:$appPort/kentico-api"
}
Get-ChildItem src -Recurse -Filter webpack.config.js -File | Where-Object FullName -NotMatch 'node_modules' | ForEach-Object {
    Update-File ([IO.Path]::GetRelativePath($root, $_.FullName)) { param($c) $c -replace 'port: \d+', "port: $clientPort" }
}

# 6. Format the renamed C#: a new root namespace changes how using directives group.
# Folder mode needs no restore.
foreach ($folder in 'src', 'tests') {
    dotnet format whitespace $folder --folder
    if ($LASTEXITCODE -ne 0) { throw "dotnet format failed in $folder ($LASTEXITCODE)" }
}

# 7. Verify no template tokens, markers, or removed admin references remain
$patterns = @('(?i)repo[- ]?template', 'template:\w+:(start|end)')
if ($NoAdmin) { $patterns += [regex]::Escape("$dotNet.Admin"), [regex]::Escape($moduleKey) }

$leftovers = Get-TemplateFiles | ForEach-Object {
    if ((Split-Path $_ -Leaf) -match '(?i)repo[- ]?template') { "$_ (path)" }
    # Case-sensitive: lock files keep the lowercase admin project name until the next restore
    Select-String -LiteralPath $_ -Pattern $patterns -CaseSensitive | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
}

Write-Host ''
Write-Names
Write-Host "Ports:         app $appPort$(if (-not $NoAdmin) { ", admin client $clientPort" })"

if ($leftovers) {
    Write-Host ''
    Write-Host 'Template tokens, markers, or admin references remain:' -ForegroundColor Red
    $leftovers | ForEach-Object { Write-Host "  $_" }
    exit 1
}
