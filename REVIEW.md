# Review guidelines for AI agents

Repo-specific conventions for automated PR review (Codex, Cursor, Claude, and
any other AI reviewer). This repo ships **prose that other AI agents consume as
ground truth**, not a running service: the `skill/` tree is the product, and
`install.sh` is the only executable of consequence. Calibrate accordingly — a
wrong number in a markdown table is a higher-severity defect here than it would
be in a normal codebase, and style nits on reference prose are near-worthless.

## 1. Factual accuracy about Sei is the primary correctness axis

Every concrete claim in `skill/**` gets replayed to users by an agent that
cannot check it. The highest-value finding in this repo is a Sei fact that is
wrong or stale. Scrutinise added or changed:

- chain IDs, network names, and `evm_chain_id` values,
- contract, precompile, and pointer addresses,
- gas costs and fee/denom values,
- RPC, explorer, faucet, and docs URLs,
- hardware, Node/Go, and toolchain version requirements,
- CLI flags and subcommands for `seid`, Foundry, and Hardhat.

Real regressions have shipped in each of those categories, so treat them as
load-bearing rather than incidental.

You usually cannot settle a network fact from the diff alone. When a value
looks suspect, **ask for the authoritative source rather than asserting the
value is wrong** — link to what you checked (`docs.sei.io`, `sei-chain`,
Seiscan) and say what disagrees. An unsourced numeric or version change to an
existing documented value is worth raising on its own.

Prefer official Sei sources over third-party aggregators. This repo migrated
off Seitrace in favour of Seiscan (Sourcify) for verification flows; flag new
Seitrace references as regressions.

## 2. A new reference file must be linked from `skill/SKILL.md`

`install.sh` does not carry a file manifest. In flatten mode it discovers
reference files by grepping the selected variant entry point for
`references/**.md` paths:

```bash
grep -Eo 'references/[^)"[:space:]]+\.md' "$SOURCE_DIR/$VARIANT_FILE" | sort -u
```

So a file added under `skill/references/` but not linked from a `SKILL*.md`
entry point is **silently omitted** from every flattened agent install
(`--agent cursor`, `--agent codex`, `--flatten`, …) while still appearing in the
Claude Code directory install, which copies the whole tree. That asymmetry is
invisible in CI and in the diff.

The invariant to check: every file under `skill/references/` is linked from
`skill/SKILL.md` (the full variant), **and** from each domain variant
(`SKILL-CONTRACTS.md`, `SKILL-FRONTEND.md`, `SKILL-ECOSYSTEM.md`) it belongs
to. Flag an added reference file that no entry point links, and flag a renamed
or moved reference whose links were not updated — a stale link degrades to a
missing file rather than an error, since the append loop skips paths that do not
exist.

## 3. YAML frontmatter on `SKILL*.md` is load-bearing

Two consumers parse it:

- `install.sh` strips frontmatter with awk by discarding everything up to the
  **second** `---` line. There is no check that those two lines actually
  delimit a frontmatter block, so an entry point whose frontmatter is malformed
  or missing silently mis-slices — output starting at some later horizontal
  rule, or an empty file if fewer than two `---` lines remain. It never fails
  loudly. Any edit to the opening `---`/`name`/`description` block deserves a
  close look.
- `tests/run.ts` reads `name` and `description` out of the frontmatter and
  scores whether an agent selects the skill for a given prompt.

The `description` field is the skill's trigger surface: it is a long list of
paraphrased user requests, and trimming it changes activation behaviour even
though nothing about it looks like code. Treat a shortened or reworded
`description` as a behavioural change and say which prompts it may stop
matching.

## 4. `install.sh` portability constraints

The README commits to macOS, Linux, Git Bash on Windows, and WSL. That means:

- **bash 3.2 compatible** — macOS ships bash 3.2. No `mapfile`/`readarray`, no
  associative arrays (`declare -A`), no `${var,,}` case conversion. The script
  is currently clean of all of these; keep it that way.
- **no GNU-only flags** — coreutils on macOS and Git Bash are BSD/MinGW.
- The script runs under `set -e` only. If you flag a missing `set -u` or
  `pipefail`, note that adding them is a behavioural change to every path, not a
  free hardening win.

Also check that a new `--agent` target sets `AGENT_DEFAULT_OUTPUT`, is listed in
both `--help` and the `Supported agents` error string, and is documented in the
README table — the four are updated by hand and drift silently.

## 5. Known non-issues — do not flag these

- **Content duplicated across `SKILL.md` and the `SKILL-*.md` variants.** Each
  variant is a standalone entry point for a separate install, so overlap is
  intentional. The same reference file is deliberately linked from several
  variants. Do not propose deduplicating them into shared includes.
- **`tests/` not running in CI.** It is a model-scored benchmark: it calls the
  Anthropic API (`new Anthropic()`, so it needs `ANTHROPIC_API_KEY`) and grades
  skill selection. It is not a deterministic unit-test suite. Do not ask for it
  to gate the PR, and do not ask for exact-match assertions in place of model
  scoring.
- **Long files and long lines under `skill/references/`.** Reference documents
  are meant to be exhaustive and there is no line-length or file-size lint.
  Size alone is not a finding.
- **Prose that repeats itself between `README.md` and `skill/`.** The README
  describes the skill to humans; `skill/` addresses agents. Parallel wording is
  expected — only flag it when the two actually contradict each other.
