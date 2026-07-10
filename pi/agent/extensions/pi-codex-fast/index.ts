import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import {
    type ExtensionAPI,
    type ExtensionContext,
    type ReadonlyFooterDataProvider,
    type Theme,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const STATUS_KEY = "fast-priority";
const SETTINGS_KEY = "pi-codex-fast";
const PRIORITY_MODELS = ["openai-codex/gpt-5.4", "openai-codex/gpt-5.5"];
const PRIORITY_MODEL_LABEL = PRIORITY_MODELS.join(" or ");
const FAST_LABEL = "(fast)";

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function currentModelName(ctx: ExtensionContext): string | undefined {
    return ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined;
}

function supportsPriorityServiceTier(ctx: ExtensionContext): boolean {
    const modelName = currentModelName(ctx);
    return modelName !== undefined && PRIORITY_MODELS.includes(modelName);
}

function asObject(value: unknown): Record<string, unknown> | null {
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    return value as Record<string, unknown>;
}

function sanitizeStatusText(text: string): string {
    return text
        .replace(/[\r\n\t]/g, " ")
        .replace(/ +/g, " ")
        .trim();
}

function formatTokens(count: number): string {
    if (count < 1000) return count.toString();
    if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
    if (count < 1000000) return `${Math.round(count / 1000)}k`;
    if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
    return `${Math.round(count / 1000000)}M`;
}

function formatCwdForFooter(cwd: string, home: string | undefined): string {
    if (!home) return cwd;

    const resolvedCwd = resolve(cwd);
    const resolvedHome = resolve(home);
    const relativeToHome = relative(resolvedHome, resolvedCwd);
    const isInsideHome =
        relativeToHome === "" ||
        (relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));

    if (!isInsideHome) return cwd;
    return relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`;
}

function globalSettingsPath(): string {
    return join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), "settings.json");
}

function projectSettingsPath(cwd: string): string {
    return join(cwd, ".pi", "settings.json");
}

async function readSettings(path: string): Promise<Record<string, unknown>> {
    try {
        const content = await readFile(path, "utf8");
        const settings = JSON.parse(content);
        return isRecord(settings) ? settings : {};
    } catch (error) {
        if (isRecord(error) && error.code === "ENOENT") return {};
        throw error;
    }
}

function mergeSettings(base: Record<string, unknown>, overrides: Record<string, unknown>): Record<string, unknown> {
    const merged: Record<string, unknown> = { ...base };
    for (const [key, overrideValue] of Object.entries(overrides)) {
        const baseValue = merged[key];
        if (isRecord(baseValue) && isRecord(overrideValue)) {
            merged[key] = mergeSettings(baseValue, overrideValue);
            continue;
        }
        merged[key] = overrideValue;
    }
    return merged;
}

async function loadPersistedFastMode(cwd: string): Promise<boolean | undefined> {
    const settings = mergeSettings(
        await readSettings(globalSettingsPath()),
        await readSettings(projectSettingsPath(cwd)),
    );
    const extensionSettings = asObject(settings[SETTINGS_KEY]);
    return typeof extensionSettings?.enabled === "boolean" ? extensionSettings.enabled : undefined;
}

async function persistFastMode(enabled: boolean): Promise<void> {
    const path = globalSettingsPath();
    const globalSettings = await readSettings(path);
    const extensionSettings = asObject(globalSettings[SETTINGS_KEY]) ?? {};
    globalSettings[SETTINGS_KEY] = {
        ...extensionSettings,
        enabled,
    };
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, `${JSON.stringify(globalSettings, null, 2)}\n`);
}

function renderFastFooter(
    ctx: ExtensionContext,
    pi: ExtensionAPI,
    theme: Theme,
    footerData: ReadonlyFooterDataProvider,
    width: number,
): string[] {
    let totalInput = 0;
    let totalOutput = 0;
    let totalCacheRead = 0;
    let totalCacheWrite = 0;
    let totalCost = 0;

    for (const entry of ctx.sessionManager.getEntries()) {
        if (entry.type === "message" && entry.message.role === "assistant") {
            totalInput += entry.message.usage.input;
            totalOutput += entry.message.usage.output;
            totalCacheRead += entry.message.usage.cacheRead;
            totalCacheWrite += entry.message.usage.cacheWrite;
            totalCost += entry.message.usage.cost.total;
        }
    }

    const contextUsage = ctx.getContextUsage();
    const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
    const contextPercentValue = contextUsage?.percent ?? 0;
    const contextPercent = contextUsage?.percent !== null ? contextPercentValue.toFixed(1) : "?";

    let pwd = formatCwdForFooter(ctx.sessionManager.getCwd(), process.env.HOME || process.env.USERPROFILE);

    const branch = footerData.getGitBranch();
    if (branch) {
        pwd = `${pwd} (${branch})`;
    }

    const sessionName = ctx.sessionManager.getSessionName();
    if (sessionName) {
        pwd = `${pwd} • ${sessionName}`;
    }

    const statsParts: string[] = [];
    if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
    if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
    if (totalCacheRead) statsParts.push(`R${formatTokens(totalCacheRead)}`);
    if (totalCacheWrite) statsParts.push(`W${formatTokens(totalCacheWrite)}`);

    const usingSubscription = ctx.model ? ctx.modelRegistry.isUsingOAuth(ctx.model) : false;
    if (totalCost || usingSubscription) {
        statsParts.push(`$${totalCost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`);
    }

    let contextPercentStr: string;
    const autoIndicator = " (auto)";
    const contextPercentDisplay =
        contextPercent === "?"
            ? `?/${formatTokens(contextWindow)}${autoIndicator}`
            : `${contextPercent}%/${formatTokens(contextWindow)}${autoIndicator}`;
    if (contextPercentValue > 90) {
        contextPercentStr = theme.fg("error", contextPercentDisplay);
    } else if (contextPercentValue > 70) {
        contextPercentStr = theme.fg("warning", contextPercentDisplay);
    } else {
        contextPercentStr = contextPercentDisplay;
    }
    statsParts.push(contextPercentStr);

    let statsLeft = statsParts.join(" ");
    let statsLeftWidth = visibleWidth(statsLeft);
    if (statsLeftWidth > width) {
        statsLeft = truncateToWidth(statsLeft, width, "...");
        statsLeftWidth = visibleWidth(statsLeft);
    }

    const modelName = `${ctx.model?.id || "no-model"} ${FAST_LABEL}`;
    let rightSideWithoutProvider = modelName;
    if (ctx.model?.reasoning) {
        const thinkingLevel = pi.getThinkingLevel() || "off";
        rightSideWithoutProvider =
            thinkingLevel === "off" ? `${modelName} • thinking off` : `${modelName} • ${thinkingLevel}`;
    }

    const minPadding = 2;
    let rightSide = rightSideWithoutProvider;
    if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
        rightSide = `(${ctx.model.provider}) ${rightSideWithoutProvider}`;
        if (statsLeftWidth + minPadding + visibleWidth(rightSide) > width) {
            rightSide = rightSideWithoutProvider;
        }
    }

    const rightSideWidth = visibleWidth(rightSide);
    const totalNeeded = statsLeftWidth + minPadding + rightSideWidth;

    let statsLine: string;
    if (totalNeeded <= width) {
        const padding = " ".repeat(width - statsLeftWidth - rightSideWidth);
        statsLine = statsLeft + padding + rightSide;
    } else {
        const availableForRight = width - statsLeftWidth - minPadding;
        if (availableForRight > 0) {
            const truncatedRight = truncateToWidth(rightSide, availableForRight, "");
            const truncatedRightWidth = visibleWidth(truncatedRight);
            const padding = " ".repeat(Math.max(0, width - statsLeftWidth - truncatedRightWidth));
            statsLine = statsLeft + padding + truncatedRight;
        } else {
            statsLine = statsLeft;
        }
    }

    const dimStatsLeft = theme.fg("dim", statsLeft);
    const remainder = statsLine.slice(statsLeft.length);
    const dimRemainder = theme.fg("dim", remainder);

    const lines = [
        truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "...")),
        dimStatsLeft + dimRemainder,
    ];

    const extensionStatuses = footerData.getExtensionStatuses();
    if (extensionStatuses.size > 0) {
        const statusLine = Array.from(extensionStatuses.entries())
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([, text]) => sanitizeStatusText(text))
            .join(" ");
        lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
    }

    return lines;
}

export default function codexFastExtension(pi: ExtensionAPI): void {
    let fastModeEnabled = false;
    let fastFooterInstalled = false;
    let settingsWriteQueue: Promise<void> = Promise.resolve();

    function persistState(enabled: boolean, ctx: ExtensionContext): void {
        settingsWriteQueue = settingsWriteQueue
            .catch(() => undefined)
            .then(() => persistFastMode(enabled));

        void settingsWriteQueue.catch((error) => {
            if (!ctx.hasUI) return;
            const message = error instanceof Error ? error.message : String(error);
            ctx.ui.notify(`pi-codex-fast: failed to write settings: ${message}`, "warning");
        });
    }

    function restoreDefaultFooter(ctx: ExtensionContext): void {
        if (!ctx.hasUI || !fastFooterInstalled) return;
        ctx.ui.setFooter(undefined);
        fastFooterInstalled = false;
    }

    function installFastFooter(ctx: ExtensionContext): void {
        if (!ctx.hasUI) return;
        ctx.ui.setFooter((tui, theme, footerData) => {
            const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
            return {
                dispose: unsubscribe,
                invalidate() {},
                render(width: number): string[] {
                    return renderFastFooter(ctx, pi, theme, footerData, width);
                },
            };
        });
        fastFooterInstalled = true;
    }

    function updateUI(ctx: ExtensionContext): void {
        if (!ctx.hasUI) return;

        if (!fastModeEnabled) {
            ctx.ui.setStatus(STATUS_KEY, undefined);
            restoreDefaultFooter(ctx);
            return;
        }

        if (supportsPriorityServiceTier(ctx)) {
            ctx.ui.setStatus(STATUS_KEY, undefined);
            installFastFooter(ctx);
            return;
        }

        restoreDefaultFooter(ctx);
        ctx.ui.setStatus(STATUS_KEY, ctx.ui.theme.fg("accent", "fast (inactive)"));
    }

    function notifyState(ctx: ExtensionContext): void {
        if (!ctx.hasUI) return;
        if (!fastModeEnabled) {
            ctx.ui.notify("Fast mode disabled. Requests will use the default service tier.", "info");
            return;
        }

        if (supportsPriorityServiceTier(ctx)) {
            ctx.ui.notify(`Fast mode enabled. ${PRIORITY_MODEL_LABEL} requests will send service_tier=priority.`, "info");
            return;
        }

        const modelLabel = currentModelName(ctx) ?? "no active model";
        ctx.ui.notify(
            `Fast mode enabled, but inactive for ${modelLabel}. Switch to ${PRIORITY_MODEL_LABEL} to use it.`,
            "info",
        );
    }

    function setFastMode(enabled: boolean, ctx: ExtensionContext, options?: { persist?: boolean; notify?: boolean }): void {
        fastModeEnabled = enabled;
        if (options?.persist !== false) persistState(enabled, ctx);
        updateUI(ctx);
        if (options?.notify !== false) notifyState(ctx);
    }

    async function reloadFastModeState(ctx: ExtensionContext, options?: { includeStartupFlag?: boolean }): Promise<void> {
        fastModeEnabled = false;

        try {
            const persistedEnabled = await loadPersistedFastMode(ctx.cwd);
            if (typeof persistedEnabled === "boolean") {
                fastModeEnabled = persistedEnabled;
            }
        } catch (error) {
            if (ctx.hasUI) {
                const message = error instanceof Error ? error.message : String(error);
                ctx.ui.notify(`pi-codex-fast: failed to load settings: ${message}`, "warning");
            }
        }

        if (options?.includeStartupFlag && pi.getFlag("fast") === true) {
            fastModeEnabled = true;
        }

        updateUI(ctx);
    }

    pi.registerFlag("fast", {
        description: `Start with fast mode enabled (adds service_tier=priority to ${PRIORITY_MODEL_LABEL} requests)`,
        type: "boolean",
        default: false,
    });

    pi.registerCommand("codex-fast", {
        description: `Toggle ${PRIORITY_MODEL_LABEL} priority service tier`,
        handler: async (_args, ctx) => {
            setFastMode(!fastModeEnabled, ctx);
        },
    });

    pi.on("session_start", async (_event, ctx) => {
        await reloadFastModeState(ctx, { includeStartupFlag: true });
    });

    pi.on("model_select", async (_event, ctx) => {
        updateUI(ctx);
    });

    pi.on("thinking_level_select", async (_event, ctx) => {
        updateUI(ctx);
    });

    pi.on("session_shutdown", async (_event, ctx) => {
        if (!ctx.hasUI) return;
        ctx.ui.setStatus(STATUS_KEY, undefined);
        restoreDefaultFooter(ctx);
    });

    pi.on("before_provider_request", (event, ctx) => {
        if (!fastModeEnabled || !supportsPriorityServiceTier(ctx) || !isRecord(event.payload)) {
            return;
        }

        return {
            ...event.payload,
            service_tier: "priority",
        };
    });
}
