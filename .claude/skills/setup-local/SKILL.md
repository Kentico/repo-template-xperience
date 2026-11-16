---
name: setup-local
description: Set up a local development environment for this repository - SQL Server, the DancingGoat database with an Xperience license, user secrets, npm packages, and Playwright browsers. Use after cloning the repository, or when a developer needs a new local database.
---

Each step ends on its completion criterion. Run from the repository root.

## 1. Check prerequisites

- .NET SDK matching `global.json` (`dotnet --version`)
- Node.js matching `engines` in `tests/e2e/package.json` (`node --version`)
- SQL Server: ask the user whether to use Docker or a locally installed SQL Server.
  - Docker: if nothing listens on port 1433, start one matching the default connection string in `examples/DancingGoat/appsettings.json`:
    `docker run -d --name xperience-sql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD=Pass@12345 -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest`
  - Local install: get its server name (e.g. `localhost\SQLEXPRESS`) and whether it uses Windows authentication.
- Mailpit, shared by every project on the machine: if nothing listens on port 1025, start one:
  `docker run -d --name mailpit --restart unless-stopped -p 1025:1025 -p 8025:8025 axllent/mailpit`

Done when both versions match, the SQL Server accepts connections, and <http://localhost:8025> responds.

## 2. Get the license

Ask the user for the path to their Xperience license file, or check `XPERIENCE_LICENSE_FILE`. Treat the file as a credential: pass its path, never read, print, or copy its contents. Without a license the database is still created, but the live site returns errors and the administration hides custom applications until the license is added at first sign-in. Done when you have a path that exists, or the user chose to continue without one.

## 3. Install dependencies and build

1. `dotnet tool restore` and `dotnet restore`
2. `npm ci` in each `src/*/Client` folder and in `tests/e2e`
3. `npm run install:browsers` in `tests/e2e`
4. `dotnet build`

Done when all four exit 0. The database step runs DancingGoat's Xperience CLI from this build.

## 4. Create the database

Run `./scripts/Initialize-Database.ps1 -LicenseFile <path>`, adding `-ServerName <server>` and `-Username ""` for a local Windows-authentication SQL Server. Add `-Recreate` only after the user confirms dropping an existing database of the same name. The script:

- creates the database with `kentico-xperience-dbmanager`, signing macros with the shared `CMSHashStringSalt` committed in `examples/DancingGoat/appsettings.json`
- moves the connection string into DancingGoat's user secrets, leaving `appsettings.json` unchanged
- restores the committed Xperience Continuous Integration repository (`examples/DancingGoat/App_Data/CIRepository`) and enables Continuous Integration, so the database matches the repository and later changes are written back to it

Done when the script exits 0 and `git status --short` is empty: neither `appsettings.json` nor the CI repository changed.

## 5. Offer Aspire

If the `aspire` CLI is installed (`aspire --version`), tell the user `aspire run` starts DancingGoat and the admin client dev server together, using the database from step 4 and the Mailpit from step 1. Mention that `aspire agent init` installs Aspire's agent skills but also adds Aspire telemetry hooks to their global agent settings unless `ASPIRE_CLI_TELEMETRY_OPTOUT=true` is set; run it only if the user asks. Done when the user has been told.

## 6. Verify

1. `dotnet run --project examples/DancingGoat --no-build -- --kxp-db-status --format json`: `state` is `Ready`. For any other state, follow its `message`.
2. `dotnet run --project examples/DancingGoat --no-build -- --kxp-ci-status --format json`: `enabled` is `true`. If not (an existing database), run `--kxp-ci-restore`, then `--kxp-ci-enable`, the same way.
3. `git status --short examples/DancingGoat/App_Data` is empty.

Done when all three hold.

## 7. Start the site

Start the site in the background (`aspire run`, or `dotnet run --project examples/DancingGoat`) and wait until `<applicationUrl>/admin` responds (`applicationUrl` in `examples/DancingGoat/Properties/launchSettings.json`). The `xperience-management-mcp` server only connects while the site is running: if its tools are missing or its connection failed when the session started, reconnect it now (Claude Code: `/mcp`; otherwise ask the user to reconnect it or restart the agent session). Done when `/admin` responds and the MCP server lists its tools.

The channel domains come from the CI repository (`localhost:<port>`), so emails link to the local site without further setup.

## 8. Report

Tell the user:

- the site URL (`applicationUrl` in `examples/DancingGoat/Properties/launchSettings.json`) and the administration at `<url>/admin`, user `administrator`, password `Pass@12345` (the repository's password, from the CI repository)
- whether the license was installed
- Continuous Integration is on: changes to objects and content in the administration are written to `examples/DancingGoat/App_Data/CIRepository`; commit the ones that belong with the code change, revert the rest with `git restore` followed by `--kxp-ci-restore`
- how to work on the admin client: `aspire run`, or `npm start` in `src/*/Client` (Proxy mode) alongside `dotnet run --project examples/DancingGoat`
- how to run e2e tests: `tests/e2e/README.md`
