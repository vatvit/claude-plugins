# claude.awk — the project's CLAUDE.md from the answers. Run through kickoff_awk with
# -v tasks="<where tasks live>" (empty when no task config was written).
#
# Instructions only, never project knowledge: the knowledge is in docs/ and the charter.
# The user's standing instructions are never restated. Only this project's choices, and where it
# departs from how the user usually works (E4), are.

{ load() }

function a(id) { return settled(id) }
function line(label, v) { if (v != "") body = body "- **" label "** " v "\n" }
function section(title) { if (body != "") { out = out "\n## " title "\n\n" body; body = "" } }

END {
    name = (ans["A1"] != "") ? ans["A1"] : "Project"
    out = "# " name " — project instructions\n\n"
    out = out "Project knowledge (context, goal, decisions, how to run and test) lives in `docs/`;\n"
    out = out "this file holds only instructions. Start every session by reading [the charter](docs/project/charter.md).\n"

    line("Branching:", a("R1")); line("Commit messages:", a("R2"))
    if (a("A5") != "" && !starts_ci(a("A5"), "No remote")) line("Remote:", "`" a("A5") "`")
    if (a("R3") != "" && !starts_ci(a("R3"), "None")) line("Remote quirks:", a("R3"))
    if (starts_ci(a("A6"), "Yes")) line("Identity:", "only the project owner's identity appears in this project — no personal names, emails, links or home paths of whoever works on it, in code, docs or commits.")
    section("Git")

    line("Development runs:", a("I0"))
    line("Entry point:", a("R4"))
    if (starts_ci(a("R5"), "Yes")) line("Parallel sessions:", "several Claude sessions work in this tree at once; each joins the crew at session start (crew plugin).")
    if (tasks != "") line("Tasks:", "the `/task` skill, prefix `" a("R8") "`, kept " tasks ".")
    else if (a("R6") != "" && !starts_ci(a("R6"), "None")) line("Tasks:", a("R6"))
    # C5: the two rules a backward-compatibility answer chooses between; a Later answer flips one to the other.
    free = "change interfaces, formats and stored data freely — no shims, no deprecation paths, no migrations for old data."
    keep = "deprecate before removing, and migrate stored data."
    c5 = a("C5"); L = "Backward compatibility:"
    if (later_trigger(c5) != "") line(L, "free to break until " later_trigger(c5) "; from then on, " keep)
    else if (starts_ci(c5, "Not needed")) line(L, "not needed yet: " free)
    else if (starts_ci(c5, "Never")) line(L, "never kept: " free)
    else if (starts_ci(c5, "From the start")) line(L, "kept from the start: " keep)
    else line(L, c5)
    section("Working here")

    if (a("F1") != "") line("Quality level:", a("F1") " — the checks and their tools are in [quality](docs/project/quality.md).")
    if (a("F7") != "") line("Checks run:", joined("F7", "; ") ".")
    line("A red check:", a("F9"))
    section("Quality")

    if (a("E3") != "" && a("E2") != "") {
        if (starts_ci(a("E3"), "Yes")) line("Approved:", "calling " joined("E2", ", ") " in development and tests. Any other external service needs its own approval.")
        else line("External services:", a("E3"))
    }
    if (a("E4") != "" && !starts_ci(a("E4"), "None")) line("Differs from your usual rules:", a("E4") (why["E4"] != "" ? " — " why["E4"] : ""))
    line("Language:", a("K2") != "" ? "docs and our conversation are in " a("K2") "." : "")
    section("Approvals and exceptions")

    printf "%s", out
}
