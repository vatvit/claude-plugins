# claude.awk — the project's CLAUDE.md from the answers. Run through kickoff_awk with
# -v tasks="<where tasks live>" (empty when no task config was written).
#
# Instructions only, never project knowledge: the knowledge is in docs/ and the charter.
# Global rules are never restated. Only this project's choices and its exceptions to them are.

{ load() }

function a(id) { return settled(id) }
function line(label, v) { if (v != "") body = body "- **" label "** " v "\n" }
function section(title) { if (body != "") { out = out "\n## " title "\n\n" body; body = "" } }

END {
    name = (ans["A1"] != "") ? ans["A1"] : "Project"
    out = "# " name " — project instructions\n\n"
    out = out "Project knowledge (context, goal, decisions, how to run and test) lives in [`docs/`](docs/_index.md);\n"
    out = out "this file holds only instructions. Start every session by reading [the charter](docs/project/charter.md).\n"

    line("Branching:", a("R1")); line("Commit messages:", a("R2"))
    if (a("A5") != "" && !starts_ci(a("A5"), "No remote")) line("Remote:", "`" a("A5") "`")
    if (a("R3") != "" && !starts_ci(a("R3"), "None")) line("Remote quirks:", a("R3"))
    section("Git")

    line("Entry point:", a("R4"))
    if (starts_ci(a("R5"), "Yes")) line("Parallel sessions:", "several Claude sessions work in this tree at once; each joins the crew at session start (crew plugin).")
    if (tasks != "") line("Tasks:", "the `/task` skill, prefix `" a("R7") "`, kept " tasks ".")
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

    if (starts_ci(a("E3"), "Yes") && a("E2") != "") line("Approved:", "calling " a("E2") " in development and tests. Any other external service needs its own approval.")
    if (a("E5") != "" && !starts_ci(a("E5"), "None")) line("Exception to the global rules:", a("E5") (why["E5"] != "" ? " — " why["E5"] : ""))
    if (a("K2") != "" && !starts_ci(a("K2"), "English")) line("Language:", "docs and our conversation are in " a("K2") ".")
    section("Approvals and exceptions")

    printf "%s", out
}
