// ============================================================
// Safety, Content Filtering & Prompt Injection Defense
// ============================================================

/**
 * Normalizes and sanitizes user free-text inputs.
 * Strips prompt-injection attempts, enforces character length caps,
 * and escapes markdown/control delimiters.
 */
export function sanitizeInput(input: string | undefined | null, maxChars = 300): string {
  if (!input) return "";

  let cleaned = input
    .trim()
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "") // Remove control characters
    .replace(/```/g, "'''")                                          // Escape code fence delimiters
    .slice(0, maxChars);

  return cleaned;
}

/**
 * Checks for prohibited, unsafe, or inappropriate special-education topics.
 * Returns null if safe, or a user-friendly refusal message if unsafe.
 */
export function checkContentSafety(text: string): string | null {
  const lower = text.toLowerCase();

  const blockedPatterns = [
    /\b(kill|murder|suicide|self-harm|bomb|weapon|terror|gun|shooting)\b/,
    /\b(porn|erotic|sex|nsfw|xxx|strip)\b/,
    /\b(drugs|cocaine|heroin|meth|weed|alcohol)\b/,
    /\b(system\s*prompt|ignore\s*previous\s*instructions|jailbreak|DAN\s*mode)\b/,
  ];

  for (const pattern of blockedPatterns) {
    if (pattern.test(lower)) {
      return "This topic cannot be generated because it contains unsafe or inappropriate educational content. Please enter a safe curriculum topic.";
    }
  }

  return null;
}

/**
 * Wraps untrusted user fields inside clearly delimited tags
 * to prevent prompt injection breakouts.
 */
export function wrapInUntrustedTags(tag: string, content: string): string {
  const safe = sanitizeInput(content);
  return `<${tag}>\n${safe}\n</${tag}>`;
}
