# Workflow guide — writing and customising workflows

Where workflow files live, how a step is resolved and what WORKFLOW.md looks like is in
`workflow-system.md`; this is the authoring side — writing a step definition and shaping a
workflow for a particular kind of project.

## Creating Workflows

### Global Default

Create at `~/.claude/project-tasks/_workflow/`:

```bash
mkdir -p ~/.claude/project-tasks/_workflow/steps
```

This applies to all projects without their own workflow.

### Project-Specific

Create at `{tasksDir}/_workflow/`:

```bash
mkdir -p ~/.claude/tasks/my-project/_workflow/steps
```

You can:
- Override entire workflow (custom WORKFLOW.md)
- Override specific steps only (add just those step files)
- Mix: use global WORKFLOW.md but override some steps

## Step File Format

`steps/requirements.md`:

```markdown
# Requirements

## Purpose
Formalize requirements before implementation.

## When Needed
- Complex features with multiple stakeholders
- Ambiguous user requests
- Features requiring approval

## When to Skip
- Simple bugfixes
- Clear, well-defined tasks
- Urgent hotfixes

## Process

1. Identify stakeholders
2. Gather requirements through questions
3. Write EARS specifications:
   - "When <trigger>, the system shall <response>"
   - "While <state>, the system shall <behavior>"
4. Review with user
5. Add to task file under ## Requirements

## Output
Requirements section added to task file.

## References
- EARS syntax guide
- Example requirements
```

## Step Naming

Use semantic names without number prefixes:

```
requirements.md
bdd.md
assessment.md
...
reflection.md
```

Order is defined in WORKFLOW.md, not filenames. This allows reusing steps in different sequences across projects.

## Customization Examples

### Backend-Heavy Project

```markdown
1. requirements - API contract definition
2. database - Schema design
3. implementation - Write code
4. tests - Unit + integration tests
5. documentation - API docs
```

### Frontend Project

```markdown
1. design - UI/UX mockups
2. components - Component breakdown
3. implementation - Build components
4. tests - Component + E2E tests
5. accessibility - A11y audit
```

### Research Task

```markdown
1. question - Define research question
2. sources - Identify sources
3. research - Gather information
4. synthesis - Summarize findings
5. recommendations - Actionable conclusions
```


## Resolution

Project step file, then the global one, then the one-liner in WORKFLOW.md — spelled out in
`workflow-system.md`. Writing the same rule here again is how the two drift apart.
