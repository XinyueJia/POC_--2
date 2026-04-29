# Step 2.6: Prototype-aligned validation

## Why this validation exists

Step 2.5 originally supports a small synthetic smoke-test dataset so we can verify the spec-driven generator, Stan input JSON, CmdStan execution, and output contract wiring. That smoke-test is useful for interface checks, but it is not enough to show that the migrated Step 2.5 / CmdStan workflow can run on data aligned with the original Rmd prototype scenario.

Step 2.6 uses the same simulated-data source as the Rmd prototype where available: `prototype/demo_data_advanced.xlsx`. If that file is unavailable, the export script falls back to the Rmd prototype simulation logic. The goal is migration validation, not new statistical model development.

## Rmd prototype data vs Step 2.5 smoke-test data

The prototype-aligned data represents the original three-cohort simulated scenario:

- `Hainan_Treated`: current single-arm treated cohort
- `External_A`: external control source A
- `External_B`: external control source B
- binary, continuous, and survival outcomes
- IPTW, source discount, and Bayesian borrowing weights

The Step 2.5 smoke-test data is smaller and only intended to prove that the generator and CmdStan path run end to end. Step 2.6 replaces that smoke-test input with prototype-aligned simulated data while reusing `spec/analysis_spec.R` and `config/config.json`.

## Input data source

The primary input source is:

```text
prototype/demo_data_advanced.xlsx
```

The generated analysis-ready dataset is:

```text
data/preprocessed_demo.rds
```

This data is still synthetic / simulated data. It is not real study data.

## Generated Stan input JSON

Running Step 2.6 generates:

```text
data/stan_input_binary.json
data/stan_input_continuous.json
data/stan_input_survival.json
```

These files are generated from `data/preprocessed_demo.rds` and the shared `spec/analysis_spec.R` configuration.

## Generated CmdStan outputs

If local CmdStan and `cmdstanr` are available, Step 2.6 generates:

```text
outputs/summary_output.json
outputs/metadata.json
outputs/diagnostics.json
outputs/cmdstan/<run_id>/<outcome_type>/
```

The validation report is:

```text
outputs/prototype_aligned_validation_report.json
```

The prototype-vs-CmdStan comparison report is:

```text
outputs/prototype_cmdstan_comparison.json
```

## How to run

```bash
Rscript R/run_prototype_aligned_validation.R
```

This entry point generates `config/config.json`, exports prototype-aligned preprocessed data, generates Stan input JSON, runs CmdStan validation, writes output JSON, writes the comparison report, and syncs Step 3 engine package data / expected outputs when CmdStan validation succeeds.

## Current limitations

- The data is simulated data, not real study data.
- v0.1 does not require a full brms prototype rerun.
- If `outputs/prototype_reference_summary.json` is a placeholder, Step 2.6 completes prototype-aligned CmdStan validation but does not claim full brms-vs-CmdStan numerical equivalence.
- A full numerical equivalence test requires rerunning the Rmd/brms prototype or exporting a real prototype reference summary, then rerunning `R/compare_prototype_and_cmdstan.R`.
- Running the full validation requires a local CmdStan / `cmdstanr` environment.
