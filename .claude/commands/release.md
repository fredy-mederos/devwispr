# Release DevWispr

Execute the full release pipeline for DevWispr. Follow these steps exactly in order:

## Step 1: Commit pending changes

1. Run `git status` and `git diff` to check for uncommitted changes.
2. If there are staged or unstaged changes, commit them with an appropriate message and push.
3. If there are no changes, skip this step.

## Step 2: Detect version changes

1. Read the current `MARKETING_VERSION` from `DevWispr.xcodeproj/project.pbxproj` (the app target entries at lines ~461 and ~503, NOT the test target ones).
2. Get the latest git tag with `git tag --sort=-v:refname | head -1`.
3. Compare the current version to the latest tag (strip `v` prefix from tag).
   - If the version in the project **differs** from the latest tag → use that version as the release version.
   - If the version **matches** the latest tag → bump the **minor** version (e.g., `1.1.0` → `1.2.0`) and update BOTH `MARKETING_VERSION` entries for the app target in `project.pbxproj`.

## Step 3: Confirm with user

Ask the user to confirm the release version using `AskUserQuestion`. Show the version number and ask them to confirm or provide a different version. If the user provides a different version, update the `MARKETING_VERSION` entries accordingly.

## Step 4: Build, sign, notarize

Run the release script:

```bash
APP_SIGN_IDENTITY="Developer ID Application: Fredy Mederos (R72WZKM2MR)" \
  NOTARY_KEYCHAIN_PROFILE="wispr-notary" bash scripts/release.sh
```

This will build, sign, create DMG, notarize, and staple. Wait for it to complete. If it fails, show the error and stop.

## Step 5: Commit version bump and tag

Only if the version was bumped in Step 2 (i.e., the pbxproj was modified):

1. Stage the `project.pbxproj` file: `git add DevWispr.xcodeproj/project.pbxproj`
2. Commit with message: `Bump version to X.Y.Z`
3. Push the commit.

Then create and push a git tag:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

## Step 6: Create GitHub release

Create a GitHub release with the DMG attached. Include the app icon in the release body before the auto-generated notes:

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

This places the icon at the top of the release notes, followed by a separator and the auto-generated changelog.

Show the release URL to the user when done.
