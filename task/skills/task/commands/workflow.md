# /task workflow

The workflow definition lives in `{tasksDir}/_workflow/WORKFLOW.md`, falling back to
`<global>/_workflow/WORKFLOW.md` (`<global>` per `references/configuration.md`). Full detail — the file format, step
definition files and their resolution order — is in `references/workflow-system.md`.

- `/task workflow` — read WORKFLOW.md and show the steps as a table, then mention which
  steps have a detail file under `steps/`.
- `/task workflow step <name>` — show that step's detail file (project first, then global).
- `/task workflow init` — create `{tasksDir}/_workflow/`: copy the global workflow if there
  is one, otherwise write the template from `references/workflow-system.md`. Tell the user
  it is theirs to customise.
