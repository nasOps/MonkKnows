# Service Level Objectives (SLO) — MonkKnows

_Sidst opdateret: 2026-05-17_

Et SLO kombinerer en SLI-måling med et target og et tidsvindue. Targets herunder skal valideres mod faktiske Grafana-målinger før de betragtes som bindende.

---

## SLO 1 — Tilgængelighed

| Felt | Værdi |
|---|---|
| **SLI** | `avg_over_time(up{job="monkknows"}[30d])` |
| **Target** | ≥ 0,95 (95 %) |
| **Tidsvindue** | Rullende 30 dage |

Prometheus scraper hvert 15. sekund. `up = 1` betyder scrape lykkedes, `up = 0` betyder fejl. Et gennemsnit på 0,95 over 30 dage svarer til max ~36 timers nedetid pr. måned.

Target er afstemt med SLA'ens oppetidsmål på 95 %.

---

## SLO 2 — Fejlrate

| Felt | Værdi |
|---|---|
| **SLI** | Andel af requests der returnerer 5xx |
| **Target** | _udfyldes efter baseline er etableret_ |
| **Tidsvindue** | Rullende 30 dage |

**PromQL:**
```
sum(rate(http_server_requests_total{code=~"5.."}[30d]))
/
sum(rate(http_server_requests_total[30d]))
```

---

## SLO 3 — Latency (p95)

| Felt | Værdi |
|---|---|
| **SLI** | p95 svartid på tværs af dækkede endpoints |
| **Target** | _udfyldes efter baseline er etableret_ |
| **Tidsvindue** | Rullende 30 dage |

**PromQL:**
```
histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket[30d])))
```
