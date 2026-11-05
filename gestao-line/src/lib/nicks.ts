// Associação do nick lido no print com o elenco.
// norm, quase, semTag e quaseNick copiados do Battle Hub (supabase/functions/_shared/campeonato.ts):
// tratam tags, letras estilizadas/pequenas e uma letra lida errada.

// letras pequenas (ᴀʙᴄ…) que o NFKC não converte
const SMALL: Record<string, string> = { 'ᴀ': 'a', 'ʙ': 'b', 'ᴄ': 'c', 'ᴅ': 'd', 'ᴇ': 'e', 'ꜰ': 'f', 'ɢ': 'g', 'ʜ': 'h', 'ɪ': 'i', 'ᴊ': 'j', 'ᴋ': 'k', 'ʟ': 'l', 'ᴍ': 'm',
  'ɴ': 'n', 'ᴏ': 'o', 'ᴘ': 'p', 'ǫ': 'q', 'ʀ': 'r', 'ꜱ': 's', 'ᴛ': 't', 'ᴜ': 'u', 'ᴠ': 'v', 'ᴡ': 'w', 'ʏ': 'y', 'ᴢ': 'z', 'ø': 'o', 'Ø': 'o' };
// letras estilizadas e símbolos somem: "ᴿᴰᴺ丶Kaio" → "rdnkaio" (丶, ツ, 乂 e outros enfeites de nick também saem)
export const norm = (s: string | null | undefined) =>
  String(s || '').normalize('NFKC').replace(/./gu, (c) => SMALL[c] || c).toLowerCase()
    .replace(/[\p{Script=Han}\p{Script=Katakana}\p{Script=Hiragana}]/gu, '').replace(/[^\p{L}\p{N}]/gu, '');

// uma letra trocada, sobrando ou faltando (a IA às vezes lê "O" como "D" em print pequeno): só para nicks de 5+ letras
export function quase(a: string, b: string) {
  if (Math.min(a.length, b.length) < 5 || Math.abs(a.length - b.length) > 1) return false;
  let i = 0, j = 0, dif = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) { i++; j++; continue; }
    if (++dif > 1) return false;
    if (a.length > b.length) i++; else if (b.length > a.length) j++; else { i++; j++; }
  }
  return dif + (a.length - i) + (b.length - j) <= 1;
}
// o nick sem a tag: a última palavra ("PDI MDZIN⁷⁷⁷" → "mdzin777")
export const semTag = (x: string | null | undefined) => norm(String(x || '').trim().split(/\s+/).pop());
// tolerante: uma letra de diferença no nick inteiro ou só no nick sem a tag
export const quaseNick = (seen: string, nick: string | null | undefined) => !!nick && (quase(norm(seen), norm(nick)) || quase(semTag(seen), semTag(nick)));

export type Candidato = { id: string; nick: string; apelidos_leitura: string[] };

// 3 = igual (com ou sem a tag da line), 2 = um contém o outro (print cortado/sufixo), 1 = uma letra de diferença, 0 = não
export function parecido(seen: string, nome: string, tag?: string | null): number {
  const a = norm(seen), b = norm(nome);
  if (!a || !b) return 0;
  const t = norm(tag);
  const strip = (x: string) => (t && x.startsWith(t) && x.length > t.length ? x.slice(t.length) : x);
  const a2 = strip(a), b2 = strip(b);
  if (a === b || a2 === b2) return 3;
  const [s, l] = a2.length <= b2.length ? [a2, b2] : [b2, a2];
  if (s.length >= 4 && l.includes(s)) return 2;
  if (quase(a, b) || quase(a2, b2) || quaseNick(seen, nome)) return 1;
  return 0;
}

// Liga cada nick lido a um jogador do elenco. Só associa sozinho quando é seguro:
// a melhor nota é única (ninguém empata) e o jogador não foi usado por outro nick do mesmo print.
// O que sobra volta como null, e a tela pergunta "Quem é este?".
export function associar(lidos: string[], elenco: Candidato[], tag?: string | null): (string | null)[] {
  const notas = lidos.map((seen) => elenco.map((j) => Math.max(parecido(seen, j.nick, tag), ...j.apelidos_leitura.map((ap) => parecido(seen, ap, tag)), 0)));
  const res: (string | null)[] = lidos.map(() => null);
  const usado = new Set<string>();
  // primeiro os pares mais certos, para um nick parecido não "roubar" o jogador de um nick exato
  const pares: { i: number; j: number; n: number }[] = [];
  notas.forEach((linha, i) => linha.forEach((n, j) => { if (n > 0) pares.push({ i, j, n }); }));
  pares.sort((x, y) => y.n - x.n);
  for (const { i, j, n } of pares) {
    if (res[i] !== null || usado.has(elenco[j].id)) continue;
    const empatados = notas[i].filter((m, k) => m === n && !usado.has(elenco[k].id)).length;
    if (empatados > 1) continue; // dois jogadores do elenco servem: pergunta
    res[i] = elenco[j].id;
    usado.add(elenco[j].id);
  }
  return res;
}
