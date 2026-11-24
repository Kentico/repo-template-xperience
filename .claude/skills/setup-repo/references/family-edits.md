# Family edits

`Rename-Template.ps1` makes the edits under "Done by the script" from `-Family`, `-Example`, `-GitHubOrg`, and `-Author`. The edits under "By hand" are yours, after the script succeeds. Where a family row and the Example row conflict, the Example row wins.

## Done by the script

### Publishing

| Family | Kept | Deleted |
| --- | --- | --- |
| Kentico, Labs | `.azuredevops/`, `Directory.Build.targets` (code signing), `azuresigntool` in `.config/dotnet-tools.json` | `.github/workflows/publish.yml` |
| Community | `.github/workflows/publish.yml` | `.azuredevops/`, `Directory.Build.targets`, `azuresigntool` entry |
| Example (any family) | – | `.azuredevops/`, `Directory.Build.targets`, `azuresigntool` entry, `.github/workflows/publish.yml`, `src/*.Libs.slnx` |

Blocks marked `template:azure:start` / `template:azure:end` go with `.azuredevops/` (VS Code file association and extension, the `publish.yml` header line).

Example: `<IsPackable>false</IsPackable>` is added to the root `Directory.Build.props`, and the blocks marked `template:package:start` / `template:package:end` are removed (package metadata, the `logo.png` / `README.md` pack items, symbol package settings).

### Ownership

| Family | `Directory.Build.props` `Company` / `Authors` | `LICENSE.md` holder | `.github/CODEOWNERS` |
| --- | --- | --- | --- |
| Kentico, Labs | kept (`Kentico Software`) | kept | kept |
| Community | `-Author`; `Trademark` removed | `-Author` | `* @<GitHubOrg>` |

## By hand

### Ownership

- Kentico, Labs: ask which Kentico team owns the repository and set it in `.github/CODEOWNERS`; keep the existing owner only when the user confirms it.
- Community: ask the author for a package icon to replace `images/logo.png`; keep the Kentico logo only if they accept it.

### README support

| Family | Badge | Support section |
| --- | --- | --- |
| Kentico | 7-day bug-fix badge only | "Full support by 7-day bug-fix policy" + `SUPPORT.md#full-support` link |
| Labs | Kentico Labs badge only | "Kentico Labs limited support" + `SUPPORT.md#labs-limited-support` link |
| Community | none | community-maintained statement; issues on this repository; drop Kentico `SUPPORT.md` / `SECURITY.md` links |

Example (any family): the family's badge and support text apply. Describe the repository as example source code. Replace "Package Installation", "Quick Start", and the version matrix with a `## Running the Example` section (create the database per `docs/Contributing-Setup.md`, then `dotnet run --project examples/DancingGoat`, and the app URL from `launchSettings.json`). "Dependencies" lists what is needed to run it.

Community: point "Contributing" at `docs/Contributing-Setup.md` and this repository's issues instead of Kentico's `CONTRIBUTING.md` / `CODE_OF_CONDUCT`.

Keep the CI badge for every family.

### Releasing

`docs/Contributing-Setup.md` "Releasing": keep the publish pipeline list for the family (Azure DevOps for Kentico and Labs, GitHub Actions for Community) and delete the other. Example: delete the whole section.

Community: tell the maintainer to create a nuget.org Trusted Publishing policy for the repository and `publish.yml`, and set the `NUGET_USER` repository variable.

### Object type names

`docs/Contributing-Setup.md` "Custom object types" → "Names": keep the family's table row, delete the other rows and the `Setup:` comment above the table. The text below the table, the generator command, and the `-Include` default in `scripts/Update-ObjectTypeClasses.ps1` use the Kentico class namespace (`Kentico<Name>` after the rename); for Labs replace it with `KenticoLabs<Name>`, for Community with `XperienceCommunity<Name>`.
