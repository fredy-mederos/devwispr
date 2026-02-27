# Release DevWispr

Execute the full release pipeline for DevWispr. Follow these steps exactly in order:

## Step 1: Detect version changes

1. Read the current `MARKETING_VERSION` from `DevWispr.xcodeproj/project.pbxproj` (the app target entries at lines ~461 and ~503, NOT the test target ones).
2. Get the latest git tag with `git tag --sort=-v:refname | head -1`.
3. Compare the current version to the latest tag (strip `v` prefix from tag).
   - If the version in the project **differs** from the latest tag → use that version as the release version.
   - If the version **matches** the latest tag → bump the **minor** version (e.g., `1.1.0` → `1.2.0`) and update BOTH `MARKETING_VERSION` entries for the app target in `project.pbxproj`.

## Step 2: Confirm with user

Ask the user to confirm the release version using `AskUserQuestion`. Show the version number and ask them to confirm or provide a different version. If the user provides a different version, update the `MARKETING_VERSION` entries accordingly.

## Step 3: Build, sign, notarize

Run the release script:

```bash
APP_SIGN_IDENTITY="Developer ID Application: Fredy Mederos (R72WZKM2MR)" \
  NOTARY_KEYCHAIN_PROFILE="wispr-notary" bash scripts/release.sh
```

This will build, sign, create DMG, notarize, and staple. Wait for it to complete. If it fails, show the error and stop.

## Step 4: Commit version bump and tag

Only if the version was bumped in Step 1 (i.e., the pbxproj was modified):

1. Stage the `project.pbxproj` file: `git add DevWispr.xcodeproj/project.pbxproj`
2. Commit with message: `Bump version to X.Y.Z`
3. Push the commit.

Then create and push a git tag:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

## Step 5: Create GitHub release

Create a GitHub release with the DMG attached:

```bash
gh release create vX.Y.Z build/DevWispr.dmg \
  --title "DevWispr vX.Y.Z" \
  --generate-notes
```

Show the release URL to the user when done.
