data {
	int<lower=1> N;
	array[N] int<lower=0, upper=1> y;
	array[N] int<lower=0, upper=1> trt;
	vector<lower=0>[N] weights;
}

parameters {
	real alpha;
	real beta_trt;
}

model {
	alpha ~ normal(0, 2.5);
	beta_trt ~ normal(0, 2.5);

	for (i in 1:N) {
		target += weights[i] * bernoulli_logit_lpmf(y[i] | alpha + beta_trt * trt[i]);
	}
}

generated quantities {
	real odds_ratio;
	odds_ratio = exp(beta_trt);
}
