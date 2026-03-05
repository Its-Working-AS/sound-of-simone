# Feilanalyse og løsningsplan (Cloudflare Workers + Decap OAuth)

## Hvorfor denne versjonen

Denne analysen er strammet inn mot **Cloudflare Workers-feiltyper** og hvordan de faktisk treffer vår `decap-oauth-proxy`-implementasjon.
Målet er å komme raskere fra symptom → eksakt rotårsak → verifisert fiks.

## Verifisert status akkurat nå

- Frontend bygger lokalt uten blokkerende feil (`npm run build`).
- OAuth-flyten håndteres av worker i `decap-proxy/src/index.ts` med tre kritiske steg:
  1. `/auth` (origin + redirect til GitHub)
  2. `/callback` (code + token exchange)
  3. `postMessage` tilbake til admin-vindu
- Worker er satt opp med vars/secrets via `wrangler.toml` + Cloudflare secrets.

## Arbeidshypotese

Problemet er mest sannsynlig i én av disse kategoriene:

1. **Worker-runtime/Workers-platform feil** (exceptions, misconfig, route/domain mismatch)
2. **OAuth-konfig feil** (client id/secret/callback mismatch)
3. **CORS/origin-policy mismatch** (forbudt origin/callback-origin)
4. **GitHub token exchange-feil** (scope/credentials/code)

## Direkte mapping: symptom → sannsynlig feilklasse

### A) 403 fra `/auth` eller preflight (OPTIONS)

**Sannsynlig årsak:** origin ikke i `ALLOWED_ORIGINS`.

I vår kode returneres dette eksplisitt når origin mangler eller ikke er tillatt.

**Sjekk nå:**

- At faktisk origin er med i `ALLOWED_ORIGINS` i worker-miljø.
- At origin i browser faktisk matcher (www vs non-www, https, port).

### B) 500 fra `/auth` eller `/callback`

**Sannsynlig årsak:** manglende secrets (`GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET`).

I vår kode gir dette tydelige JSON-feil.

**Sjekk nå:**

- Secrets er satt i riktig miljø (prod vs preview).
- Navn matcher eksakt (`GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`).

### C) 502 fra `/callback`

**Sannsynlig årsak:** GitHub token exchange feiler.

I vår kode skjer dette når GitHub ikke returnerer `access_token`.

**Vanlige underårsaker:**

- Callback URL mismatch i GitHub OAuth app.
- Feil/utløpt auth code.
- Manglende scopes eller feil app-konfig.

### D) 404 / 5xx utenfor vår JSON-feilstruktur

**Sannsynlig årsak:** Workers-ruting/domene/deploy-problem, eller runtime-exception før vår handler svarer.

**Sjekk nå:**

- Worker er deployet siste versjon.
- Custom domain peker til riktig worker.
- Feilen finnes i `wrangler tail` med stack/exception.

## Kodeforankret sjekkpunktliste

Basert på `decap-proxy/src/index.ts`:

1. `resolveOrigin()` prioriterer `origin` query param, deretter `Origin` header.
2. OPTIONS krever tillatt origin, ellers 403.
3. `/auth` krever tillatt origin + `GITHUB_CLIENT_ID`.
4. `/callback` krever tillatt callback-origin + `code` + begge GitHub secrets.
5. Token exchange mot `https://github.com/login/oauth/access_token` må gi `access_token`.

Dette betyr at nesten alle funksjonelle feil kan klassifiseres med én responskode + én logglinje.

## Operativ incident-run (konkret rekkefølge)

### Fase 1 — Identifiser feilklasse (10–15 min)

1. Kjør login fra `/admin` og noter første feilkall i Network-tab.
2. Noter:
   - URL (`/auth` eller `/callback`)
   - statuskode
   - response body

**Beslutning:**

- 403 → gå til Fase 2 (origin)
- 500 → gå til Fase 3 (secrets)
- 502 → gå til Fase 4 (GitHub exchange)
- 404/5xx annet → gå til Fase 5 (Workers deploy/route/runtime)

### Fase 2 — Origin/CORS (15 min)

1. Hent faktisk frontend-origin fra browser.
2. Sammenlign med `ALLOWED_ORIGINS` i Worker vars.
3. Valider også callback-origin (query-param `origin` i callback URL).

**Fiks:** oppdater `ALLOWED_ORIGINS` i Cloudflare Worker vars og redeploy.

### Fase 3 — Secrets (10 min)

1. Verifiser at secrets finnes i riktig miljø:
   - `GITHUB_CLIENT_ID`
   - `GITHUB_CLIENT_SECRET`
2. Roter/re-set hvis usikker på verdi.

**Fiks:** sett secrets på nytt og deploy worker.

### Fase 4 — GitHub token exchange (20–30 min)

1. Verifiser GitHub OAuth app callback URL eksakt mot worker callback URL.
2. Verifiser at riktig GitHub OAuth app brukes (ikke gammel app).
3. Test ny OAuth-runde i inkognito.

**Fiks:** korriger callback URL/app-konfig og retest.

### Fase 5 — Workers-runtime/plattform (20–30 min)

1. Tail runtime-logger:

```bash
cd decap-proxy
npx wrangler tail decap-oauth-proxy
```

2. Verifiser deploystatus:

```bash
cd decap-proxy
npm run deploy
```

3. Verifiser domain/route peker på riktig worker i Cloudflare Dashboard.

**Fiks:** redeploy + korriger route/domain binding ved mismatch.

## Minimal kommandopakke for feilsøking

```bash
# 1) Verifiser frontend build
npm run build

# 2) Lokal worker-run for rask validering av kodebane
cd decap-proxy
npm run dev

# 3) Prod runtime logs (Cloudflare)
npx wrangler tail decap-oauth-proxy

# 4) Deploy worker ved konfigfiks
npm run deploy
```

## Forbedringer som bør inn etter incident (for å unngå gjentakelse)

1. **Strengere observability**
   - Legg til request-id i JSON-feilresponser.
   - Logg klassifisering (origin/auth/token/runtime) eksplisitt.

2. **Konfig-validering ved deploy**
   - Fail-fast script som sjekker at nødvendige vars/secrets finnes før deploy.

3. **Runbook i repo**
   - Egen “OAuth incident quickstart” med decision tree over (403/500/502/5xx).

## Tidsestimat

- Klassifisering til sannsynlig rotårsak: **10–30 min**
- Målrettet fiks + verifisering: **20–60 min**
- Totalt normal løp: **30–90 min**

## Neste konkrete steg (anbefalt)

Start med Fase 1 umiddelbart, og lås først **eksakt statuskode + endpoint**.
Det alene vil normalt kutte 80 % av søkeområdet i denne worker-arkitekturen.
