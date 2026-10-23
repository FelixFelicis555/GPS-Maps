// Proxies Sarvam AI (text translation, speech-to-text, text-to-speech) so the
// Sarvam key stays server-side.
//
// Secret (never in the app):  supabase secrets set SARVAM_API_KEY=...
// Deploy:                     supabase functions deploy sarvam
//
// Requests (all POST):
//   JSON      { op: "translate", text, from, to }   from = Sarvam code or "auto"
//             -> { text, detected }
//   JSON      { op: "tts", text, lang }
//             -> { audio }  (base64 WAV)
//   multipart op=stt, file=<audio>, lang=<Sarvam code | "unknown">
//             -> { transcript, language }
// Errors: { error: "<message>" } with a non-200 status.

const BASE = "https://api.sarvam.ai";

// mayura:v1 handles these 11 (and auto-detection); sarvam-translate:v1 covers
// the rest of the scheduled Indian languages but needs an explicit source.
const MAYURA = new Set([
  "bn-IN", "en-IN", "gu-IN", "hi-IN", "kn-IN", "ml-IN",
  "mr-IN", "od-IN", "pa-IN", "ta-IN", "te-IN",
]);
const TRANSLATE_ONLY = new Set([
  "as-IN", "brx-IN", "doi-IN", "kok-IN", "ks-IN", "mai-IN",
  "mni-IN", "ne-IN", "sa-IN", "sat-IN", "sd-IN", "ur-IN",
]);
const TTS_LANGS = MAYURA; // bulbul supports the same 11

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

async function upstreamError(res: Response) {
  let message = `sarvam_${res.status}`;
  try {
    const j = await res.json();
    message = j?.error?.message ?? message;
  } catch { /* keep default */ }
  // Pass quota/auth problems through; everything else is a bad gateway.
  const status = [400, 403, 422, 429].includes(res.status) ? res.status : 502;
  return json({ error: message }, status);
}

async function translate(key: string, b: Record<string, unknown>) {
  const text = typeof b.text === "string" ? b.text : "";
  const from = typeof b.from === "string" ? b.from : "auto";
  const to = typeof b.to === "string" ? b.to : "";
  if (!text.trim() || !to) return json({ error: "invalid_request" }, 400);

  const known = (c: string) => MAYURA.has(c) || TRANSLATE_ONLY.has(c);
  if (!known(to) || (from !== "auto" && !known(from))) {
    return json({ error: "unsupported_language" }, 422);
  }
  const useMayura = MAYURA.has(to) && (from === "auto" || MAYURA.has(from));
  if (!useMayura && from === "auto") {
    // sarvam-translate:v1 cannot auto-detect the source.
    return json({ error: "unsupported_language" }, 422);
  }
  const limit = useMayura ? 1000 : 2000;
  if (text.length > limit) return json({ error: "text_too_long" }, 413);

  const res = await fetch(`${BASE}/translate`, {
    method: "POST",
    headers: {
      "api-subscription-key": key,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      input: text,
      source_language_code: from,
      target_language_code: to,
      model: useMayura ? "mayura:v1" : "sarvam-translate:v1",
      mode: "formal",
    }),
  });
  if (!res.ok) return upstreamError(res);
  const j = await res.json();
  return json({ text: j.translated_text, detected: j.source_language_code });
}

async function tts(key: string, b: Record<string, unknown>) {
  const text = typeof b.text === "string" ? b.text.slice(0, 2500) : "";
  const lang = typeof b.lang === "string" ? b.lang : "";
  if (!text.trim() || !TTS_LANGS.has(lang)) {
    return json({ error: "unsupported_language" }, 422);
  }
  const res = await fetch(`${BASE}/text-to-speech`, {
    method: "POST",
    headers: {
      "api-subscription-key": key,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      text,
      language_code: lang,
      model: "bulbul:v3",
      output_audio_codec: "wav",
    }),
  });
  if (!res.ok) return upstreamError(res);
  const j = await res.json();
  const audio = Array.isArray(j.audios) ? j.audios[0] : null;
  if (!audio) return json({ error: "no_audio" }, 502);
  return json({ audio });
}

async function stt(key: string, form: FormData) {
  const file = form.get("file");
  const lang = typeof form.get("lang") === "string"
    ? (form.get("lang") as string)
    : "unknown";
  if (!(file instanceof File)) return json({ error: "invalid_request" }, 400);
  if (lang !== "unknown" && !MAYURA.has(lang) && !TRANSLATE_ONLY.has(lang)) {
    return json({ error: "unsupported_language" }, 422);
  }
  const out = new FormData();
  out.append("file", file, file.name || "audio.m4a");
  out.append("language_code", lang);
  out.append("mode", "transcribe");
  const res = await fetch(`${BASE}/speech-to-text`, {
    method: "POST",
    headers: { "api-subscription-key": key },
    body: out,
  });
  if (!res.ok) return upstreamError(res);
  const j = await res.json();
  return json({ transcript: j.transcript ?? "", language: j.language_code });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const key = Deno.env.get("SARVAM_API_KEY");
  if (!key) return json({ error: "server_not_configured" }, 500);

  try {
    const type = req.headers.get("content-type") ?? "";
    if (type.includes("multipart/form-data")) {
      const form = await req.formData();
      if (form.get("op") !== "stt") return json({ error: "invalid_op" }, 400);
      return await stt(key, form);
    }
    const body = (await req.json()) as Record<string, unknown>;
    if (body.op === "translate") return await translate(key, body);
    if (body.op === "tts") return await tts(key, body);
    return json({ error: "invalid_op" }, 400);
  } catch {
    return json({ error: "bad_request" }, 400);
  }
});
