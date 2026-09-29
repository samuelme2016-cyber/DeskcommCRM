// Aplica o schema (supabase/baseline.sql) no Supabase apontado pelo .env.local,
// sem precisar de `psql`. É o mesmo arquivo que o install.sh aplica na VPS.
//
//   node darkcom/aplicar-banco.mjs
//
// Só instala em banco VAZIO; num banco que já tem o schema, não faz nada.
import fs from "node:fs";
import path from "node:path";
import pg from "pg";

const raiz = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const env = {};
for (const linha of fs.readFileSync(path.join(raiz, ".env.local"), "utf8").split("\n")) {
  const m = linha.match(/^([A-Z0-9_]+)=(.*)$/);
  if (m) env[m[1]] = m[2];
}
const url = env.SUPABASE_DB_ADMIN_URL || env.SUPABASE_DB_URL;
if (!url) {
  console.error("✖ SUPABASE_DB_URL ausente no .env.local — rode darkcom/configurar-local.ps1");
  process.exit(1);
}

const client = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await client.connect();

const { rows } = await client.query(
  "select count(*)::int as n from information_schema.tables where table_schema='public' and table_name='organizations'",
);
const jaTem = rows[0].n > 0;
if (jaTem) {
  // Reaplicar exige continuar depois de cada "already exists" (o update.sh usa
  // psql SEM ON_ERROR_STOP). Numa query única o Postgres para no 1º erro e o
  // apêndice novo nunca rodaria — melhor recusar do que dizer que atualizou.
  console.log("✓ O banco já tem o schema. Nada feito.");
  console.log("  Para trazer mudanças de schema novas, aplique só os blocos novos do apêndice do baseline.sql.");
  await client.end();
  process.exit(0);
}
console.log("▶ Banco vazio — instalando o schema");

await client.query(`
  create extension if not exists vector with schema public;
  create extension if not exists citext with schema public;
  create extension if not exists pg_trgm with schema public;
`);
console.log("✓ extensões vector, citext, pg_trgm");

const sql = fs.readFileSync(path.join(raiz, "supabase", "baseline.sql"), "utf8");
const t0 = Date.now();
try {
  await client.query(sql);
  console.log(`✓ baseline.sql aplicado (${Math.round((Date.now() - t0) / 1000)}s)`);
} catch (e) {
  // Numa query única o Postgres desfaz tudo ao falhar: o banco volta a ficar vazio.
  console.error(`✖ Falhou ao aplicar o baseline (nada foi gravado): ${e.message}`);
  if (e.position) {
    const linha = sql.slice(0, Number(e.position)).split("\n").length;
    console.error(`  perto da linha ${linha} de supabase/baseline.sql`);
  }
  await client.end();
  process.exit(1);
}

const tabelas = await client.query(
  "select count(*)::int as n from information_schema.tables where table_schema='public'",
);
console.log(`✓ ${tabelas.rows[0].n} tabelas em public`);
await client.end();
