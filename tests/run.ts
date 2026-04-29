#!/usr/bin/env npx tsx
/**
 * Skill benchmark suite.
 *
 * Two modes:
 *   trigger     — Does the skill get selected based on the user prompt?
 *   mcp-install — Once the skill is active, does the agent auto-install the Sei MCP?
 *
 * Usage:
 *   npx tsx run.ts                          # run both suites
 *   npx tsx run.ts trigger                  # run trigger suite only
 *   npx tsx run.ts mcp-install              # run mcp-install suite only
 *   npx tsx run.ts --verbose                # show model reasoning
 *   npx tsx run.ts trigger --case 3         # run a single trigger case
 */

import Anthropic from "@anthropic-ai/sdk";
import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── Config ────────────────────────────────────────────────────────────
const MODEL = "claude-haiku-4-5-20251001";
const TARGET_SKILL = "sei";

// ── Helpers ───────────────────────────────────────────────────────────
interface SkillEntry {
  name: string;
  description: string;
}

function loadSkillDescription(path: string): SkillEntry | null {
  try {
    const content = readFileSync(path, "utf-8");
    const match = content.match(/^---\s*\n([\s\S]*?)\n---/);
    if (!match) return null;
    const frontmatter = match[1];
    const name = frontmatter.match(/^name:\s*(.+)$/m)?.[1]?.trim();

    // Handle both single-line `description: foo` and YAML folded `description: >\n  ...`
    let description: string | undefined;
    const firstLine = frontmatter.match(/^description:\s*(.*)$/m)?.[1]?.trim();
    if (firstLine && firstLine !== ">" && firstLine !== "|") {
      description = firstLine;
    } else if (firstLine === ">" || firstLine === "|") {
      const folded = frontmatter.match(/^description:\s*[>|]\s*\n((?:[ \t]+.*\n?)+)/m);
      if (folded) {
        description = folded[1].split("\n").map(l => l.trim()).filter(Boolean).join(" ");
      }
    }

    if (!name || !description) return null;
    return { name, description };
  } catch {
    return null;
  }
}

function loadSkillBody(path: string): string {
  const content = readFileSync(path, "utf-8");
  // Strip frontmatter
  return content.replace(/^---\s*\n[\s\S]*?\n---\s*\n/, "").trim();
}

const skills: SkillEntry[] = [
  loadSkillDescription(resolve(__dirname, "../skill/SKILL.md")),
  { name: "remotion-best-practices", description: "Best practices for Remotion - Video creation in React" },
  { name: "find-skills", description: "Helps users discover and install agent skills" },
  { name: "claude-api", description: "Build apps with the Claude API or Anthropic SDK. TRIGGER when: code imports anthropic/@anthropic-ai/sdk/claude_agent_sdk, or user asks to use Claude API, Anthropic SDKs, or Agent SDK." },
  { name: "solana-dev", description: "Use when user asks to build Solana dApps, write Anchor programs, deploy to Solana devnet/mainnet, use @solana/kit, connect Phantom wallet, work with SPL tokens, or debug Solana transactions." },
].filter(Boolean) as SkillEntry[];

const skillBody = loadSkillBody(resolve(__dirname, "../skill/SKILL.md"));

// ── Types ─────────────────────────────────────────────────────────────
interface TestCase {
  prompt: string;
  expected: boolean;
}

interface SuiteResult {
  name: string;
  pass: number;
  fail: number;
  failures: { prompt: string; expected: boolean; got: boolean; reasoning: string }[];
}

// ── Suite runner ──────────────────────────────────────────────────────
async function runSuite(
  client: Anthropic,
  suiteName: string,
  systemPrompt: string,
  cases: TestCase[],
  evaluator: (text: string) => { matched: boolean; reasoning: string },
  verbose: boolean,
  singleCase: number,
): Promise<SuiteResult> {
  const selected = singleCase >= 0 ? [cases[singleCase]] : cases;
  const startIdx = singleCase >= 0 ? singleCase : 0;

  const result: SuiteResult = { name: suiteName, pass: 0, fail: 0, failures: [] };

  console.log(`\n🧪 ${suiteName}`);
  console.log(`   Model: ${MODEL}`);
  console.log(`   Cases: ${selected.length}\n`);

  for (let i = 0; i < selected.length; i++) {
    const { prompt, expected } = selected[i];
    const idx = startIdx + i + 1;

    try {
      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 512,
        system: systemPrompt,
        messages: [{ role: "user", content: prompt }],
      });

      const text = response.content[0].type === "text" ? response.content[0].text : "";
      const { matched, reasoning } = evaluator(text);
      const ok = matched === expected;

      if (ok) {
        result.pass++;
        console.log(`  ✅ #${idx} ${expected ? "SHOULD" : "SHOULD NOT"} match — "${prompt}"`);
      } else {
        result.fail++;
        console.log(`  ❌ #${idx} ${expected ? "SHOULD" : "SHOULD NOT"} match — "${prompt}"`);
        result.failures.push({ prompt, expected, got: matched, reasoning });
      }

      if (verbose) {
        console.log(`     → ${reasoning}\n`);
      }
    } catch (err: any) {
      result.fail++;
      console.log(`  💥 #${idx} ERROR — "${prompt}": ${err.message}`);
    }
  }

  return result;
}

// ══════════════════════════════════════════════════════════════════════
// SUITE 1: Trigger matching
// ══════════════════════════════════════════════════════════════════════
const triggerSystemPrompt = `You are a skill-matching engine for a coding assistant.
You are given a list of available skills with their names and descriptions.
Your job is to decide which skills (if any) should be activated for the user's message.

Available skills:
${skills.map((s) => `- ${s.name}: ${s.description}`).join("\n")}

Respond with a JSON object:
{
  "triggered_skills": ["skill-name", ...],
  "reasoning": "brief explanation"
}

Rules:
- Only include skills that are clearly relevant to the user's request.
- If no skill matches, return an empty array.
- A skill should trigger when the user's request falls within its described scope.
- Do not trigger a skill for tangentially related requests.
- Respond ONLY with the JSON object, no other text.`;

const triggerCases: TestCase[] = [
  // ─── Dev (smart contracts + tooling) ──────────────────────────────
  { prompt: "Build me a Sei dapp", expected: true },
  { prompt: "Deploy a Solidity contract on Sei testnet", expected: true },
  { prompt: "How do I use the Staking precompile on Sei?", expected: true },
  { prompt: "Explain Twin Turbo Consensus on Sei", expected: true },
  { prompt: "How do pointer contracts work on Sei?", expected: true },
  { prompt: "Why is SSTORE 72000 gas on Sei?", expected: true },
  { prompt: "Set up the Sei MCP server in Claude Code", expected: true },
  { prompt: "Migrate my Ethereum contract to Sei", expected: true },
  { prompt: "Set up Foundry for Sei Network", expected: true },
  { prompt: "Create an ERC20 token on Sei", expected: true },
  { prompt: "How do I use the IBC precompile on Sei?", expected: true },
  { prompt: "What is the dual address system on Sei?", expected: true },
  { prompt: "I'm coming from Solana, how does Sei work?", expected: true },
  { prompt: "How do I use the TokenFactory on Sei?", expected: true },
  { prompt: "Debug my Sei transaction — it keeps reverting", expected: true },
  { prompt: "How do I verify my contract on Seitrace?", expected: true },
  { prompt: "Load test my Sei contract against the OCC scheduler", expected: true },
  { prompt: "How should I design a Sei contract for parallel execution?", expected: true },
  { prompt: "Optimize gas for my Sei contract — what's different from Ethereum?", expected: true },
  { prompt: "How do I use ERC-4337 account abstraction on Sei?", expected: true },
  { prompt: "Make my Sei contract upgradeable with UUPS proxy", expected: true },
  // ─── Website (frontend dev + site awareness) ──────────────────────
  { prompt: "Connect a wallet to Sei using Wagmi", expected: true },
  { prompt: "How do I use Sei Global Wallet for social login?", expected: true },
  { prompt: "Display both EVM and Cosmos addresses for a Sei user", expected: true },
  { prompt: "How do I contribute a page to docs.sei.io?", expected: true },
  { prompt: "Where do I find the Sei brand kit?", expected: true },
  { prompt: "Where on the Sei docs site can I find precompile docs?", expected: true },
  { prompt: "How do I add Sei to my multichain dApp with RainbowKit?", expected: true },
  // ─── Ecosystem (apps + integration + participation) ───────────────
  { prompt: "What dApps are live on Sei mainnet?", expected: true },
  { prompt: "How do I integrate with a Sei DEX?", expected: true },
  { prompt: "How do I bridge tokens to Sei with LayerZero?", expected: true },
  { prompt: "What bridges work with Sei?", expected: true },
  { prompt: "What are good RPC endpoints for Sei?", expected: true },
  { prompt: "Set up a Sei full node", expected: true },
  { prompt: "How do I delegate SEI to a validator?", expected: true },
  { prompt: "How do I become a Sei validator?", expected: true },
  { prompt: "Submit a governance proposal on Sei", expected: true },
  { prompt: "How do I use Pyth oracles on Sei?", expected: true },
  { prompt: "Set up The Graph subgraph for my Sei contract", expected: true },
  { prompt: "Apply for a Sei Foundation grant", expected: true },
  { prompt: "Run an indexer for Sei", expected: true },
  // ─── Should NOT trigger ───────────────────────────────────────────
  { prompt: "Build me a React app", expected: false },
  { prompt: "Help with my Solana program", expected: false },
  { prompt: "Deploy to Arbitrum", expected: false },
  { prompt: "Set up PostgreSQL", expected: false },
  { prompt: "Create a video with Remotion", expected: false },
  { prompt: "How do I use the Claude API?", expected: false },
  { prompt: "Write a Python web scraper", expected: false },
  { prompt: "Deploy to Vercel", expected: false },
  { prompt: "Write a Rust CLI tool", expected: false },
  { prompt: "Set up Ethereum mainnet with MetaMask", expected: false },
];

function triggerEvaluator(text: string) {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(jsonMatch?.[0] ?? text);
    const matched = parsed.triggered_skills.includes(TARGET_SKILL);
    return {
      matched,
      reasoning: `skills: [${parsed.triggered_skills.join(", ")}] — ${parsed.reasoning}`,
    };
  } catch {
    return { matched: false, reasoning: `[parse error] ${text}` };
  }
}

// ══════════════════════════════════════════════════════════════════════
// SUITE 2: MCP auto-install
// ══════════════════════════════════════════════════════════════════════
const mcpInstallSystemPrompt = `You are a coding assistant called Claude Code. You have the Bash tool available.
The following skill has been activated for this conversation:

<skill>
${skillBody}
</skill>

You do NOT currently have any Sei MCP tools available (no mcp__sei-mcp-server__* tools exist).

The user is asking a Sei-related question. Describe the first actions you would take before answering, as a JSON object:

{
  "actions": ["description of each action you'd take"],
  "would_install_mcp": true/false,
  "install_command": "the exact command you'd run, or null",
  "reasoning": "brief explanation"
}

Respond ONLY with the JSON object.`;

const mcpInstallCases: TestCase[] = [
  // All should trigger MCP install
  { prompt: "What is my SEI balance?", expected: true },
  { prompt: "Deploy a contract to Sei testnet", expected: true },
  { prompt: "How do I use the Staking precompile?", expected: true },
  { prompt: "Send 1 SEI to another address on Sei", expected: true },
  { prompt: "What's the latest block on Sei?", expected: true },
  { prompt: "Check the transaction status on Sei", expected: true },
  { prompt: "Interact with a Sei smart contract", expected: true },
  { prompt: "How do I run a Sei node?", expected: true },
];

function mcpInstallEvaluator(text: string) {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    const parsed = JSON.parse(jsonMatch?.[0] ?? text);
    const matched = parsed.would_install_mcp === true;
    const cmd = parsed.install_command || "none";
    const hasCorrectCmd = typeof cmd === "string" &&
      cmd.includes("claude mcp add") &&
      cmd.includes("sei-mcp-server");
    return {
      matched,
      reasoning: `install: ${matched}, correct_cmd: ${hasCorrectCmd}, cmd: "${cmd}" — ${parsed.reasoning}`,
    };
  } catch {
    return { matched: false, reasoning: `[parse error] ${text}` };
  }
}

// ── Main ──────────────────────────────────────────────────────────────
async function main() {
  const args = process.argv.slice(2);
  const verbose = args.includes("--verbose");
  const suiteFilter = args.find((a) => ["trigger", "mcp-install"].includes(a));
  const caseIdx = args.includes("--case")
    ? parseInt(args[args.indexOf("--case") + 1], 10) - 1
    : -1;

  const client = new Anthropic();
  const results: SuiteResult[] = [];

  if (!suiteFilter || suiteFilter === "trigger") {
    results.push(
      await runSuite(client, "Skill trigger matching", triggerSystemPrompt, triggerCases, triggerEvaluator, verbose, caseIdx)
    );
  }

  if (!suiteFilter || suiteFilter === "mcp-install") {
    results.push(
      await runSuite(client, "MCP auto-install", mcpInstallSystemPrompt, mcpInstallCases, mcpInstallEvaluator, verbose, caseIdx)
    );
  }

  // ── Summary ─────────────────────────────────────────────────────────
  console.log(`\n${"═".repeat(60)}`);
  let totalPass = 0;
  let totalFail = 0;

  for (const r of results) {
    totalPass += r.pass;
    totalFail += r.fail;
    const pct = Math.round((r.pass / (r.pass + r.fail)) * 100);
    console.log(`  ${r.name}: ${r.pass}/${r.pass + r.fail} (${pct}%)`);

    if (r.failures.length > 0) {
      for (const f of r.failures) {
        console.log(`    ❌ "${f.prompt}"`);
        console.log(`       expected ${f.expected ? "YES" : "NO"}, got ${f.got ? "YES" : "NO"}`);
        console.log(`       ${f.reasoning}`);
      }
    }
  }

  const totalPct = Math.round((totalPass / (totalPass + totalFail)) * 100);
  console.log(`${"─".repeat(60)}`);
  console.log(`  Total: ${totalPass}/${totalPass + totalFail} (${totalPct}%)\n`);

  process.exit(totalFail > 0 ? 1 : 0);
}

main();
