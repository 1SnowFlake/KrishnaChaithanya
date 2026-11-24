// ============================================================
// Free AI Provider Layer (OpenAI-Compatible Multi-Provider Fallback)
//
// Built strictly for FREE tier providers that require NO credit card:
// 1. Groq (Primary): Llama 3.3 70B (30 RPM, 14,400 RPD free)
//    Limits: https://console.groq.com/docs/rate-limits
// 2. Gemini (Secondary): Gemini 1.5 Flash via OpenAI endpoint (15 RPM, 1,500 RPD free)
//    Limits: https://ai.google.dev/pricing
// 3. OpenRouter (Tertiary Fallback): Free rotating models (20 RPM free)
//    Limits: https://openrouter.ai/models?max_price=0
// ============================================================

export interface FreeAiProviderConfig {
  id: "groq" | "gemini" | "openrouter";
  name: string;
  baseUrl: string;
  model: string;
  secretName: string;
  priority: number;
  limitsLookupUrl: string;
  notes: string;
}

/**
 * Single source of truth for free models.
 * Update model names here when provider free tiers evolve.
 */
export const FREE_AI_PROVIDERS: FreeAiProviderConfig[] = [
  {
    id: "groq",
    name: "Groq (Llama 3.3 70B Versatile)",
    baseUrl: "https://api.groq.com/openai/v1",
    model: "llama-3.3-70b-versatile",
    secretName: "GROQ_API_KEY",
    priority: 1,
    limitsLookupUrl: "https://console.groq.com/docs/rate-limits",
    notes: "Primary: Sub-second inference, strict structured JSON, zero cost.",
  },
  {
    id: "gemini",
    name: "Google Gemini 1.5 Flash (OpenAI Endpoint)",
    baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai",
    model: "gemini-1.5-flash",
    secretName: "GEMINI_API_KEY",
    priority: 2,
    limitsLookupUrl: "https://ai.google.dev/pricing",
    notes: "Secondary: High multilingual fluency for Hindi, Kannada, etc.",
  },
  {
    id: "openrouter",
    name: "OpenRouter (Free Model Router)",
    baseUrl: "https://openrouter.ai/api/v1",
    model: "meta-llama/llama-3.2-3b-instruct:free",
    secretName: "OPENROUTER_API_KEY",
    priority: 3,
    limitsLookupUrl: "https://openrouter.ai/models?max_price=0",
    notes: "Last Fallback: Automatic routing across community free endpoints.",
  },
];

export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface CompletionResult {
  content: string;
  provider: "groq" | "gemini" | "openrouter";
  model: string;
  tokensEstimate: number;
  attempts: Array<{ provider: string; status: string; error?: string }>;
}

/**
 * Universal OpenAI-compatible chat completion client with automatic failover.
 * Tries providers in order of priority. If a provider returns 429 (rate-limit),
 * 5xx (server error), or times out, it automatically fails over to the next provider.
 */
export async function executeAiCompletionWithFallback(
  messages: ChatMessage[],
  options: {
    temperature?: number;
    responseFormatJson?: boolean;
    timeoutMs?: number;
  } = {},
): Promise<CompletionResult> {
  const temperature = options.temperature ?? 0.2;
  const timeoutMs = options.timeoutMs ?? 25000;
  const attempts: Array<{ provider: string; status: string; error?: string }> = [];

  for (const provider of FREE_AI_PROVIDERS) {
    const apiKey = Deno.env.get(provider.secretName);

    if (!apiKey || apiKey.trim() === "") {
      attempts.push({
        provider: provider.id,
        status: "skipped_no_key",
        error: `Secret ${provider.secretName} is not configured`,
      });
      continue;
    }

    const controller = new AbortController();
    const timeoutTimer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey.trim()}`,
      };

      // OpenRouter recommends attribution headers
      if (provider.id === "openrouter") {
        headers["HTTP-Referer"] = "https://slkc.school";
        headers["X-Title"] = "SLKC Special Education Assistant";
      }

      const bodyPayload: Record<string, unknown> = {
        model: provider.model,
        messages,
        temperature,
      };

      if (options.responseFormatJson) {
        bodyPayload["response_format"] = { type: "json_object" };
      }

      const response = await fetch(`${provider.baseUrl}/chat/completions`, {
        method: "POST",
        headers,
        body: JSON.stringify(bodyPayload),
        signal: controller.signal,
      });

      clearTimeout(timeoutTimer);

      if (!response.ok) {
        const errorText = await response.text();
        const status = response.status;
        console.warn(
          `[AI-Fallback] Provider ${provider.id} failed with status ${status}: ${errorText.slice(0, 150)}`,
        );

        attempts.push({
          provider: provider.id,
          status: status === 429 ? "rate_limited" : `http_${status}`,
          error: errorText.slice(0, 200),
        });

        // Failover to next provider on rate-limit (429) or server errors (500, 502, 503, 504)
        if (status === 429 || (status >= 500 && status < 600)) {
          continue;
        }

        // For other 4xx errors, also try next provider
        continue;
      }

      const data = await response.json();
      const choice = data.choices?.[0];
      const content = choice?.message?.content ?? "";

      if (!content || content.trim() === "") {
        attempts.push({
          provider: provider.id,
          status: "empty_response",
          error: "Model returned empty content",
        });
        continue;
      }

      const tokensEstimate =
        data.usage?.total_tokens ??
        Math.ceil((messages.map((m) => m.content).join(" ").length + content.length) / 4);

      attempts.push({ provider: provider.id, status: "success" });

      return {
        content: content.trim(),
        provider: provider.id,
        model: provider.model,
        tokensEstimate,
        attempts,
      };
    } catch (err: unknown) {
      clearTimeout(timeoutTimer);
      const isAbort = err instanceof DOMException && err.name === "AbortError";
      const errMsg = isAbort ? `Timed out after ${timeoutMs}ms` : (err as Error).message;

      console.warn(`[AI-Fallback] Exception calling ${provider.id}: ${errMsg}`);
      attempts.push({
        provider: provider.id,
        status: isAbort ? "timeout" : "network_exception",
        error: errMsg,
      });

      // Continue to next provider in fallback chain
      continue;
    }
  }

  // If we reach here, all configured providers failed
  const failedSummary = attempts.map((a) => `${a.provider}: ${a.status}`).join("; ");
  throw new Error(
    `AI generation services are currently busy or reached free quotas (${failedSummary}). Please try again in a few moments.`,
  );
}
