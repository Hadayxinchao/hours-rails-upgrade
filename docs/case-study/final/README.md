# Final benchmark (same session, same database server)

Measured 2026-11-24. All three versions were built from their own commits and run back to back against the same Postgres 9.6 container, using the unchanged `script/benchmark/seed.rb` and `script/benchmark/run.rb`. They ran in production mode, in a single process, with fragment caching off.

| Version | Commit | Ruby / Rails |
|---|---|---|
| `base` | `hop/0-baseline` | 2.4.2 / 5.0.7.2 |
| `after` | `e38d5a0` (upgrade only) | 3.4.12 / 8.1.4.1 |
| `optimized` | performance pass | 3.4.12 / 8.1.4.1 |

| Page | Before | Upgrade only | Optimized | Speed-up |
|---|---:|---:|---:|---:|
| Reports CSV export (23k rows) | 37,997 ms | 20,002 ms | **1,735 ms** | **21.9×** |
| Billables (~10k unbilled rows) | 3,318 ms | 2,114 ms | **540 ms** | **6.1×** |
| Dashboard | 655 ms | 543 ms | **165 ms** | **4.0×** |
| Client detail | 374 ms | 240 ms | **120 ms** | 3.1× |
| Project detail | 184 ms | 138 ms | **87 ms** | 2.1× |
| Reports | 143 ms | 107 ms | **86 ms** | 1.7× |
| User entries | 151 ms | 94 ms | **91 ms** | 1.7× |
| Tag detail | 118 ms | 122 ms | **105 ms** | 1.1× |
| Team | 17 ms | 9 ms | 15 ms | (noise at this size) |
| **Process memory after the run** | 833 MB | 453 MB | **358 MB** | −57% |

All numbers are p50; the JSON files hold p95, SQL counts and allocations. The SQL counts in the JSON leave out query-cache hits. `script/benchmark/sql_profile.rb` counts them, and that is how the N+1s were found: the CSV export ran 89,006 statements, of which 88,908 came from the query cache.

Absolute times are about 10–20% higher than the 2026-11-16 measurements in `../baseline/` and `../after-upgrade/` (the host's WSL kernel and Docker were updated in between), which is why all three versions were re-run together here.
