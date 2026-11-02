# MNIST FPGA Cloud SDK Result Logs

This file consolidates the SDK/UART result information that was pasted during the MNIST FPGA-to-Cloud Run measurement work.

## Notes on provenance

- The formal cloud experiment used 100-image controlled MNIST batches.
- Accuracy, latency, throughput, and communication-error information were recorded by the SDK application and written to BRAM.
- Some original console dumps included full per-image CSV-style records.
- This archive includes only values that were explicitly preserved in the clipboard/running document from the SDK terminal and reorganized here. It does not invent missing per-image rows.

---

## Formal accuracy by 100-image block

| Images | Correct | Accuracy |
|---|---:|---:|
| 0–99 | 98/100 | 98% |
| 100–199 | 97/100 | 97% |
| 200–299 | 96/100 | 96% |
| 300–399 | 98/100 | 98% |
| 400–499 | 96/100 | 96% |
| 500–599 | 97/100 | 97% |
| 600–699 | 95/100 | 95% |
| 700–799 | 100/100 | 100% |
| 800–899 | 98/100 | 98% |
| 900–999 | 95/100 | 95% |

Overall:

```text
970 / 1000 correct
97.0% accuracy
```

---

## Formal steady-state latency and throughput summaries

These values summarize accepted formal runs for each 100-image block.

| Images | Mean latency | SD | Throughput |
|---|---:|---:|---:|
| 0–99 | 58.272 ms | 0.686 ms | 17.11 img/s |
| 100–199 | 59.252 ms | 0.571 ms | 16.82 img/s |
| 200–299 | 58.766 ms | 1.218 ms | 16.97 img/s |
| 300–399 | 59.364 ms | 1.478 ms | 16.80 img/s |
| 400–499 | 59.197 ms | 0.789 ms | 16.84 img/s |
| 500–599 | 58.750 ms | 0.439 ms | 17.03 img/s |
| 600–699 | 59.455 ms | 0.461 ms | 16.78 img/s |
| 700–799 | 59.924 ms | 1.517 ms | 16.69 img/s |
| 800–899 | 59.300 ms | 1.282 ms | 16.76 img/s |
| 900–999 | 59.484 ms | 1.282 ms | 16.76 img/s |

Observed formal latency range across the dataset:

```text
Minimum observed latency: 51.934 ms
Maximum observed latency: 159.652 ms
Typical steady-state mean: approximately 58–60 ms
Typical throughput: approximately 16.7–17.1 classifications/s
```

---

## Validation cold-start / first-request observations

The first request of a validation run was often substantially slower than steady-state requests.

| Images | First-request latency |
|---|---:|
| 0–99 | 2198.925 ms |
| 100–199 | 2975.776 ms |
| 200–299 | 3509.396 ms |
| 300–399 | 3112.686 ms |
| 400–499 | 3546.831 ms |
| 500–599 | 3480.085 ms |
| 600–699 | 2085.655 ms |
| 700–799 | 1843.503 ms |
| 800–899 | 3263.304 ms |
| 900–999 | 3347.360 ms |

These startup observations were treated separately from the accepted steady-state timing results.

---

## Exact preserved UART summary: 700–799

```text
Connected to COM3 at 115200

Total images : 100
Correct : 100
Errors : 0
Minimum latency : 55554 us
Maximum latency : 86259 us
Average latency : 58710 us
Total run time : 5890150 us
```

The original pasted console block also contained a full per-image CSV section. That row-level text is not reproduced here because the complete original block is not available in the current context.

---

## Exact preserved UART summary: 600–699 validation

```text
Total images : 100
Correct : 95
Errors : 0
Minimum latency : 53712 us
Maximum latency : 2085655 us
Average latency : 78858 us
Total run time : 7904959 us
```

The original full CSV contained 100 image records. Five misclassifications were identified at image indices:

```text
10
19
59
84
91
```

The very large maximum latency corresponds to the first-request/startup effect and was not representative of the later steady-state requests.

---

## Exact preserved UART summary: 800–899 validation

```text
Total images : 100
Correct : 10
Errors : 0
Minimum latency : 58223 us
Maximum latency : 3386686 us
Average latency : 95951 us
Total run time : 9614202 us
```

This run was diagnosed as using stale 900-set pixel-ROM contents and was not accepted as a valid 800–899 measurement run.

A later corrected 800–899 formal result was:

```text
98 / 100 correct
98% accuracy
```

with steady-state mean latency of approximately:

```text
59.300 ms
```

and throughput of approximately:

```text
16.76 images/s
```

---

## 900–999 formal result

The preserved formal summary for the final 100-image block was:

```text
95 / 100 correct
95% accuracy
Errors: 0
```

The accepted steady-state summary was:

```text
Mean latency: 59.484 ms
SD: 1.282 ms
Throughput: 16.76 images/s
```

The first-request validation latency for this block was:

```text
3347.360 ms
```

---

## 0–99 validation summary

The preserved validation summary was:

```text
Total images : 100
Correct : 98
Errors : 0
Validation batch mean : 91.280 ms
```

The accepted formal steady-state summary for this block was:

```text
Mean latency: 58.272 ms
SD: 0.686 ms
Throughput: 17.11 images/s
```

---

## Measurement acceptance notes

The formal experiment used repeated 100-image runs for each image block.

Accepted runs required:

```text
100 completed images
aligned per-image records
zero communication errors
valid TEST_COMPLETE
```

A 99-image misaligned run was excluded.

Startup failures included TCP error `-13`; these occurred before a valid measured workload and were not treated as accepted formal runs.

Across the accepted formal runs:

```text
Communication errors: 0
```

---

## Relationship to SDK implementation

The formal SDK application stored:

```text
total count
correct count
error count
minimum latency
maximum latency
latency sum
total 100-image run time
TEST_COMPLETE
```

It also stored one 16-byte record per image containing:

```text
image index
expected label
predicted label
correct flag
error flag
latency in microseconds
raw latency timer ticks
```

Development builds could print these records over UART after `TEST_COMPLETE`. The final quiet measurement build left the results in BRAM so UART output did not affect the timed interval.

---

## Scope

This file archives the formal FPGA-to-Cloud Run measurement results only.

It does not include:

- local FPGA-only measurements;
- live camera-to-cloud diagnostic latency;
- Unity Cloud Run measurements;
- Cloud Run server-side request latency as a substitute for client-side latency; or
- power/memory measurements from the reduced cloud-power FPGA build.
