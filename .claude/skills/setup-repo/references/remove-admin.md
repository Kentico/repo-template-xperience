# Remove the `.Admin` project

Only when the project has no admin UI extensions. `Rename-Template.ps1 -NoAdmin` does the removal; `<Admin>` is the renamed `.Admin` project.

## Done by the script

- `src/<Admin>/` folder, and its entry in the root `.slnx` and `src/*.Libs.slnx`
- `examples/DancingGoat/DancingGoat.csproj`: the `<Admin>` `ProjectReference`
- `examples/DancingGoat/appsettings.Development.json`: the `CMSAdminClientModuleSettings` section
- `.vscode/tasks.json`: every `npm` task
- `tests/e2e/admin/custom-template.spec.ts`, `tests/e2e/admin/customTemplatePage.ts`, and `tests/e2e/screenshots/admin.screenshots.ts` (the sample admin page they test and capture is gone); the rest of `tests/e2e/admin` stays – admin sign-in and shell tests still apply to libraries without admin UI pages
- README install command: the core package instead of `.Admin`
- every block marked `template:admin:start` / `template:admin:end`:
  - `.github/workflows/ci.yml`: the `build_and_test` `Check admin client` step and the npm build comments
  - `.github/workflows/publish.yml` and `.azuredevops/pipelines/build-and-release.yml` (when present): the Node.js steps and the `Admin` artifact
  - `.github/dependabot.yml`: the admin client `npm` entry
  - `examples/AppHost/AppHost.cs`: the `admin-client` resource
  - `.gitignore`: the `**/Client/dist/*` line
  - `.github/PULL_REQUEST_TEMPLATE.md`: the `### Admin UI / Client` section
  - `AGENTS.md`: the admin client lint and format line
  - `docs/Contributing-Setup.md`: the admin `Client/package.json` reference and the admin client lint item (Node.js itself stays: `tests/e2e` needs it)
  - `tests/e2e/README.md`: the Proxy-mode `npm start` requirement

`Kentico.Xperience.Admin` stays in the root `Directory.Packages.props`: DancingGoat still references it, and `examples/Directory.Packages.props` only overrides its version.

## By hand

- `AGENTS.md` `## Repository`: drop the `.Admin` project from the layout list
- `README.md` and `docs/`: any remaining admin UI wording
- `.claude/skills/setup-local/SKILL.md` and `.claude/skills/update-xperience/SKILL.md`: the `src/*/Client` steps (npm install, typecheck, `npm start`)

Done when `git grep --untracked -n -e "<.NET name>.Admin" -e "<admin module key>" -e "src/\*/Client" -- ":!.claude/skills/setup-repo" ":!*packages.lock.json"` finds nothing.
