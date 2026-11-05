// Os prints ficam só no celular de quem enviou (IndexedDB). Para o Supabase vão só os números.
const DB = 'gestao-line', STORE = 'prints';

function abrir(): Promise<IDBDatabase> {
  return new Promise((ok, falha) => {
    const r = indexedDB.open(DB, 1);
    r.onupgradeneeded = () => r.result.createObjectStore(STORE, { keyPath: 'hash' });
    r.onsuccess = () => ok(r.result);
    r.onerror = () => falha(r.error);
  });
}

export type PrintLocal = { hash: string; blob: Blob; evento_id: string; criado_em: number };

export async function guardarPrint(p: PrintLocal) {
  try {
    const db = await abrir();
    await new Promise<void>((ok, falha) => {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put(p);
      tx.oncomplete = () => ok();
      tx.onerror = () => falha(tx.error);
    });
  } catch { /* navegador sem IndexedDB (aba anônima): segue sem guardar a imagem */ }
}

export async function lerPrint(hash: string): Promise<PrintLocal | null> {
  try {
    const db = await abrir();
    return await new Promise((ok) => {
      const r = db.transaction(STORE).objectStore(STORE).get(hash);
      r.onsuccess = () => ok((r.result as PrintLocal) || null);
      r.onerror = () => ok(null);
    });
  } catch { return null; }
}
