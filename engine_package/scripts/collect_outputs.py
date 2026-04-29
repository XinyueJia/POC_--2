#!/usr/bin/env python3
import csv
import json
import math
import statistics
from pathlib import Path


PACKAGE_DIR = Path(__file__).resolve().parents[1]
DRAWS_DIR = PACKAGE_DIR / "outputs" / "draws"
SUMMARY_DIR = PACKAGE_DIR / "outputs" / "summaries"
SUMMARY_PATH = SUMMARY_DIR / "plaintext_summary_output.json"


OUTCOMES = {
    "binary": {
        "file": "binary_draws.csv",
        "estimand": "OR",
        "transform": math.exp,
        "benefit": lambda x: x < 1,
    },
    "continuous": {
        "file": "continuous_draws.csv",
        "estimand": "Mean difference",
        "transform": lambda x: x,
        "benefit": lambda x: x < 0,
    },
    "survival": {
        "file": "survival_draws.csv",
        "estimand": "HR",
        "transform": math.exp,
        "benefit": lambda x: x < 1,
    },
}


def read_beta_trt_draws(csv_path):
    if not csv_path.exists():
        raise FileNotFoundError(f"CmdStan posterior CSV not found: {csv_path}")

    header = None
    beta_index = None
    draws = []

    with csv_path.open("r", newline="") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            row = next(csv.reader([line]))
            if header is None:
                header = row
                if "beta_trt" not in header:
                    raise ValueError(f"Column 'beta_trt' not found in CmdStan CSV: {csv_path}")
                beta_index = header.index("beta_trt")
                continue

            try:
                draws.append(float(row[beta_index]))
            except (ValueError, IndexError) as error:
                raise ValueError(f"Invalid beta_trt draw in {csv_path}: {row}") from error

    if not draws:
        raise ValueError(f"No beta_trt posterior draws found in CmdStan CSV: {csv_path}")

    return draws


def quantile(sorted_values, probability):
    if not sorted_values:
        raise ValueError("Cannot compute quantile for an empty vector.")
    if len(sorted_values) == 1:
        return sorted_values[0]

    position = probability * (len(sorted_values) - 1)
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return sorted_values[int(position)]

    weight = position - lower
    return sorted_values[lower] * (1 - weight) + sorted_values[upper] * weight


def summarize_outcome(outcome_type, spec):
    beta_draws = read_beta_trt_draws(DRAWS_DIR / spec["file"])
    effect_draws = [spec["transform"](draw) for draw in beta_draws]
    sorted_effects = sorted(effect_draws)

    return {
        "outcome_type": outcome_type,
        "estimand": spec["estimand"],
        "posterior_mean": statistics.fmean(effect_draws),
        "posterior_median": statistics.median(effect_draws),
        "ci_95_lower": quantile(sorted_effects, 0.025),
        "ci_95_upper": quantile(sorted_effects, 0.975),
        "benefit_probability": statistics.fmean(1.0 if spec["benefit"](x) else 0.0 for x in effect_draws),
        "n_draws": len(effect_draws),
    }


def main():
    SUMMARY_DIR.mkdir(parents=True, exist_ok=True)
    summary = {
        "package": "plaintext_cmdstan_engine_demo",
        "summary_type": "lightweight_plaintext_demo_summary",
        "outcomes": [summarize_outcome(outcome_type, spec) for outcome_type, spec in OUTCOMES.items()],
    }

    with SUMMARY_PATH.open("w") as handle:
        json.dump(summary, handle, indent=2)
        handle.write("\n")

    print(f"Wrote plaintext summary to {SUMMARY_PATH}")


if __name__ == "__main__":
    main()
