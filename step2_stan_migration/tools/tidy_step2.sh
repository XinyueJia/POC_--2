#!/usr/bin/env bash
set -euo pipefail

# Script to tidy step2_stan_migration into recommended structure using git mv where possible.
# Run from repository root.

mkdir -p step2_stan_migration/{models,R,reports,artifacts,archive,tools}

# Move stan sources
git mv step2_stan_migration/stan_model_binary.stan step2_stan_migration/models/ || true
git mv step2_stan_migration/stan_model_continuous.stan step2_stan_migration/models/ || true
git mv step2_stan_migration/stan_model_survival.stan step2_stan_migration/models/ || true

# Move R scripts
git mv step2_stan_migration/stan_data_preparation.R step2_stan_migration/R/ || true
git mv step2_stan_migration/stan_execution.R step2_stan_migration/R/ || true
git mv step2_stan_migration/stan_output_formatter.R step2_stan_migration/R/ || true
git mv step2_stan_migration/stan_alignment_validation.R step2_stan_migration/R/ || true
git mv step2_stan_migration/step2_weighted_alignment_test.R step2_stan_migration/R/ || true
git mv step2_stan_migration/step2_real_data_binary_test.R step2_stan_migration/R/ || true
git mv step2_stan_migration/step2_real_data_complete_test.R step2_stan_migration/R/ || true
git mv step2_stan_migration/step2_real_data_alignment_test.R step2_stan_migration/R/ || true

# Move reports
git mv step2_stan_migration/STEP2_FINAL_REPORT.md step2_stan_migration/reports/ || true
git mv step2_stan_migration/STEP2_PROJECT_SUMMARY_WITH_REAL_DATA.md step2_stan_migration/reports/ || true
git mv step2_stan_migration/alignment_report.md step2_stan_migration/reports/ || true
git mv step2_stan_migration/alignment_report.json step2_stan_migration/reports/ || true
git mv step2_stan_migration/step2_weighted_alignment_report.json step2_stan_migration/reports/ || true
git mv step2_stan_migration/step2_output_alignment_final.json step2_stan_migration/reports/ || true
git mv step2_stan_migration/step2_real_data_binary_alignment.json step2_stan_migration/reports/ || true

# Archive older outputs
git mv step2_stan_migration/step2_output_alignment_v1.json step2_stan_migration/archive/ || true

# Move logs and binary artifacts
mkdir -p step2_stan_migration/artifacts
git mv step2_stan_migration/real_data_test.log step2_stan_migration/artifacts/ || true
git mv step2_stan_migration/stan_model_binary step2_stan_migration/artifacts/ || true || true
git mv step2_stan_migration/stan_model_continuous step2_stan_migration/artifacts/ || true || true
git mv step2_stan_migration/stan_model_survival step2_stan_migration/artifacts/ || true || true

# Final reminders
cat <<EOF
Tidying completed. Please:
  - Review moved files and run 'git status'
  - Update any path references in scripts if needed (use git grep)
  - Commit the tidy branch: git add -A && git commit -m "chore(tidy): reorganize step2_stan_migration"
EOF
