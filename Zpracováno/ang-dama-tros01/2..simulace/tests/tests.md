Porovnat výsledky:

|opt| move ordering | alpha-beta  | 1v1=terminal | loosening the preassure=terminal | beam search (human) | Time (s) | Nodes |
|--|--|--|--|--|--|--|--|
| brute-force | |  |  | | | 0.001 | 2090 |
| smart | X  |  |  | | | 0.004 | 2090 |
| clever (AB) | X | X | |  | | 0.002 | 595 |
| pragmatic (AB+Prune) | X | X | X | | | 0.011 | 555 |
| lazy | X | X | X | X | | 0.001 | 555 |
| human (manual) | X | X | X | X | X | 0.000 | 13 |

