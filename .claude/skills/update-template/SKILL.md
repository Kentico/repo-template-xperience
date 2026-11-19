---
name: update-template
description: Check the Kentico repository template this repository was created from for newer releases, decide which changes fit this project, and adopt them - CI and Dependabot configuration, agent skills, repository rulesets, docs, Playwright tooling, lint and editor settings, SDK and Node.js minimums. Use every month or two, or when asked to update from, sync with, or check the template.
---

Brings changes from newer releases of the template (`Kentico/repo-template-xperience`) into this repository. `.config/template.json` records the last template commit and release adopted, the setup choices, and changes skipped on purpose. You decide per change whether it fits this project; most releases touch only a few files. Each step ends on its completion criterion; move on only when it holds.

## 1. Check the starting state

- `git remote get-url origin` does not point at `Kentico/repo-template-xperience` (the template itself), and `Kentico.Xperience.RepoTemplate.slnx` does not exist (an unset-up repository runs `setup-repo` instead).
- `git status --short` is empty. If not, stop and ask the user how to proceed.
- `gh auth status` succeeds.
- Create a branch `template-update` from the default branch, unless the user names another.

Done when all hold.

## 2. Read the manifest

Read `.config/template.json`:

- `template`: the template repository
- `commit`, `version`: the last template commit and release adopted (both `null` until the first update)
- `setup`: the `setup-repo` choices (family, name, display name, example, admin, GitHub owner, repository slug, author)
- `skipped`: changes not adopted, each with its release and reason

If the file is missing (the repository predates it), create it in that shape. Fill `setup` from the repository: the solution name gives family and name (`Kentico.Xperience.<Name>`: Kentico, `Kentico.Xperience.Labs.<Name>`: Labs, `XperienceCommunity.<Name>`: Community), a `src/*.Admin` project means `noAdmin: false`, `<IsPackable>false</IsPackable>` in `Directory.Build.props` means `example: true`, and `git remote get-url origin` gives owner and slug. Done when the manifest exists with `setup` filled.

## 3. Fetch the template

Clone it outside the repository, without file contents until needed:

```powershell
$tmpl = Join-Path ([IO.Path]::GetTempPath()) "template-$(Get-Random)"
git clone --bare --filter=blob:none https://github.com/Kentico/repo-template-xperience.git $tmpl
```

Run every later template command as `git -C $tmpl ...`. Done when `git -C $tmpl tag` runs.

## 4. Find the baseline

The baseline is the template commit this repository matches:

1. `commit` from the manifest, if set.
2. Otherwise the template commit whose tree equals this repository's first commit's tree. GitHub creates a repository from a template as one commit with the template's files:
   `git rev-parse "$(git rev-list --max-parents=0 HEAD)^{tree}"`, then find that tree in `git -C $tmpl log --format="%H %T" main`.
3. Otherwise the last template `main` commit before this repository's first commit date. Tell the user the baseline is approximate.

Done when the baseline commit is known.

## 5. List newer releases

Newer releases are the template's `v*` tags whose commit is not an ancestor of the baseline (`git -C $tmpl merge-base --is-ancestor <tag> <baseline>` fails), oldest first. Read each one's notes with `gh release view <tag> --repo Kentico/repo-template-xperience`.

If there are none, report that the repository is up to date, delete the branch, and stop. Done when the list and notes are read.

## 6. Update this skill first

If `git -C $tmpl diff --stat <baseline> <latest tag> -- .claude/skills/update-template` lists changes, replace `.claude/skills/update-template` with the latest tag's version, then read the new `SKILL.md` and continue from its step 5:

```powershell
$zip = Join-Path $tmpl 'skill.zip'
git -C $tmpl archive --output $zip <latest tag> .claude/skills/update-template
Remove-Item .claude/skills/update-template -Recurse -Force
Expand-Archive $zip -DestinationPath .
```

Done when this skill matches the latest tag.

## 7. Review each release

For each release, oldest first:

1. List the pull requests in its notes. For each, read `gh pr view <number> --repo Kentico/repo-template-xperience --json title,body,files`. Its **Downstream** section says who should adopt it, why, and the follow-up steps.
2. Read the change: `git -C $tmpl diff <previous tag or baseline> <tag> -- <files>`.
3. Decide per change, and note the reason:
   - **adopt**: it fits as is
   - **adapt**: it fits, but this repository's names or local changes need a different form
   - **skip**: not relevant, or already done here

Skip unless the release notes or the Downstream section say otherwise:

- template-only files: `.github/workflows/template-smoke.yml`, the `setup-repo` skill, the `---Template info---` part of `README.md`, `template:upstream` blocks, the template repository's own `.config/template.json` values
- package versions (`Directory.Packages.props`, lock files, `package.json` dependencies): Dependabot handles them
- `examples/DancingGoat` changes from an Xperience update: the `update-xperience` skill owns them
- naming convention changes and folder moves
- changes for parts this repository lacks: `.Admin` project when `setup.noAdmin`, `.azuredevops/` for Community or examples, `publish.yml` for Kentico, Labs, or examples, packaging for examples
- items in `skipped`, unless the project changed so that the reason no longer holds

Weigh the rest against this project: what it builds, what it changed on purpose (see its git history for the files), and whether the change fixes a problem it has. Recommended changes, security fixes, and SDK or Node.js minimum raises are adopted unless something here conflicts.

Done when every change in every newer release has a decision and a reason.

## 8. Apply

Apply the adopt and adapt decisions:

- Template names map to this repository's names. The ordered token list is in `.claude/skills/setup-repo/scripts/Rename-Template.ps1` at the tag (`git -C $tmpl show <tag>:<path>`); the values come from `setup`. For example, `Kentico.Xperience.RepoTemplate` becomes the repository's .NET name, and `Kentico/xperience-by-kentico-repotemplate` becomes `<gitHubOrg>/<repoSlug>`.
- Template-marked blocks (`template:<tag>:start` / `end`) are kept or dropped by the same choices as in `setup-repo`; their marker lines never land here.
- Small diffs: edit the files by hand. Larger ones: replace the tokens in the diff, then `git apply --3way`.
- Keep this repository's own content (project-specific docs text, `references/dancinggoat-overlay.md`, customized skills) and bring in only the template's change around it.
- New files (a new skill, a new script) are copied with tokens replaced.

Then do each adopted change's follow-up steps, and the checks in `AGENTS.md` ("Development") for what changed: `dotnet restore --force-evaluate` after `global.json` or project changes, `dotnet format`, npm format, lint, and typecheck, build and test, screenshots when screenshot tooling or captured UI changed.

Done when every adopted change is applied and the checks pass. On a failure you can't fix, revert that change, record it as skipped with the reason, and tell the user.

## 9. Update the manifest

In `.config/template.json`:

- `version`: the latest release reviewed
- `commit`: that release's commit (`git -C $tmpl rev-list -n 1 <tag>`)
- `skipped`: add each skip whose reason is a choice for this project (not "template-only" or "package version"), as `{ "release", "change", "reason" }`; remove entries adopted now

Delete the template clone. Done when the manifest is updated and the clone is gone.

## 10. Report

List, per release: each change, the decision, and the reason. Then the steps that need a repository admin or maintainer (repository settings, imported rulesets, secrets, `./scripts/Test-RepositorySettings.ps1`).

Leave the changes uncommitted; commit only when the user approves, then open the pull request with the `create-pull-request` skill. Done when the report is given.
