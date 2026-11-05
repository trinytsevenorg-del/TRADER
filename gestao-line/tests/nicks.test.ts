import { describe, expect, it } from 'vitest';
import { associar, norm } from '../src/lib/nicks';

const elenco = [
  { id: 'a', nick: 'Kaio', apelidos_leitura: [] },
  { id: 'b', nick: 'MDZIN777', apelidos_leitura: [] },
  { id: 'c', nick: 'Lipan', apelidos_leitura: ['╰ᴼᴰ╯✿Lɪᴘᴀɴ࿐'] },
  { id: 'd', nick: 'Shadow', apelidos_leitura: [] },
];

describe('associação dos nicks', () => {
  it('ignora tag e letras estilizadas', () => {
    expect(norm('ᴿᴰᴺ丶Kaio')).toBe('rdnkaio');
    expect(associar(['RDN丶Kaio', 'PDI MDZIN⁷⁷⁷'], elenco, 'RDN')).toEqual(['a', 'b']);
  });
  it('usa os apelidos de leitura', () => {
    expect(associar(['╰ᴼᴰ╯✿Lɪᴘᴀɴ࿐'], elenco)).toEqual(['c']);
  });
  it('aceita uma letra lida errada', () => {
    expect(associar(['RDN Shadcw'], elenco, 'RDN')).toEqual(['d']);
  });
  it('não associa o desconhecido nem repete jogador', () => {
    expect(associar(['Zé Ninguém', 'RDN丶Kaio', 'Kaio'], elenco, 'RDN')).toEqual([null, 'a', null]);
  });
  it('pergunta quando dois do elenco servem', () => {
    const e2 = [{ id: 'x', nick: 'Shadow1', apelidos_leitura: [] }, { id: 'y', nick: 'Shadow2', apelidos_leitura: [] }];
    expect(associar(['Shadow'], e2)).toEqual([null]);
  });
});
