data {
	int<lower=1> N;
	int<lower=1> J;
	array[N] int<lower=0, upper=1> event;
	array[N] int<lower=1, upper=J> interval;
	array[N] int<lower=0, upper=1> trt;
	vector<lower=0>[N] exposure;
	vector<lower=0>[N] weights;
}

parameters {
	vector[J] alpha;
	real beta_trt;
}

model {
	alpha ~ normal(0, 2.5);
	beta_trt ~ normal(0, 2.5);

	for (i in 1:N) {
		target += weights[i] * poisson_log_lpmf(
			event[i] |
			log(exposure[i]) + alpha[interval[i]] + beta_trt * trt[i]
		);
	}
}

generated quantities {
	real hazard_ratio;
	hazard_ratio = exp(beta_trt);
}
// Step 2 placeholder: survival outcome Stan model
// TODO: replace with the frozen Step 1 survival specification
