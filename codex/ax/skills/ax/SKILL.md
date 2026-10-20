---
name: ax
description: Use AX to run agent experiments, analyze and share their results, and label and review agent behaviors in run transcripts. Use when the user asks to run or analyze an AX experiment, publish an insight, invite teammates, or label, review or count behaviors.
---

# AX

AX runs agent experiments: matrices of tasks, agents and models in sandboxes,
with results you can query and share. Behaviors label what agents did in run
transcripts.

Before a multi-step AX task, call the AX MCP server's `learn` tool:

- `learn` with no arguments lists the workflows.
- `learn` with a workflow's `slug` returns its steps: the tools to call, in
  order, with how to call each.

Follow the steps `learn` returns. They match the tools your organization has,
while the list below is only an overview.

## Workflows

- `run-experiment`: Run an experiment
- `analyze-results`: Analyze your results
- `publish-insight`: Publish a shareable insight
- `analyze-sql`: Query results with SQL
- `secrets`: Use secrets in an experiment
- `invite-team`: Invite teammates to your org
- `label-behaviors`: Label and review behaviors in run transcripts (only where behaviors are enabled for the organization)
