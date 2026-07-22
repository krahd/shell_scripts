# `ov`: open folders as Obsidian vaults with one shared profile

`ov` opens the current directory, or a supplied directory, as an Obsidian vault on macOS. If the folder is not already registered, it adds it to Obsidian's local vault registry. Before opening the vault, it applies the latest safe subset of a shared [Settings Profiles](https://github.com/4Source/settings-profiles-obsidian-plugin) profile.

The default canonical vault is:

```text
/Users/tom/obsidian/Tom_Main_Obsidian_Vault
```

Notes, attachments, and every other vault-content file remain independent. `ov` only manages selected files under each vault's `.obsidian` directory.

## Installation

From this repository:

```bash
./deploy.sh --apply
```

Add the repository's `bin` directory to `PATH`, if it is not there already:

```bash
export PATH="/path/to/shell_scripts/bin:$PATH"
```

Alternatively, install only `ov`:

```bash
install -m 0755 ./ov ~/.local/bin/ov
```

## Required Obsidian setup

Perform the following in the canonical vault:

```text
/Users/tom/obsidian/Tom_Main_Obsidian_Vault
```

### 1. Install Settings Profiles

In Obsidian:

1. Open **Settings → Community plugins**.
2. Install and enable **Settings Profiles** by 4Source.
3. Leave community plugins enabled for the vault.

### 2. Use a global profile directory

In **Settings → Settings Profiles**, set **Profile save path** to an absolute directory outside every Obsidian vault. Recommended:

```text
/Users/tom/.local/share/ObsidianPlugins/Profiles
```

Do not place the profile directory inside the canonical vault, another vault, or Obsidian's application-support directory.

### 3. Create and activate one profile

Create a profile, select it as the active profile, and configure it as follows:

| Profile option | Required state | Reason |
|---|---:|---|
| **Auto-Sync** | On | Writes managed changes to the shared profile automatically. |
| **Appearance** | On | Shares appearance settings, themes, and CSS snippets. |
| **Community plugins** | On | Shares installed/enabled community plugins and their settings. |
| **App** | Off | `app.json` may contain vault-relative note, attachment, and link settings. |
| **Bookmarks** | Off | Bookmarks point to content belonging to one vault. |
| **Core plugins** | Off | The plugin includes `workspace.json`, `workspaces.json`, and vault-relative core-plugin settings in this category. |
| **Graph** | Optional | Safe to share when identical graph presentation is desired. |
| **Hotkeys** | Optional | Safe to share when identical shortcuts are desired. |

These requirements are enforced by `ov`. It refuses to run when an unsafe category is enabled.

### 4. Enable profile change detection

In the plugin's general settings, enable:

```text
Profile update: On
```

This switch is separate from the profile's **Auto-Sync** option. **Profile update** installs the filesystem watcher; **Auto-Sync** determines whether detected changes are written to the active profile. Both must be enabled for changes made in any managed vault to propagate.

The default profile-update delay is suitable. **UI update** is optional and affects only the plugin's status display.

### 5. Save the canonical profile

Use the plugin's **Save current profile** command once after configuring it. Confirm that the profile directory contains:

```text
<profile-name>/
├── profile.json
├── appearance.json          # when Appearance is enabled
├── community-plugins.json   # when Community plugins is enabled
├── plugins/
├── snippets/
└── themes/
```

## Usage

Open the current folder:

```bash
ov
```

Open another folder:

```bash
ov /path/to/folder
```

Validate without changing anything:

```bash
ov --dry-run /path/to/folder
```

Force the managed profile to be reapplied:

```bash
ov --force /path/to/folder
```

Allow a nested vault deliberately:

```bash
ov --allow-nested /path/to/folder
```

Nested vaults are rejected by default because Obsidian links and indexing are vault-relative.

## Propagation model

1. Open a vault with `ov`.
2. Change a managed appearance, plugin, graph, or hotkey setting.
3. Settings Profiles writes the change to the global active profile.
4. Run `ov` for another vault.
5. `ov` closes Obsidian when mutation is required, reloads the latest global profile, applies it atomically, and opens the requested vault.

Propagation is therefore automatic at profile-save time and deterministic at the next `ov` invocation. It is not live synchronisation between already-open vault windows. When the same setting is changed concurrently in different vaults, the last profile write wins.

## What is shared

According to the enabled safe profile categories, `ov` manages:

```text
.obsidian/appearance.json
.obsidian/snippets/
.obsidian/themes/
.obsidian/community-plugins.json
.obsidian/plugins/
.obsidian/graph.json
.obsidian/hotkeys.json
```

The Settings Profiles plugin itself is always installed and enabled in every managed vault.

## What remains independent

`ov` does not touch vault content or these vault-local settings:

```text
notes and folders
attachments
.obsidian/app.json
.obsidian/bookmarks.json
.obsidian/core-plugins.json
.obsidian/workspace.json
.obsidian/workspaces.json
other unmanaged .obsidian files
```

## Community-plugin caveat

Settings Profiles 0.7.x treats community plugins as one category: plugin code, enablement, and each plugin's `data.json` are shared together. A plugin setting that stores vault-relative paths, credentials, caches, indexes, or vault identities may therefore be unsuitable for the shared profile. Disable or remove such a plugin from the shared profile, or accept that its settings are global across these vaults.

## Safety and backups

`ov`:

- validates the canonical plugin installation and active profile;
- rejects unsafe profile categories and unsafe symlinks;
- prevents nested vaults unless explicitly allowed;
- serialises concurrent invocations with a filesystem lock;
- closes Obsidian before mutating its registry or vault configuration;
- re-reads the shared profile after Obsidian exits;
- stages and compares configuration before replacement;
- uses atomic registry writes;
- rolls back partial configuration changes;
- preserves notes and all unmanaged files.

Backups are stored under:

```text
~/.local/state/ov/registry-backups/
~/.local/state/ov/config-backups/
```

The script retains the latest 20 registry backups and the latest five configuration backups per vault.

## Environment overrides

The defaults can be changed without editing the script:

```bash
export OV_CANONICAL_VAULT="/path/to/canonical-vault"
export OV_OBSIDIAN_REGISTRY="$HOME/Library/Application Support/obsidian/obsidian.json"
export OV_STATE_DIR="$HOME/.local/state/ov"
```

## Important implementation constraint

Obsidian's public URI handler can open only already registered vaults. Registration of an arbitrary folder is implemented by updating Obsidian's private macOS vault registry:

```text
~/Library/Application Support/obsidian/obsidian.json
```

This part is necessarily unofficial and may require adjustment if Obsidian changes its internal registry format. Registry mutations are backed up and written atomically.
