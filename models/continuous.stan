data {
  int<lower=1> N;
  vector[N] y;
  array[N] int<lower=0, upper=1> trt;
  vector<lower=0>[N] weights;
}

parameters {
  real alpha;
  real beta_trt;
  real<lower=0> sigma;
}

model {
  alpha ~ normal(0, 10);
  beta_trt ~ normal(0, 10);
  sigma ~ student_t(3, 0, 10);

  for (i in 1:N) {
    target += weights[i] * normal_lpdf(y[i] | alpha + beta_trt * trt[i], sigma);
  }
}

generated quantities {
  real mean_difference = beta_trt;
}
