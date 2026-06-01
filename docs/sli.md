# Service Level Indicators (SLI) — MonkKnows

_Sidst opdateret: 2026-05-17_

SLI'er er de målbare størrelser vi bruger til at vurdere tjenestens tilstand. Tallene herunder skal udfyldes på baggrund af faktiske Grafana-målinger.

---

## 1. Tilgængelighed

Andelen af tid hvor `/metrics`-endpointet er tilgængeligt for Prometheus' scrape. Fungerer som proxy for tjenestens overordnede tilgængelighed.

**Metrik:** `up{job="monkknows"}`

**PromQL (månedlig):**
```
avg_over_time(up{job="monkknows"}[7d])
```

**Målt værdi:** _udfyldes_

---

## 2. Fejlrate

Andelen af alle HTTP-requests til tjenesten der returnerer 5xx. Inkluderer al trafik gennem Rack-middlewaren — ikke begrænset til de endpoints SLA'en dækker.

**Metrik:** `http_server_requests_total` — labels: `code`, `method`, `path`

**PromQL:**
```
sum(rate(http_server_requests_total{code=~"5.."}[7d]))
/
sum(rate(http_server_requests_total[7d]))
```

**Målt værdi:** _udfyldes_

---

## 3. Latency (p95)

95. percentil af svartiden for alle HTTP-requests til tjenesten. Inkluderer al trafik gennem Rack-middlewaren — ikke begrænset til de endpoints SLA'en dækker.

**Metrik:** `http_server_request_duration_seconds` — labels: `method`, `path`

**PromQL:**
```
histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket[7d])))
```

**Målt værdi:** _udfyldes_
