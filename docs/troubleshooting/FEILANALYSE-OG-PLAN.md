# Feilanalyse og løsningsplan

## Situasjonsbilde

Prosjektet bygger lokalt uten feil, men det finnes flere indikatorer på at problemet sannsynligvis oppstår i miljø/spesifikk deploy-flyt (ikke i selve Astro-koden):

- Lokal build kjører fullført (`npm run build`) og genererer statiske sider i `dist/`.
- Repoet inneholder omfattende deploy- og CMS-dokumentasjon med kjente feilsituasjoner (OAuth, CORS, manglende miljøvariabler, DNS/SSL, GitHub Pages/Cloudflare-flows).
- Det finnes en separat `decap-proxy`-tjeneste med egne miljøkrav som ofte er roten til “det fungerer lokalt men ikke i drift”.

## Verifiserte observasjoner

### 1) Applikasjonen bygger lokalt

Kommando:

```bash
npm run build
```

Resultat:

- Build fullførte med 4 sider generert.
- Ingen blokkerende feil i Astro-builden.
- Én ikke-blokkerende Vite-warning om ubrukte imports i intern Astro-avhengighet.

Tolkning:

- Kjerneproblemet er sannsynligvis ikke en syntaks-/kompileringsfeil i `src/`.
- Videre feilsøk bør fokusere på runtime/deployment/CMS-autentisering.

### 2) Høy sannsynlighet for konfigurasjonsfeil i deploy-kjeden

Repoet inneholder egne guider for kjente produksjonsfeil, særlig:

- “Client ID not configured”
- “Repo not found”
- CORS-/OAuth-problemer i Decap-proxy

Tolkning:

- Dette er et klassisk signal på at feil ligger i miljøvariabler, callback-URL eller origin-policy, ikke i frontend-koden.

## Mest sannsynlige rotårsaker (prioritert)

1. **Manglende eller feil OAuth-miljøvariabler**
   - `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, eller callback-relatert config mangler/er feil i drift.

2. **CORS/origin mismatch i `decap-proxy`**
   - Frontend-origin eller callback-origin er ikke i tillattliste.

3. **Feil redirect/callback URL mellom GitHub OAuth app og proxy**
   - Små avvik (http/https, trailing slash, subdomene) gir hard fail.

4. **Feil repo/permissions i CMS**
   - Decap CMS får ikke tilgang (repo-navn, branch, token-scope, org-policy).

5. **Deploy-miljø avviker fra lokal antagelse**
   - Secrets ikke satt i GitHub/Cloudflare, eller satt i feil miljø (preview/prod).

## Konkrete hypoteser å teste først (raskest gevinst)

### Hypotese A: OAuth-variabler mangler i proxy-miljøet

**Test:** sjekk runtime logs for feilmeldinger som eksplisitt nevner manglende credentials.

**Forventet signal:** 500-respons med melding om manglende OAuth-konfig.

### Hypotese B: Origin blir blokkert av proxy

**Test:** kall proxy-endepunkt fra faktisk frontend-origin og verifiser responskode.

**Forventet signal:** 403 med “Forbidden origin” eller “Forbidden callback origin”.

### Hypotese C: Callback URL mismatch

**Test:** sammenlign nøyaktig callback i:

- GitHub OAuth app
- Proxy-konfig
- CMS-konfig/frontend

**Forventet signal:** OAuth-flyt stopper etter GitHub-redirect.

## Handlingsplan (gjennomførbar i én arbeidsøkt)

### Fase 1 — Innsamling av fakta (30–45 min)

1. Hent siste deploy-logger (frontend + proxy).
2. Marker første feiltidspunkt i hver logg.
3. Kategoriser feil i: build, runtime, auth, nettverk.

**Leveranse:** kort loggmatrise med tidspunkt + feilkode + komponent.

### Fase 2 — Konfig-audit (30 min)

1. Verifiser alle nødvendige env vars i riktig miljø (preview/prod).
2. Verifiser GitHub OAuth callback URL 1:1 mot runtime URL.
3. Verifiser tillatte origins i proxy.

**Leveranse:** pass/fail-sjekkliste per variabel/URL.

### Fase 3 — Reproduserbar test (30 min)

1. Kjør E2E av login/CMS-flow fra deployed frontend.
2. Observer network requests i browser devtools.
3. Match failing request mot proxy-logg.

**Leveranse:** ett konkret failing request med statuskode, payload og korrelert logglinje.

### Fase 4 — Målrettet fiks (30–60 min)

1. Rett kun den identifiserte rotårsaken.
2. Deploy på nytt.
3. Kjør samme E2E-sjekk.

**Leveranse:** før/etter-verifikasjon av samme test.

### Fase 5 — Stabilisering (15 min)

1. Legg inn tydeligere feilmeldinger i proxy-responser der mulig.
2. Oppdater driftssjekkliste så feilen fanges tidligere.

**Leveranse:** enkel runbook for neste deploy.

## Operativ sjekkliste (kan kjøres punktvis)

- [ ] `npm run build` er grønn lokalt.
- [ ] Proxy har alle OAuth-secrets i aktivt miljø.
- [ ] GitHub OAuth callback URL matcher eksakt produksjons-URL.
- [ ] Proxy tillater frontend-origin + callback-origin.
- [ ] CMS-repo/branch og permissions er verifisert.
- [ ] Nettverkskall i browser viser 2xx i OAuth-exchange.
- [ ] Login/CMS-flyt er bekreftet fra deployet miljø.

## Forslag til ansvarsdeling

- **Deg (produkt/eier):** bekreft domener, ønsket prod/preview-struktur, og GitHub-org-policy.
- **Meg (implementasjon):** utfører logganalyse, konfig-audit, målrettet patch, og verifisering.

## Forventet tidsestimat

- Hurtig diagnose til sannsynlig rotårsak: **1–2 timer**.
- Fiks + verifisering: **0.5–1.5 timer**.
- Totalt: **1.5–3.5 timer** avhengig av tilgang til logger/secrets.

## Beslutningstre for neste steg

1. **Hvis build feiler i CI:** prioriter build-feil først.
2. **Hvis build er grønn men auth feiler:** gå direkte på OAuth/origin/callback.
3. **Hvis auth er grønn men CMS feiler:** valider repo/permissions/branch.
4. **Hvis alt ser riktig ut men fortsatt feil:** ta packet-level spor (request/response + log correlation ID).

---

Hvis du vil, kan neste steg være at jeg følger denne planen som en operativ “incident-run” og dokumenterer hvert funn fortløpende til vi har bekreftet rotårsak og grønn flyt.
