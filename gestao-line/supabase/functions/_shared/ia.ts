// Copiado sem mudanças do Battle Hub (projeto tjaqjirsayclexzaycti, supabase/functions/_shared/ia.ts).
// IA que lê imagens (prints do Free Fire). Usa o Claude quando existe ANTHROPIC_API_KEY; sem ela, o Gemini do Google
// (GEMINI_API_KEY, plano gratuito sem cartão). Quando a chave da Anthropic for colocada, volta para o Claude sozinho.
// As duas devolvem o mesmo objeto (o "input" da ferramenta), então quem chama não muda nada.
import Anthropic from 'npm:@anthropic-ai/sdk';

export type Tool = { name: string; description?: string; input_schema: Record<string, unknown> };
export type Pergunta = { system: string; tool: Tool; image: ArrayBuffer; media: string; text: string; maxTokens: number; pensar?: boolean };

export class IaError extends Error {}
// modelos do Gemini que atingiram o limite do plano (429) e até quando ficam de fora
const cheio = new Map<string, number>();

export const iaLigada = () => !!(Deno.env.get('ANTHROPIC_API_KEY') || Deno.env.get('GEMINI_API_KEY'));
export const iaNome = () => (Deno.env.get('ANTHROPIC_API_KEY') ? 'claude' : Deno.env.get('GEMINI_API_KEY') ? 'gemini' : '');

function toBase64(buf: ArrayBuffer) {
  const b = new Uint8Array(buf); let s = '';
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000));
  return btoa(s);
}
const MEDIA = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

// deno-lint-ignore no-explicit-any
export async function perguntar(p: Pergunta): Promise<any> {
  const media = MEDIA.includes(p.media) ? p.media : 'image/jpeg';
  const data = toBase64(p.image);
  const claude = Deno.env.get('ANTHROPIC_API_KEY');
  if (claude) {
    try {
      const res = await new Anthropic({ apiKey: claude }).messages.create({
        model: Deno.env.get('ANTHROPIC_MODEL') || 'claude-haiku-5-5',
        max_tokens: p.maxTokens,
        system: p.system,
        // deno-lint-ignore no-explicit-any
        tools: [p.tool as any],
        tool_choice: { type: 'tool', name: p.tool.name },
        messages: [{ role: 'user', content: [
          // deno-lint-ignore no-explicit-any
          { type: 'image', source: { type: 'base64', media_type: media as any, data } },
          { type: 'text', text: p.text },
        ] }],
      });
      // deno-lint-ignore no-explicit-any
      const t = res.content.find((c: any) => c.type === 'tool_use') as any;
      return t ? t.input : null;
    } catch (e) {
      throw new IaError(e instanceof Anthropic.APIError ? 'IA fora do ar (' + e.status + ')' : String(e));
    }
  }

  const gemini = Deno.env.get('GEMINI_API_KEY');
  if (!gemini) throw new IaError('IA desligada');
  // primeiro o modelo leve (lê print em ~2 s e acertou tudo nos testes); os maiores ficam de reserva.
  // Modelo que respondeu "limite atingido" (429) fica de fora por 10 minutos, em vez de esperar e tentar de novo toda vez.
  const modelos = [Deno.env.get('GEMINI_MODEL_RAPIDO') || 'gemini-flash-lite-latest', Deno.env.get('GEMINI_MODEL') || 'gemini-3.8-flash',
    ...(Deno.env.get('GEMINI_MODELS_RESERVA') || 'gemini-flash-latest').split(',').map((m) => m.trim()).filter(Boolean)]
    .filter((m, i, a) => a.indexOf(m) === i);
  const livres = modelos.filter((m) => !(cheio.get(m)! > Date.now()));
  const fila = livres.length ? livres : modelos;
  const base = Deno.env.get('GEMINI_API_BASE') || 'https://generativelanguage.googleapis.com/v1beta'; // GEMINI_API_BASE: só para os testes
  // o Gemini responde em JSON seguindo o mesmo formato da ferramenta do Claude
  const formato = 'Responda SOMENTE com um objeto JSON (sem texto antes ou depois) no formato deste JSON Schema:\n' + JSON.stringify(p.tool.input_schema);
  // pensar = false desliga o raciocínio de vez (modelo que não aceita volta ao padrão)
  const corpo = (pensar: boolean) => JSON.stringify({
    systemInstruction: { parts: [{ text: p.system + '\n\n' + formato }] },
    contents: [{ role: 'user', parts: [{ inlineData: { mimeType: media, data } }, { text: p.text }] }],
    generationConfig: { responseMimeType: 'application/json', temperature: 0, maxOutputTokens: Math.max(p.maxTokens, 1024),
      ...(pensar ? {} : { thinkingConfig: { thinkingBudget: 0 } }) },
  });
  // sem pedir nada sobre raciocínio (o modelo leve não pensa; nos testes não mudou o tempo)
  let semPensar = p.pensar === false, req = corpo(!semPensar);
  const LIMITE_MS = 40000; // cada tentativa; passando disso vai para o próximo modelo
  // pico de uso no Google (503) ou limite por minuto do plano gratuito (429): espera um pouco e tenta de novo
  let res!: Response, body: any; // deno-lint-ignore no-explicit-any
  for (const [i, model] of fila.entries()) {
    for (let tent = 0; ; tent++) {
      const t0 = Date.now();
      try {
        res = await fetch(`${base}/models/${model}:generateContent`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'x-goog-api-key': gemini }, body: req, signal: AbortSignal.timeout(LIMITE_MS) });
        body = await res.json().catch(() => ({}));
      } catch (_e) {
        console.log('IA', model, 'passou de', LIMITE_MS / 1000, 's');
        res = new Response(null, { status: 504 }); body = {};
        break;
      }
      console.log('IA', model, res.status, Date.now() - t0, 'ms');
      // modelo que não aceita desligar o raciocínio: tenta de novo do jeito padrão
      if (res.status === 400 && semPensar) { semPensar = false; req = corpo(true); continue; }
      if (res.status === 429) { cheio.set(model, Date.now() + 10 * 60 * 1000); if (i < fila.length - 1) break; }
      if ((res.status === 503 || res.status === 429) && tent < 1) { await new Promise((r) => setTimeout(r, 1500)); continue; }
      break;
    }
    if (res.ok || ![503, 429, 404, 504].includes(res.status)) break;
  }
  if (!res.ok) throw new IaError('IA fora do ar (' + res.status + (body?.error?.status ? ' ' + body.error.status : '') + ')');
  // deno-lint-ignore no-explicit-any
  const txt = (body?.candidates?.[0]?.content?.parts || []).map((x: any) => x.text || '').join('').trim();
  if (!txt) return null;
  try {
    return JSON.parse(txt.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, ''));
  } catch (_) {
    const m = txt.match(/\{[\s\S]*\}/);
    if (m) { try { return JSON.parse(m[0]); } catch (_) { /* cai no null */ } }
    return null;
  }
}
