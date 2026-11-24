# Contributing Setup

---This documents the steps a maintainer or developer would follow to work on the library in their development environment---

## Required Software

The requirements to setup, develop, and build this project are listed below.

### .NET Runtime

The exact .NET SDK version in `global.json`

- <https://dotnet.microsoft.com/en-us/download/dotnet/10.0>
- The version is pinned (`rollForward: disable`) because the committed NuGet lock files depend on it. To move to a newer SDK, change `global.json` and run `dotnet restore --force-evaluate`, then commit both.
- Central package transitive pinning is enabled only for `examples/` and `tests/`, so security pins apply to projects run here without adding transitive dependencies to published libraries in `src/`. Their lock files still record the resolved dependencies.

### Node.js Runtime

- [Node.js](https://nodejs.org/en/download) LTS or newer
- [NVM for Windows](https://github.com/coreybutler/nvm-windows) or [NVM for macOS](https://github.com/nvm-sh/nvm) to manage multiple installed versions of Node.js
<!-- template:admin:start -->
- See `engines` in `src/Kentico.Xperience.RepoTemplate.Admin/Client/package.json` for specific version requirements
<!-- template:admin:end -->

### GitHub CLI

- [GitHub CLI](https://cli.github.com/), authenticated with access to the repository; used by repository checks and the `create-pull-request` and `update-template` skills

#### Minimum package age

Each npm folder's `.npmrc` sets `min-release-age=3`: npm resolves only versions published at least 3 days ago, so a compromised or broken release is usually caught and pulled first. Dependabot version updates wait the same 3 days (`cooldown` in `.github/dependabot.yml`).

Dependabot security updates skip both, so a merged security fix can lock a version newer than 3 days. `npm ci` and `npm install` still work. `npm update`, or an install that re-resolves that package, fails with `notarget`. Wait until the version is 3 days old, or add the package to `min-release-age-exclude` in that `.npmrc` and remove it again once it is.

### Database

SQL Server 2019 or newer compatible database

- [SQL Server Linux](https://learn.microsoft.com/en-us/sql/linux/install-upgrade/setup?view=sql-server-ver15)

### Email

[Mailpit](https://mailpit.axllent.org) catches DancingGoat's emails on `localhost:1025` (SMTP), with the inbox at <http://localhost:8025>. One container serves every project on the machine:

```powershell
docker run -d --name mailpit --restart unless-stopped -p 1025:1025 -p 8025:8025 axllent/mailpit
```

## Sample Project

### Database Setup

Running the sample project requires an Xperience by Kentico database. AI agents can do the whole local setup (SQL Server, database, dependencies, verification) with the `setup-local` skill. To create the database by hand, run from the repository root:

```powershell
./scripts/Initialize-Database.ps1
```

- Server, database (`xperience-by-kentico-repotemplate`), and SQL login come from `ConnectionStrings` in `examples/DancingGoat/appsettings.json`. The default targets a Docker SQL Server on `localhost,1433` with the `sa` login; for a locally installed SQL Server pass `-ServerName` (and `-Username ""` for Windows authentication).
- The `administrator` account password is `Pass@12345`. It is the repository's password, chosen at repository setup: the CI repository commits its hash, and the e2e tests sign in with it.
- Pass `-LicenseFile <path>` (or set `XPERIENCE_LICENSE_FILE`) to install your Xperience license. Without it, add the license when you first sign in to the administration.
- `-Recreate` drops and recreates an existing database.
- DancingGoat must be built first (`dotnet build`): the script runs DancingGoat's Xperience CLI.
- The script runs [`kentico-xperience-dbmanager`](https://docs.kentico.com/documentation/developers-and-admins/installation#create-the-project-database), then moves the connection string it writes into DancingGoat user secrets and restores `examples/DancingGoat/appsettings.json`, so there is nothing to commit. `-SaveTo` changes this (`Salt`, `AppSettings`, `None`); see the script's help.
- Macros are signed with the `CMSHashStringSalt` committed in `appsettings.json`. Every machine shares it, so the CI repository's macro signatures stay valid; do not change it.
- The script then restores the [Continuous Integration](https://docs.kentico.com/documentation/developers-and-admins/ci-cd/continuous-integration) repository (below) and enables CI.

### Continuous Integration repository

`examples/DancingGoat/App_Data/CIRepository` holds DancingGoat's objects and content (content types, pages, email templates, channels, and anything the library adds) as XML files, committed with the code. With CI enabled, every change made in the administration is written there.

- Commit repository changes that belong with your code change. To discard others: `git restore` (and `git clean` for new files) in the folder, then `dotnet run --project examples/DancingGoat -- --kxp-ci-restore`.
- After pulling repository changes from others: `dotnet run --project examples/DancingGoat -- --kxp-ci-restore`.
- Settings keys are excluded (`repository.config`). Users are included: the `administrator` password is the repository's, and changing it locally changes the repository.
- The CI `e2e` job restores the repository into a new database and runs the tests against it.
- Windows: some paths are long; enable `git config --global core.longpaths true`.

### Run with Aspire

[Aspire](https://aspire.dev) starts everything together: DancingGoat and the admin client dev server (Proxy mode), with a link to the Mailpit inbox. Install the [Aspire CLI](https://aspire.dev/get-started/install-cli/), then from the repository root:

```powershell
aspire run
```

The dashboard links the live site and the administration. By default DancingGoat uses the database from `scripts/Initialize-Database.ps1`. To use a SQL Server container instead (Docker required; the database is created on first run), set `Sql:UseExistingServer` to `false` in `examples/AppHost` user secrets:

```powershell
dotnet user-secrets set "Sql:UseExistingServer" false --project examples/AppHost
```

Set `XPERIENCE_LICENSE_FILE` before `aspire run` to install the license into a new container database.

By default DancingGoat sends emails to the machine-wide Mailpit from [Email](#email), and the dashboard shows it as unhealthy when it isn't running. To start a Mailpit container for the run instead, set `Mail:UseExistingServer` to `false`:

```powershell
dotnet user-secrets set "Mail:UseExistingServer" false --project examples/AppHost
```

The root `.mcp.json` registers the Aspire MCP server (`aspire agent mcp`), so AI agents can list resources, read logs, and restart them. `aspire agent init` can also install Aspire's agent skills; note that it adds Aspire telemetry hooks to your global agent settings unless `ASPIRE_CLI_TELEMETRY_OPTOUT=true` is set.

### End-to-end tests

Playwright tests for the live site and the administration live in `tests/e2e`; they need a licensed database. See [`tests/e2e/README.md`](../tests/e2e/README.md).

## Custom object types

A library that stores data in custom [object types](https://docs.kentico.com/documentation/developers-and-admins/customization/object-types) ships their generated `*Info` classes. Sites that install it must not generate the same classes again: the copies would register the same object types a second time.

The code generator (`--kxp-codegen --type Classes`) skips every class whose **module** code name starts with `CMS` (any case, no dot needed), unless `CMSDevelopmentMode` is `true`. So:

- Put the library's classes in a module whose code name starts with `CMS.`. The library creates the module and classes in code (an installer that runs at startup).
- Class code names do not affect this filter. Never start them with `CMS`.
- A `CMS` module is a system module: read-only in the administration, and its classes are hidden outside development mode. Manage the data through the library's own UI or API.
- Keep the module code name once released: the installer finds the existing module by it.

### Names

<!-- Setup: keep only the row for this repository's family. -->

| Family | Module code name | Module display name | Class code names |
| --- | --- | --- | --- |
| Kentico | `CMS.Integration.RepoTemplate` | `Kentico Integration - Repo Template` | `KenticoRepoTemplate.<Entity>` |
| Labs | `CMS.Labs.RepoTemplate` | `Kentico Labs - Repo Template` | `KenticoLabsRepoTemplate.<Entity>` |
| Community | `CMS.XperienceCommunity.RepoTemplate` | `Xperience Community - Repo Template` | `XperienceCommunityRepoTemplate.<Entity>` |

The class code name sets the object type (the code name in lowercase) and the table (`KenticoRepoTemplate_<Entity>`). One class namespace per library keeps `--include` exact.

### Generate the library's classes

Stop DancingGoat first (`dotnet run` builds it), then from the repository root:

```powershell
./scripts/Update-ObjectTypeClasses.ps1
```

The script runs DancingGoat's code generator in development mode:

```powershell
dotnet run -- --kxp-codegen --type Classes --include "KenticoRepoTemplate.*" --namespace "Kentico.Xperience.RepoTemplate" --location "../../src/Kentico.Xperience.RepoTemplate/Classes/{name}" --with-provider-class False --skip-confirmation
```

- `--include`: required. Development mode turns off the filter for every system module, so without it the generator writes all Xperience system classes (about 150) to the library.
- `--namespace`: required. The default C# namespace is the module code name (`CMS.Integration.RepoTemplate`).
- `CMSDevelopmentMode` is set for the generator process only (environment variable). Do not add it to `appsettings*.json`: DancingGoat should run like a site that installed the library.
- `--with-provider-class False` (the default, stated explicitly): no dedicated `*InfoProvider` classes. Use the generic `IInfoProvider<TInfo>` ([database table API](https://docs.kentico.com/documentation/developers-and-admins/api/database-table-api#generic-provider-class-iinfoprovidertinfo)); customize it with `InfoProviderDecorator<TInfo>`, not a provider subclass.
- In development mode the generator writes classes and interfaces without `partial`; the script adds it back. Running the command by hand needs the same fix.
- Regenerating overwrites `*.generated.cs`. Put `TYPEINFO` changes in a partial class ([object type configuration](https://docs.kentico.com/documentation/developers-and-admins/customization/object-types/object-type-configuration#configure-object-types-in-a-partial-class)).

### DancingGoat's own classes

DancingGoat's content types, forms, and any object types it adds for itself are generated without development mode, into DancingGoat (see `examples/DancingGoat/AGENTS.md`), never into `src/`. Development mode does not change which content types or forms are generated. Object types for DancingGoat alone go in a module whose code name does not start with `CMS` (for example `DancingGoat.<Feature>`).

## Development Workflow

1. Create a new branch with one of the following prefixes
   - `feat/` - for new functionality
   - `refactor/` - for restructuring of existing features
   - `fix/` - for bugfixes

1. Run `dotnet format` against the `Kentico.Xperience.RepoTemplate` solution

   > use `dotnet: format` VS Code task.

1. If you changed TypeScript, run `npm run format`, `npm run lint`, and `npm run typecheck` in its folder (`npm run lint:fix` fixes what it can). CI fails on unformatted or failing code.
   - `tests/e2e`
<!-- template:admin:start -->
   - `src/Kentico.Xperience.RepoTemplate.Admin/Client` – or use the `npm: format - admin client` and `npm: lint - admin client` VS Code tasks
<!-- template:admin:end -->

1. Commit changes, with a commit message preferably following the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#summary) convention.

1. Once ready, create a PR on GitHub. The PR will need to have all comments resolved and all tests passing before it will be merged.
   - The PR should have a helpful description of the scope of changes being contributed.
   - Include screenshots or video to reflect UX or UI updates. When the UI shown in the README changes, update its screenshots with `npm run screenshots` in `tests/e2e` (see [README screenshots](../tests/e2e/README.md#readme-screenshots))
   - Indicate if new settings need to be applied when the changes are merged - locally or in other environments
   - Use the `create-pull-request` agent skill (`.claude/skills/create-pull-request/SKILL.md`, works with
     both Copilot and Claude) to push the branch and create or update the PR, with `.github/PULL_REQUEST_TEMPLATE.md`
     filled from git diff and CI evidence instead of writing the description by hand.

1. This repository uses `lf` line endings for text files. EditorConfig and Git enforce this on all platforms; no Git line-ending override is needed.

## Merging pull requests

For Kentico and Labs projects, use **Merge when ready** to add pull requests to the merge queue. The CI workflow runs for `merge_group` events, testing each queued pull request on top of `main` and the pull requests ahead of it. Community projects do not use the merge queue; the ruleset requires the CI checks before a pull request can be merged.

## Repository settings

Set once by a repository admin. Required for repositories in the Kentico organization; recommended for others. Check them with `./scripts/Test-RepositorySettings.ps1` (GitHub CLI authenticated as an admin; see Required Software); it exits 1 while one fails.

- `.github/CODEOWNERS` has a `* @<owner>` line, and GitHub resolves the owner (no errors under the file on GitHub)
- the owner team has the **Admin** role (**Settings** → **Collaborators and teams**)
- no outside collaborators added directly; access goes through teams
- **Settings** → **General** → **Automatically delete head branches**: on
- rulesets for `main`, imported from `.github/rulesets` (**Settings** → **Rules** → **Rulesets** → **New ruleset** → **Import a ruleset**):
  - All project types: `protect-main.json` blocks deleting `main` and force pushes, and sets pull-request requirements and allowed merge methods. Repository admins can bypass according to the policy below.
  - Kentico integrations: `protect-main.json` requires Code Owner approval, approval of the latest push, resolved review threads, and Copilot code review. `merge-queue.json` requires **Build and Test** and **E2E Tests** (branches need not be up to date) and the squash-only merge queue. Admin bypass is pull-request-only.
  - Labs: `protect-main.json` has no review or Copilot requirements and permits squash only. `merge-queue.json` requires the same CI checks and squash-only queue. Admins can bypass all rules.
  - Community: `protect-main.json` has no review or Copilot requirements, permits merge, squash, or rebase, and requires the same CI checks without a merge queue. Admins can bypass all rules.
- **Settings** → **Advanced Security**:
  - **Dependency graph**: on, with manifests found (**Insights** → **Dependency graph**)
  - **Dependabot alerts**: on, with the rule that dismisses low-impact alerts for development dependencies (**Dependabot auto-triage rules**)
  - **Dependabot security updates** and **Grouped security updates**: on

## Releasing

---Keep the steps for how this repository publishes: Azure DevOps (Kentico and Labs) or GitHub Actions (Community). Delete the other list, and this whole section for an example repository.---

The package version comes from `VersionPrefix` and `VersionSuffix` in `Directory.Build.props`. A release is that version, published from `main`.

1. Set `VersionPrefix` to the new version. For a pre-release, set `VersionSuffix` to `prerelease-1` and raise the number for each further pre-release of the same version.
1. Update the version matrix in `README.md` when the supported Xperience versions change.
1. Merge the change to `main` through a pull request.
1. Run the publish pipeline for `main` (below) and confirm the packages on nuget.org.
1. Test the pre-release in a real project. When it is good, remove the `VersionSuffix` value, merge, and run the publish pipeline again for the full release.

Publish pipeline, Kentico and Labs (Azure DevOps):

1. Run the `.azuredevops/pipelines/build-and-release.yml` pipeline for `main`. It builds, signs, packs, and after approval pushes the packages to nuget.org.
1. After a successful full release, create the GitHub release and tag `v<version>` on the released commit, with generated release notes.

Publish pipeline, Community (GitHub Actions):

1. Run the **Publish: NuGet** workflow for `main` (**Actions** > **Publish: NuGet** > **Run workflow**, or `gh workflow run publish.yml --ref main`). It builds, tests, packs, and pushes the packages to nuget.org, then creates the GitHub release and tag `v<version>` with generated release notes. A version with a suffix becomes a GitHub pre-release.
1. A version that is already on nuget.org fails the push: raise the version instead of rerunning.
