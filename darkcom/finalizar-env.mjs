// Completa o .env.local preenchido no Bloco de Notas: confere as chaves coladas,
// gera as chaves internas que faltarem, descobre o endereço do Session pooler
// testando conexão real e grava SUPABASE_DB_URL. NUNCA imprime segredo — só
// "ok", tamanhos e o host do pooler.
//
//   node darkcom/finalizar-env.mjs
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const arquivo = path.join(raiz, ".env.local");
const linhas = fs.readFileSync(arquivo, "utf8").replace(/^﻿/, "").split(/\r?\n/);
const env = {};
for (const l of linhas) {
  const m = l.match(/^([A-Z0-9_]+)=(.*)$/);
  if (m) env[m[1]] = m[2].trim();
}

const problemas = [];
const papelDoJwt = (v) => {
  try {
    return JSON.parse(Buffer.from(v.split(".")[1], "base64url").toString()).role;
  } catch {
    return null;
  }
};
const vazio = (v) => !v || /^(COLE_AQUI|DIGITE_AQUI)$/.test(v);

const anon = env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
if (vazio(anon)) problemas.push("(1) anon: ainda está COLE_AQUI");
else if (!(anon.startsWith("sb_publishable_") || papelDoJwt(anon) === "anon"))
  problemas.push("(1) anon: o valor colado não é a chave anon");

const svc = env.SUPABASE_SERVICE_ROLE_KEY;
if (vazio(svc)) problemas.push("(2) service_role: ainda está COLE_AQUI");
else if (!(svc.startsWith("sb_secret_") || papelDoJwt(svc) === "service_role"))
  problemas.push("(2) service_role: o valor colado não é a service_role (conferir se não colou a anon de novo)");

const senhaBanco = env.SUPABASE_DB_PASSWORD;
if (vazio(senhaBanco)) problemas.push("(3) senha do banco: ainda está DIGITE_AQUI");
if (vazio(env.OWNER_EMAIL) || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(env.OWNER_EMAIL))
  problemas.push("(4) e-mail do CRM: vazio ou inválido");
if (vazio(env.OWNER_PASSWORD) || env.OWNER_PASSWORD.length < 8)
  problemas.push("(5) senha do CRM: vazia ou com menos de 8 caracteres");

if (problemas.length) {
  console.log("✖ Faltou ajustar no .env.local:");
  for (const p of problemas) console.log("  - " + p);
  process.exit(1);
}
console.log(`✓ anon (${anon.length}), service_role (${svc.length}), senha do banco, e-mail e senha do CRM`);

// Chaves internas: geradas aqui quando vazias.
const gerar = () => crypto.randomBytes(32).toString("base64");
const interno = env.INTERNAL_SECRET || gerar();
const preencher = {
  INTERNAL_SECRET: interno,
  INTERNAL_CRON_SECRET: env.INTERNAL_CRON_SECRET || interno,
  LGPD_SIGNING_KEY: env.LGPD_SIGNING_KEY || interno,
};
for (const k of [
  "TENANT_PROVISIONING_SECRET",
  "IMPERSONATE_COOKIE_SECRET",
  "CPF_ENCRYPTION_KEY",
  "WAHA_BYO_ENCRYPTION_KEY",
  "AI_CRED_AES_KEY",
  "NUVEMSHOP_OAUTH_ENCRYPTION_KEY",
]) {
  preencher[k] = env[k] || gerar();
}

// Session pooler: o host varia por projeto (aws-0/aws-1/…); testa de verdade.
const ref = env.SUPABASE_PROJECT_REF;
let dbUrl = "";
let ultimoErro = "";
for (const host of ["aws-0-sa-east-1", "aws-1-sa-east-1", "aws-2-sa-east-1"]) {
  const url = `postgresql://postgres.${ref}:${encodeURIComponent(senhaBanco)}@${host}.pooler.supabase.com:5432/postgres`;
  const c = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 10000 });
  try {
    await c.connect();
    await c.query("select 1");
    await c.end();
    dbUrl = url;
    console.log(`✓ banco conectado pelo pooler ${host}.pooler.supabase.com`);
    break;
  } catch (e) {
    ultimoErro = e.message;
    try { await c.end(); } catch {}
    if (/password authentication failed/i.test(e.message)) {
      console.log("✖ O banco recusou a senha (3). Confira a senha ou faça o Reset password de novo.");
      process.exit(1);
    }
  }
}
if (!dbUrl) {
  console.log(`✖ Não consegui conectar no banco: ${ultimoErro}`);
  process.exit(1);
}
preencher.SUPABASE_DB_URL = dbUrl;
preencher.SUPABASE_DB_ADMIN_URL = dbUrl;

const saida = [];
const vistos = new Set();
for (const l of linhas) {
  const m = l.match(/^([A-Z0-9_]+)=/);
  if (m && m[1] === "SUPABASE_DB_PASSWORD") continue; // já está dentro da URL
  if (m && m[1] in preencher) {
    saida.push(`${m[1]}=${preencher[m[1]]}`);
    vistos.add(m[1]);
  } else {
    saida.push(l);
  }
}
for (const [k, v] of Object.entries(preencher)) if (!vistos.has(k)) saida.push(`${k}=${v}`);
fs.writeFileSync(arquivo, saida.join("\n").replace(/\n*$/, "\n"));
console.log("✓ .env.local completo");
