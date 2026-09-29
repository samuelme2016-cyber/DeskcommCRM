# Darkcom CRM: fork próprio do DeskcommCRM

Este repositório é um **fork** do [DeskcommCRM oficial](https://github.com/melgarafael/DeskcommCRM).
Ele tem as suas personalizações e publica as **suas próprias imagens Docker**. A VPS instala e
atualiza **a partir daqui**, e não do projeto oficial.

| O quê | Onde |
|---|---|
| Código (fork) | https://github.com/samuelme2016-cyber/DeskcommCRM |
| Imagens Docker | `ghcr.io/samuelme2016-cyber/deskcommcrm`, `deskcomm-worker`, `deskcomm-scheduler` |
| Versões publicadas | https://github.com/samuelme2016-cyber/DeskcommCRM/releases |
| Robô que compila | https://github.com/samuelme2016-cyber/DeskcommCRM/actions/workflows/publish-image.yml |
| Projeto oficial | https://github.com/melgarafael/DeskcommCRM (remoto `upstream`) |
| Versão oficial mesclada | [`darkcom/VERSAO-OFICIAL`](darkcom/VERSAO-OFICIAL) |

## Como uma alteração chega à VPS

```
1. Alterar (Claude Code)  →  2. Testar  →  3. git commit + push  →  4. publicar-versao.sh  →  5. VPS atualiza
     no PC                    local         para o fork               GitHub compila          botão "Nova versão"
                                                                      (15 a 25 min)
```

1. **Alterar:** peça ao Claude Code aberto nesta pasta. Siga o `CLAUDE.md` do projeto: mudança de
   banco vira migration nova **e** apêndice no `supabase/baseline.sql`.
2. **Testar:** no PC, antes de publicar (veja "Rodar no PC" abaixo).
3. **Salvar no GitHub:** `git add -A && git commit -m "o que mudou" && git push origin main`.
   O push na `main` já compila imagens `:latest` (topo da main), mas **a VPS não usa essas**.
4. **Publicar a versão:**
   ```bash
   bash darkcom/publicar-versao.sh "Descrição curta do que mudou"
   ```
   O script calcula o número (ex.: `v1.63.5`), escreve no `CHANGELOG.md`, cria a release e o
   GitHub compila as imagens. Acompanhe no link "Robô que compila". Quando ficar verde, o canal
   `stable` passa a apontar para essa versão.
5. **Atualizar a VPS:** no CRM, menu lateral → rodapé → **"Nova versão"** → **Atualizar agora**
   (em até 5 min). Pelo terminal: `bash hostgator-setup-kit/update.sh` dentro da pasta do CRM na VPS.
   O processo faz backup antes e volta sozinho se a versão nova não subir.

## Trazer as novidades do projeto oficial

```bash
bash darkcom/atualizar-do-oficial.sh          # mescla a última release oficial
```

- Mescla **a release** oficial, nunca o topo da main dele.
- Se houver conflito com as suas mudanças, o script para e lista os arquivos. Peça ao Claude
  Code para resolver e depois rode `bash darkcom/conferir-fork.sh`.
- Depois: teste, `git push origin main` e `bash darkcom/publicar-versao.sh "Atualizado para a vX.Y.Z oficial"`.

> ⚠️ **Nunca** troque `ghcr.io/samuelme2016-cyber` de volta para `ghcr.io/melgarafael` (nem num
> conflito). Se isso acontecer, a VPS volta a instalar a versão oficial **por cima das suas
> mudanças**, sem avisar. O `darkcom/conferir-fork.sh` detecta esse problema.

## Instalar na VPS (primeira vez)

Siga o tutorial oficial (Supabase, domínio etc.), mas **clone o fork**:

```bash
git clone https://github.com/samuelme2016-cyber/DeskcommCRM.git
cd DeskcommCRM
bash hostgator-setup-kit/install.sh
```

No campo "Imagem Docker do app", aceite o valor sugerido, que já vem do fork. Com o Claude Code
na VPS, peça: *"leia o DARKCOM.md e instale seguindo o hostgator-setup-kit/install.sh"*.

## O que foi alterado em relação ao oficial (para o fork funcionar)

| Arquivo | Mudança |
|---|---|
| `hostgator-setup-kit/_common.sh` | `IMG_NS` → `ghcr.io/samuelme2016-cyber` e URL do repositório → fork |
| `hostgator-setup-kit/install.sh`, `comecar.sh`, `diagnostico.sh` | URL do repositório → fork |
| `docker-compose.prod.yml`, `.env.hostgator.example` | imagens padrão → `ghcr.io/samuelme2016-cyber/...` |
| `tests/unit/_identidade-deste-repo.ts` | namespace do repositório → fork (mantém os testes coerentes) |
| `darkcom/` | scripts deste guia |
| Robôs do GitHub | só `publish-image.yml` fica ligado no fork; os outros (CI do mantenedor, e2e, boas-vindas, release oficial) estão desligados em *Actions* |

## Rodar no PC

- **Completo (com WhatsApp):** exige virtualização ligada na BIOS e o Docker Desktop. Depois, no
  Ubuntu (WSL): `./ubuntu-local-installer.sh`, que sobe tudo em `http://localhost:3000`.
- **Sem Docker (sem WhatsApp):** usa um projeto Supabase gratuito **só para testes** (nunca o
  da VPS). Na primeira vez:
  ```bash
  pnpm install
  powershell -ExecutionPolicy Bypass -File darkcom\configurar-local.ps1   # pede as chaves no terminal
  node darkcom/aplicar-banco.mjs                                          # cria as tabelas
  pnpm exec tsx scripts/bootstrap-owner.ts                                # cria o admin
  ```
  No dia a dia, só `pnpm dev` e abra `http://localhost:3000`.
