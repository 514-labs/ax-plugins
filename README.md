# AX plugins

Connect Claude Code, Codex, GitHub Copilot and Cursor to AX experiments.
This repository is generated from [514-labs/ax](https://github.com/514-labs/ax).
Do not edit it here; changes will be overwritten by the release workflow.

## Install

Register the Git-backed main channel so your client can fetch new versions.

### Claude Code

Run inside Claude Code:

```text
/plugin marketplace add 514-labs/ax-plugins
/plugin install ax@ax-prod
```

See [Claude Code marketplace sources and refs](https://code.claude.com/docs/en/plugins/host-marketplace).

### Codex

```sh
codex plugin marketplace add 514-labs/ax-plugins
codex plugin add ax@ax-prod
```

See [Codex plugin marketplaces](https://developers.openai.com/plugins/build/plugins).

### GitHub Copilot CLI

```sh
copilot plugin marketplace add 514-labs/ax-plugins
copilot plugin install ax@ax-prod
```

See [Copilot marketplace sources and refs](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-cli-reference/cli-plugin-reference).

### GitHub Copilot in VS Code

Add this marketplace to your VS Code user settings, preserving existing entries:

```json
{
  "chat.plugins.marketplaces": [
    "514-labs/ax-plugins"
  ]
}
```

Open Extensions, search `@agentPlugins`, find `ax`, and select Install.
Review the marketplace trust prompt.
VS Code also discovers plugins installed with Copilot CLI in the same home directory.
See [VS Code agent plugins](https://code.visualstudio.com/docs/agent-customization/agent-plugins).

### Cursor

For an individual local install, clone the main channel and copy only its
Cursor shell into Cursor's local plugin directory:

```sh
git clone --branch main https://github.com/514-labs/ax-plugins.git ax-plugins-prod
mkdir -p ~/.cursor/plugins/local/ax
cp -R ./ax-plugins-prod/cursor/ax/. ~/.cursor/plugins/local/ax/
```

Restart Cursor or run **Developer: Reload Window**, then open Customize to
confirm the plugin loaded. On Teams and Enterprise plans, your admin must allow
local imports. A marketplace install with the same plugin name takes precedence
over a local copy.
For updates, pull the clone with `git -C ax-plugins-prod pull --ff-only`,
copy the Cursor shell again, and reload.
See [Cursor's local-plugin instructions](https://cursor.com/docs/plugins#test-plugins-locally).

On Teams or Enterprise, an admin imports the Git repository as a Team Marketplace:

1. Open Dashboard → Plugins & MCPs → Team Marketplaces → Add Marketplace → Import from Repo.
2. Import `https://github.com/514-labs/ax-plugins` and ensure the marketplace tracks the `main` branch.
3. Review the `ax` plugin, set access, and save. Enable Auto Refresh to receive branch updates (requires the Cursor GitHub App on the repository), or use Refresh manually.
4. Open Customize in Cursor, find `ax` in your team marketplace, and select Install.

Cursor documents this dashboard flow rather than a marketplace-add CLI command.
Public marketplace listing is a separate review step.
See [Cursor team marketplace installation and updates](https://cursor.com/docs/plugins).

Authenticate with AX when your client prompts. This channel installs ax and connects to https://app.514.ax/mcp.

## Updates

Refresh the Git-backed marketplace and update the installed plugin in your client.
Claude Code can enable marketplace auto-updates in `/plugin`; Codex refreshes with
`codex plugin marketplace upgrade ax-prod`; Copilot refreshes with
`copilot plugin marketplace update ax-prod`, then updates with
`copilot plugin update ax@ax-prod`. Cursor uses Auto Refresh or the
admin's Refresh action above; individual local installs use the pull/copy/reload
steps in the Cursor section. Releases bump the plugin version so clients can
replace their cached copy.

## Feedback and opt-out

The stop hook may ask you to draft feedback after using AX. Feedback is sent
only with your consent. Claude Code and Codex share a per-user 24-hour prompt
cooldown; Copilot and Cursor use a separate local daily marker.

- **Claude Code:** Enable "Skip AX feedback prompt" in the plugin's settings. Its
  `AX_FEEDBACK_OPT_OUT` user setting is passed to the feedback tool; opting out
  skips the prompt and doesn't count toward the daily limit.
- **Codex:** Open `/hooks` in the CLI and disable the AX Stop hook, or leave it untrusted.
  The MCP tool hook cannot read `AX_FEEDBACK_OPT_OUT` from your environment.
  To disable the entire plugin, add this to `~/.codex/config.toml` (or a
  trusted project's `.codex/config.toml`):

```toml
[plugins."ax@ax-prod"]
enabled = false
```

  See [Codex hook trust and disabling](https://learn.chatgpt.com/docs/hooks) and
  [plugin enable/disable configuration](https://developers.openai.com/plugins/build/plugins).
- **Copilot:** Set `AX_FEEDBACK_OPT_OUT=true` in the environment used to launch
  Copilot CLI or VS Code; the shell hook reads this value.
- **Cursor:** Configure the plugin's `AX_FEEDBACK_OPT_OUT` variable to `true`.
