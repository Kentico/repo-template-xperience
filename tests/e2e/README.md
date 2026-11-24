# End-to-end tests

Playwright (TypeScript) tests against a running DancingGoat site: the live site and the Xperience administration, including this repository's admin extensions.

## Projects

| Project | Files | Purpose |
| --- | --- | --- |
| `live-site` | `live-site/*.spec.ts` | public site behavior (widgets, sections, pages) |
| `admin-setup` | `admin/auth.setup.ts` | signs in once and saves the session to `playwright/.auth/` |
| `admin-tests` | `admin/*.spec.ts` | administration behavior, starting signed in |

Page objects (`admin/*Page.ts`) hold selectors for UI this repository does not own, so an Xperience update that changes markup is fixed in one place.

Tests have a three-minute timeout so administration readiness and sign-in waits can finish before the remaining steps. Screenshot tests have a separate ten-minute timeout.

## Requirements

- A DancingGoat database with an Xperience **license**: `./scripts/Initialize-Database.ps1 -LicenseFile <path>` (see `docs/Contributing-Setup.md`). Without a license the live site returns 500 and the administration hides custom applications.
<!-- template:admin:start -->
- In the Development environment the admin client runs in Proxy mode: start `npm start` in `src/Kentico.Xperience.RepoTemplate.Admin/Client` first, or run everything with `aspire run` (see `docs/Contributing-Setup.md`).
<!-- template:admin:end -->

## Run

```powershell
cd tests/e2e
npm ci
npm run install:browsers
npm test            # all projects; starts DancingGoat unless it is already running
npm run test:admin  # admin-tests only
npm run report      # open the last HTML report
```

Before a commit: `npm run format`, `npm run lint`, `npm run typecheck`. CI runs them on every PR, license or not.

## README screenshots

`npm run screenshots` saves the README's screenshots to `images/screenshots/<name>.png` (`screenshots.config.ts`). Run it before a PR that changes UI, review the images, and commit them; it is not part of `npm test` or CI.

- Each `screenshots/*.screenshots.ts` drives the UI (with the tests' page objects) to the state to show, waits for it with `expect`, and calls `capture(page, name, options)` from `shared/screenshot.ts`. Admin captures start signed in.
- `capture` uses a fixed 1440×900 light view with reduced motion, so content that animates in on scroll is shown at once. In the administration it cuts off the license banner and handles its inner scroll area. Options: `fullHeight` (full page, up to a height), `cropHeight`, `element` (one element).
- Content the captures need belongs in the CI repository, so every database has it. Captures that create data (imports, submissions) should run against a database you can throw away.
- Link the images from `README.md` or `docs/` with relative paths: `![Imports list](./images/screenshots/imports-list.png)`.

## CI

The `e2e` job in `.github/workflows/ci.yml` runs SQL Server and Mailpit service containers, builds in Release, creates the database with `scripts/Initialize-Database.ps1` (restoring the committed CI repository) (admin client embedded, no Proxy mode), and runs DancingGoat with `ASPNETCORE_ENVIRONMENT=CI` (`examples/DancingGoat/appsettings.CI.json`). It needs the license key in the `XPERIENCE_LICENSE_KEY` secret – as a repository secret, and as a Dependabot secret for Dependabot PRs. Without it the job's steps are skipped, as for PRs from forks. The HTML report is uploaded as the `playwright-report` artifact.

## Configuration

| Variable | Default |
| --- | --- |
| `DANCING_GOAT_BASE_URL` | `applicationUrl` of the `DancingGoat` profile in `examples/DancingGoat/Properties/launchSettings.json` |
| `ADMIN_BASE_URL` | `<base URL>/admin` |
| `E2E_WEB_SERVER_COMMAND` | `dotnet run --project examples/DancingGoat` |
| `E2E_WEB_SERVER_TIMEOUT_MS` | `180000` |
