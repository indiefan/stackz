# Releasing Stackz

A release is a universal build signed with a Developer ID certificate, notarized by Apple, and published on GitHub next to an appcast. Installed copies read that appcast to find updates. `release.sh` does all of it.

## How updates reach people

- Release builds look for updates at `https://github.com/indiefan/stackz/releases/latest/download/appcast.xml`. Every release uploads its own `appcast.xml` describing itself, and GitHub's `latest` redirect makes the newest one the feed. No other server is involved.
- Drafts and pre-releases are never `latest`, so they don't reach anyone.
- [Sparkle](https://sparkle-project.org) checks every download against the update-signing key and the app's Developer ID signature before it installs anything.
- Builds made with a plain `./build.sh` have no feed URL, so they have no updater.

## One-time setup

1. **Developer ID Application certificate.** This needs a paid Apple Developer Program membership, and only the account holder can create one. In Xcode: Settings → Accounts → your team → Manage Certificates → **+** → Developer ID Application. Confirm it is installed:

   ```bash
   security find-identity -v -p codesigning
   ```

   The list should include `Developer ID Application: Your Name (TEAMID)`.

2. **Tell the installer which team to trust.** Put that ten-character team ID into `TEAM_ID=""` in `install.sh` and commit it. Until then the installer always builds from source, and `release.sh` refuses to publish.

3. **Notarization credentials.** Create an app-specific password at [account.apple.com](https://account.apple.com) (Sign-In and Security → App-Specific Passwords), then store it in your keychain. The command asks for the password:

   ```bash
   xcrun notarytool store-credentials stackz-notary --apple-id you@example.com --team-id TEAMID
   ```

4. **Update-signing key.** This already exists. The private half is in the login keychain of the Mac it was generated on, as "Private key for signing Sparkle updates". The public half is `PUBLIC_ED_KEY` in `build.sh`. Back the private key up somewhere safe, such as a password manager, and delete the exported file afterwards:

   ```bash
   .build/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle-private-key.txt
   ```

   Treat it like a password: together with write access to this repository's releases, it is enough to ship an update to every installed copy. The first time `release.sh` signs an appcast, macOS asks whether `generate_appcast` may read the key. Choose Always Allow.

5. **GitHub CLI.** `release.sh` publishes with `gh`, so run `gh auth login` once.

## Cutting a release

1. Raise the number in `VERSION`. It must be three numbers separated by dots and higher than the last release, because Sparkle compares it to decide what is newer.
2. Commit and push.
3. Run:

   ```bash
   ./release.sh
   ```

   It builds for arm64 and x86_64, signs, waits for Apple to notarize the build (usually a few minutes), staples the ticket, zips the app, writes the appcast, and creates the GitHub release `v<VERSION>` with `Stackz.zip` and `appcast.xml` attached.

Installed copies pick the release up within a day, or immediately through Check for Updates… in the menu bar menu.

To rehearse without notarizing or publishing anything:

```bash
./release.sh --dry-run
```

With the certificate installed, the rehearsal leaves a fully signed `Stackz.app` in the repository folder. Open it before your first release and confirm that Check for Updates… appears in the menu bar menu.

Add `CODESIGN_IDENTITY=-` in front to rehearse on a Mac without the certificate. The result lands in `dist/` and cannot be shipped.

## Releasing from GitHub Actions instead

Pushing a tag that matches `VERSION`, such as `v1.2.3`, runs [the release workflow](.github/workflows/release.yml), which calls the same script. It needs these repository secrets:

| Secret | Contents |
|--------|----------|
| `DEVELOPER_ID_P12_BASE64` | The certificate and its private key, exported from Keychain Access as a `.p12` and base64-encoded |
| `DEVELOPER_ID_P12_PASSWORD` | The password you set on that export |
| `NOTARY_KEY_P8_BASE64` | An App Store Connect API key (`.p8`), base64-encoded |
| `NOTARY_KEY_ID` | That key's ID |
| `NOTARY_ISSUER_ID` | Its issuer ID |
| `SPARKLE_PRIVATE_KEY` | The contents of the file `generate_keys -x` writes |

This is more convenient and it puts your signing keys in GitHub. Releasing from your Mac keeps them in your keychain.

## Testing an update

Once a second release exists, install the older one and force a check on next launch:

```bash
defaults delete io.github.indiefan.stackz SULastCheckTime
```

Sparkle writes what it does to Console.app, which is the first place to look when an update is not offered.
