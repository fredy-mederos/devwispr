---
name: release-devwispr
description: "Execute the DevWispr release workflow end-to-end: validate repository state, resolve MARKETING_VERSION and tag strategy, build/sign/notarize the DMG, push release tags, and publish a GitHub release. Use when asked to release DevWispr, cut a new version, publish a DMG, or run the release script with version/tag coordination."
---

# Release DevWispr

## Overview

Run this workflow exactly in order for DevWispr releases.

## Workflow

1. Check pending changes.
- Run `git status` and `git diff`.
- If there are staged or unstaged changes, commit with an appropriate message and push.
- If there are no changes, continue.

2. Resolve release version.
- Read `MARKETING_VERSION` from `DevWispr.xcodeproj/project.pbxproj` for the app target entries (not test target entries).
- Get latest tag with `git tag --sort=-v:refname | head -1`.
- Compare project version against latest tag without leading `v`.
- If project version differs from latest tag, use project version.
- If project version matches latest tag, bump minor version (`X.Y.Z` -> `X.(Y+1).0`) and update both app-target `MARKETING_VERSION` entries in `project.pbxproj`.

3. Confirm version with user.
- Ask user to confirm the release version.
- If user provides a different version, update both app-target `MARKETING_VERSION` entries to that value.

4. Build, sign, notarize, staple.
- Run:
```bash
APP_SIGN_IDENTITY="Developer ID Application: Fredy Mederos (R72WZKM2MR)" \
  NOTARY_KEYCHAIN_PROFILE="wispr-notary" bash scripts/release.sh
```
- If command fails, stop and report the error.

5. Commit version bump when applicable.
- Only if `project.pbxproj` was modified for version bumping:
- Run `git add DevWispr.xcodeproj/project.pbxproj`.
- Commit with `Bump version to X.Y.Z`.
- Push commit.

6. Create and push tag.
- Run `git tag vX.Y.Z`.
- Run `git push origin vX.Y.Z`.

7. Create GitHub release.
- Run:
```bash
gh release create vX.Y.Z build/DevWispr.dmg \
  --title "DevWispr vX.Y.Z" \
  --notes "$(cat <<'EOF'
<p align="center">
  <img src="https://raw.githubusercontent.com/fredy-mederos/devwispr/main/screenshots/icon.png" width="80" alt="DevWispr icon" />
</p>

---

EOF
)

$(gh api repos/fredy-mederos/devwispr/releases/generate-notes -f tag_name=vX.Y.Z --jq .body)"
```
- Share the release URL at completion.

## Guardrails

- Keep app-target version entries in sync.
- Do not tag or publish if build/sign/notarization fails.
- Stop and ask for confirmation before using a version different from resolved/default value.
