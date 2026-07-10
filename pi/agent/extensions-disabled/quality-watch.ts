import * as Pi from "@earendil-works/pi-coding-agent"
import * as NFsPromises from "node:fs/promises"
import * as NPath from "node:path"

const EXTENSION_ID = "quality-watch"
const COMMAND_TIMEOUT_MS = 120_000
const PRIVATE_REPAIR_TOOLS = ["read", "bash", "edit", "write"]

interface CommandSpec {
  readonly command: string
  readonly args: ReadonlyArray<string>
  readonly display: string
}

interface CommandRun {
  readonly command: CommandSpec
  readonly result: Pi.ExecResult
}

interface CommandFailure {
  readonly stage:
    | "oxlint"
    | "dprint"
  readonly command: CommandSpec
  readonly paths: ReadonlyArray<string>
  readonly result?: Pi.ExecResult
  readonly error?: unknown
}

const exists = async (path: string): Promise<boolean> => {
  try {
    await NFsPromises.access(path)
    return true
  } catch {
    return false
  }
}

const displayArg = (arg: string): string => arg.includes(" ") ? JSON.stringify(arg) : arg

const commandDisplay = (binary: string, args: ReadonlyArray<string>): string =>
  [binary, ...args].map(displayArg).join(" ")

const resolveCommand = async (cwd: string, binary: string, args: ReadonlyArray<string>): Promise<CommandSpec> => {
  const localBinary = NPath.join(cwd, "node_modules", ".bin", binary)
  const command = await exists(localBinary) ? localBinary : binary
  return {
    command,
    args,
    display: commandDisplay(binary, args),
  }
}

const normalizeChangedPath = (cwd: string, path: string): string => {
  const withoutAt = path.startsWith("@") ? path.slice(1) : path
  if (!NPath.isAbsolute(withoutAt)) return withoutAt

  const relative = NPath.relative(cwd, withoutAt)
  return relative.startsWith("..") ? withoutAt : relative
}

const describeFiles = (paths: ReadonlyArray<string>): string =>
  paths.length === 1 ? paths[0] ?? "unknown file" : `${paths.length} files`

const combineOutput = (result:
  | Pi.ExecResult
  | undefined, error: unknown): string => {
  if (result === undefined) {
    return error instanceof Error ? error.stack ?? error.message : String(error)
  }

  const parts = [
    result.stdout.trimEnd() === "" ? undefined : `stdout:\n${result.stdout.trimEnd()}`,
    result.stderr.trimEnd() === "" ? undefined : `stderr:\n${result.stderr.trimEnd()}`,
  ]
    .filter((part) => part !== undefined)

  return parts.length === 0 ? "(no output)" : parts.join("\n\n")
}

const truncateForAgent = (text: string): string => {
  const truncated = Pi.truncateTail(text, {
    maxBytes: Pi.DEFAULT_MAX_BYTES,
    maxLines: Pi.DEFAULT_MAX_LINES,
  })

  if (!truncated.truncated) return truncated.content

  return [
    `[Output truncated to last ${truncated.outputLines} of ${truncated.totalLines} lines (`
    + `${Pi.formatSize(truncated.outputBytes)} of ${Pi.formatSize(truncated.totalBytes)}).]`,
    truncated.content,
  ]
    .join("\n")
}

const repairKey = (failure: CommandFailure): string =>
  [failure.stage, ...failure.paths, combineOutput(failure.result, failure.error)].join("\0")

const isTextPart = (part: unknown): part is { readonly type: "text"; readonly text: string } =>
  typeof part === "object"
  && part !== null
  && "type" in part
  && part.type === "text"
  && "text" in part
  && typeof part.text === "string"

const latestAssistantText = (
  messages: ReadonlyArray<{ readonly role?: string; readonly content?: unknown }>,
): string => {
  for (let index = messages.length - 1; index >= 0; index--) {
    const message = messages[index]
    if (message?.role !== "assistant" || !Array.isArray(message.content)) continue

    return message
      .content
      .filter(isTextPart)
      .map((part) => part.text)
      .join("")
  }

  return ""
}

const formatFailureMessage = (failure: CommandFailure): string => {
  const stageDescription = failure.stage === "oxlint"
    ? "oxlint failed for the changed file(s), so dprint fmt was not run."
    : "oxlint passed for the changed file(s), but dprint fmt failed."
  const output = truncateForAgent(combineOutput(failure.result, failure.error))
  const exit = failure.result === undefined
    ? "command could not be executed"
    : `exit code ${failure.result.code}${failure.result.killed ? " (killed or timed out)" : ""}`

  return [
    `Automated quality check failed for ${describeFiles(failure.paths)}.`,
    stageDescription,
    "Only the file(s) changed during the assistant turn were checked.",
    "A private repair agent will try to fix this outside the main conversation context.",
    "",
    `Command: ${failure.command.display}`,
    `Result: ${exit}`,
    "",
    "````text",
    output,
    "````",
  ]
    .join("\n")
}

const setStatus = (
  ctx: Pi.ExtensionContext,
  text: string,
  kind:
    | "info"
    | "success"
    | "warning"
    | "error" = "info",
) => {
  if (!ctx.hasUI) return

  const theme = ctx.ui.theme
  const icon = kind === "success"
    ? theme.fg("success", "✓")
    : kind === "warning"
    ? theme.fg("warning", "…")
    : kind === "error"
    ? theme.fg("error", "✗")
    : theme.fg("accent", "●")

  ctx.ui.setStatus(EXTENSION_ID, `${icon} ${theme.fg("dim", text)}`)
}

const changedPathFromPiWrite = (ctx: Pi.ExtensionContext, event: Pi.ToolResultEvent):
  | string
  | undefined => {
  if (!Pi.isEditToolResult(event) && !Pi.isWriteToolResult(event)) return undefined
  return typeof event.input.path === "string" ? normalizeChangedPath(ctx.cwd, event.input.path) : undefined
}

export default function(pi: Pi.ExtensionAPI) {
  let activeRun:
    | AbortController
    | undefined
  let running = false
  let trackingAssistantTurn = false
  let shuttingDown = false
  const changedPaths = new Set<string>()
  const attemptedRepairs = new Set<string>()
  const pendingRepairs: Array<{ readonly ctx: Pi.ExtensionContext; readonly failure: CommandFailure }> = []

  const runCommand = async (
    ctx: Pi.ExtensionContext,
    command: CommandSpec,
    signal: AbortSignal,
  ): Promise<Pi.ExecResult> => {
    return pi.exec(command.command, [...command.args], {
      cwd: ctx.cwd,
      signal,
      timeout: COMMAND_TIMEOUT_MS,
    })
  }

  const lintFiles = async (
    ctx: Pi.ExtensionContext,
    paths: ReadonlyArray<string>,
    signal: AbortSignal,
  ): Promise<CommandRun> => {
    const command = await resolveCommand(ctx.cwd, "oxlint", ["--format", "unix", "--", ...paths])
    const result = await runCommand(ctx, command, signal)
    return { command, result }
  }

  const formatFiles = async (
    ctx: Pi.ExtensionContext,
    paths: ReadonlyArray<string>,
    signal: AbortSignal,
  ): Promise<CommandRun> => {
    const command = await resolveCommand(ctx.cwd, "dprint", ["fmt", "--", ...paths])
    const result = await runCommand(ctx, command, signal)
    return { command, result }
  }

  const repairFailurePrivately = async (ctx: Pi.ExtensionContext, failure: CommandFailure): Promise<boolean> => {
    const key = repairKey(failure)
    if (attemptedRepairs.has(key)) {
      setStatus(ctx, "private repair failed; waiting for next assistant turn", "error")
      if (ctx.hasUI) {
        ctx.ui.notify(`Quality watcher: private repair did not fix ${describeFiles(failure.paths)}`, "error")
      }
      return false
    }

    attemptedRepairs.add(key)
    setStatus(ctx, `private repair for ${describeFiles(failure.paths)}`, "warning")

    const agentDir = Pi.getAgentDir()
    const resourceLoader = new Pi.DefaultResourceLoader({
      cwd: ctx.cwd,
      agentDir,
      noExtensions: true,
      appendSystemPrompt: [
        [
          "You are a private quality-fix subagent. Your conversation is intentionally isolated from the main session.",
          "Inherit and use the prior conversation context, including the latest private quality failure context.",
          "Fix only the quality failure. Do not modify unrelated files.",
          "Use namespace imports for local modules when oxlint asks for them. Preserve project import rules.",
          "After edits, run the failed command again. If it passes, run dprint fmt on the listed paths.",
          "When oxlint and dprint pass for the listed paths, respond exactly: FIXED",
        ]
          .join("\n"),
      ],
    })
    await resourceLoader.reload()

    const inheritedContext = Pi.buildSessionContext(ctx.sessionManager.getEntries(), ctx.sessionManager.getLeafId())
    const { session } = await Pi.createAgentSession({
      cwd: ctx.cwd,
      agentDir,
      resourceLoader,
      sessionManager: Pi.SessionManager.inMemory(ctx.cwd),
      modelRegistry: ctx.modelRegistry,
      model: ctx.model,
      thinkingLevel: inheritedContext.thinkingLevel ?? pi.getThinkingLevel(),
      tools: PRIVATE_REPAIR_TOOLS,
    })

    try {
      session.agent.state.messages = [
        ...inheritedContext.messages,
        {
          role: "user",
          content: [{ type: "text", text: formatFailureMessage(failure) }],
          timestamp: Date.now(),
        },
      ]
      await session.prompt("fix it", { source: "extension" })
      if (latestAssistantText(session.messages).trim() !== "FIXED") {
        setStatus(ctx, "private repair did not report FIXED", "error")
        return false
      }
      return true
    } finally {
      session.dispose()
    }
  }

  const queuePrivateRepair = (ctx: Pi.ExtensionContext, failure: CommandFailure) => {
    pendingRepairs.push({ ctx, failure })
    setStatus(ctx, "pending private quality repair", "warning")
    if (!running && ctx.isIdle()) void runPendingRepairs()
  }

  const runPendingRepairs = async () => {
    if (running || shuttingDown || pendingRepairs.length === 0) return

    const repair = pendingRepairs.shift()
    if (repair === undefined) return

    try {
      const repaired = await repairFailurePrivately(repair.ctx, repair.failure)
      if (repaired && !shuttingDown) {
        await runQualityCheck(repair.ctx, repair.failure.paths)
      }
    } catch (error) {
      if (shuttingDown) return
      setStatus(repair.ctx, "private repair command failed", "error")
      if (repair.ctx.hasUI) {
        const message = error instanceof Error ? error.message : String(error)
        repair.ctx.ui.notify(`Quality watcher private repair failed: ${message}`, "error")
      }
    } finally {
      if (!shuttingDown && pendingRepairs.length > 0) void runPendingRepairs()
    }
  }

  const runQualityCheck = async (ctx: Pi.ExtensionContext, paths: ReadonlyArray<string>) => {
    if (running || shuttingDown || paths.length === 0) return

    running = true
    const runPaths = [...new Set(paths)]
    const controller = new AbortController()
    activeRun = controller

    let currentStage:
      | "oxlint"
      | "dprint" = "oxlint"
    let currentCommand = await resolveCommand(ctx.cwd, "oxlint", ["--format", "unix", "--", ...runPaths])

    try {
      setStatus(ctx, `running oxlint on ${describeFiles(runPaths)}`, "info")
      const oxlint = await lintFiles(ctx, runPaths, controller.signal)
      currentCommand = oxlint.command

      if (shuttingDown || controller.signal.aborted) return

      if (oxlint.result.code !== 0 || oxlint.result.killed) {
        setStatus(ctx, "oxlint failed", "error")
        queuePrivateRepair(ctx, {
          stage: "oxlint",
          command: oxlint.command,
          paths: runPaths,
          result: oxlint.result,
        })
        return
      }

      currentStage = "dprint"
      setStatus(ctx, `running dprint fmt on ${describeFiles(runPaths)}`, "info")
      const dprint = await formatFiles(ctx, runPaths, controller.signal)
      currentCommand = dprint.command

      if (shuttingDown || controller.signal.aborted) return

      if (dprint.result.code !== 0 || dprint.result.killed) {
        setStatus(ctx, "dprint fmt failed", "error")
        queuePrivateRepair(ctx, {
          stage: "dprint",
          command: dprint.command,
          paths: runPaths,
          result: dprint.result,
        })
        return
      }

      setStatus(ctx, `quality passed for ${describeFiles(runPaths)}`, "success")
    } catch (error) {
      if (shuttingDown || controller.signal.aborted) return

      setStatus(ctx, "quality command failed", "error")
      queuePrivateRepair(ctx, {
        stage: currentStage,
        command: currentCommand,
        paths: runPaths,
        error,
      })
    } finally {
      if (activeRun === controller) activeRun = undefined
      running = false
      if (!shuttingDown && pendingRepairs.length > 0 && ctx.isIdle()) void runPendingRepairs()
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    shuttingDown = false
    trackingAssistantTurn = false
    changedPaths.clear()
    pendingRepairs.length = 0

    setStatus(ctx, "watching assistant-turn file changes", "success")
    if (ctx.hasUI) ctx.ui.notify("Quality watcher: oxlint → dprint fmt after assistant turns", "info")
  })

  pi.on("agent_start", async (_event, ctx) => {
    trackingAssistantTurn = true
    changedPaths.clear()
    setStatus(ctx, "tracking changed files for this assistant turn", "info")
  })

  pi.on("tool_result", (event, ctx) => {
    if (!trackingAssistantTurn || event.isError) return

    const changedPath = changedPathFromPiWrite(ctx, event)
    if (changedPath === undefined) return

    changedPaths.add(changedPath)
    setStatus(ctx, `tracked ${describeFiles([...changedPaths])}`, "info")
  })

  pi.on("agent_end", async (_event, ctx) => {
    trackingAssistantTurn = false
    const runPaths = [...changedPaths]
    changedPaths.clear()

    if (runPaths.length > 0) {
      await runQualityCheck(ctx, runPaths)
      return
    }

    if (!shuttingDown && pendingRepairs.length > 0) void runPendingRepairs()
  })

  pi.on("session_shutdown", async (_event, ctx) => {
    shuttingDown = true
    trackingAssistantTurn = false
    changedPaths.clear()
    pendingRepairs.length = 0
    activeRun?.abort()
    activeRun = undefined
    if (ctx.hasUI) ctx.ui.setStatus(EXTENSION_ID, undefined)
  })
}
