### Run over batches of 1000 parameters until 2000 complete hypercube samples are generated or 100000 parameter
 ## values are exhausted. If it is the later probably should just adjust the parameter space 

## runs where the pop doesnt go extinct
num_complete <- 0
## collections of parameters
j            <- 1

while (num_complete < num_points | j < 100) {
  
## record the batch 
batch.rows <- (1000 * (j - 1) + 1):(1000 * (j - 1) + 1000)
params     <- params.all[batch.rows, ]  

## duplicate these parameter values for each stochastic run 
num_param <- nrow(params)
params    <- params[rep(seq_len(nrow(params)), each = num_runs), ]
params    <- transform(params, run = rep(seq(1, num_runs), num_param))

## Add in number of time steps based on the mutation rate
params <- transform(params, nt = 0)
for (i in 1:nrow(params)) {
  if (params$mu[i] <= 0.005) {
      params$nt[i] <- 1.62e5
  } else if (params$mu[i] > 0.005 & params$mu[i] <= 0.01) {
      params$nt[i] <- 9e4
  } else {
      params$nt[i] <- 5e4
  }
}

params <- params %>% mutate(
  rptfreq = nt %/% nrpt
) 

params <- transform(params
  , seed      = sample(1:1e5, nrow(params), replace = FALSE)
  , biology   = model.choice
  )

## Transform the params to include the optimum alpha
params <- transform(params
  , opt_postrait = 0
  , opt_negtrait = 0
  , opt_beta     = 0
  )

## A bit odd to have opt_postrait and opt_beta as they are the same in a few models. In effiency though
 ## opt_postrait is efficiency so for consistency record each for all models
if (model.choice == "nt") {
  
  params$opt_postrait <- 1
  params$opt_beta     <- 1
  params$opt_negtrait <- 0
  
} else {

for (i in 1:nrow(params)) {
  
## negtrait is always parasite recovery
 params[i, ]$opt_negtrait <- with(params[i, ],
  seq(0.01, 0.99, by = 0.01)[which.max(
  power_tradeoff(
  alpha = seq(0.01, 0.99, by = 0.01)
, c     = power_c
, curv  = power_exp) / 
    (1 - (1 - seq(0.01, 0.99, by = 0.01)) * (1 - gamma0))
)]
)
 
}
 
if (model.choice == "to") {
 ## a bit funny because this isn't evolving, but record it anyway as beta
  params <- params %>% mutate(
    opt_postrait = power_tradeoff(
      alpha = opt_negtrait
    , c     = power_c
    , curv  = power_exp)
    ) %>% mutate(
    opt_beta     = opt_postrait
    )

} else {
  
  params <- params %>% mutate(
    opt_postrait = 1
  , opt_beta     = power_tradeoff(
      alpha = opt_negtrait
    , c     = power_c
    , curv  = power_exp)
    ) 

}
 
}
  
## run the sim
for (i in 1:nrow(params)) {
  
  print(i / nrow(params))
  
  time_check <- print(system.time(
    res <- try(
      with(params
        , run_sim(
   debug4              = F
 , debug4_val          = 20
 , nt                  = nt[i]
 , rptfreq             = rptfreq[i]
 , seed                = seed[i]
 , mu                  = mu[i]
 , gamma0              = gamma0[i]
 , pos_trait0          = pos_trait0[i]
 , neg_trait0          = neg_trait0[i]
 , mut_mean            = mut_mean[i]
 , mut_sd              = mut_sd[i]
 , power_c             = power_c[i]
 , power_exp           = power_exp[i]
 , N                   = N[i]
 , agg_eff_adjust      = agg_eff_adjust[i]
 , no_tradeoff         = no_tradeoff[i]
 , nt_mut_var_pos_trait = nt_mut_var_pos_trait[i]
 , tradeoff_only       = tradeoff_only[i]
 , eff_hit             = eff_hit[i]
 , parasite_tuning     = parasite_tuning[i]
 , eff_scale           = eff_scale[i]
 , progress            = "bar"
 , R0_init             = R0_init[i]
 , deterministic       = deterministic[i]
## Some defaults here for deterministic run. ALl parameters from here down are ignored if deterministic = FALSE
 , determ_length       = 400
 , determ_timestep     = 1
 , lsoda_hini          = 0.50
          ))
      , silent = TRUE
      )))
  
  if (class(res)[1] != "try-error") {
    
  ## clean up run i (add parameters and remove NA if the system went extinct)   
res <- res %>% mutate(param_num = i, elapsed_time = time_check[3])  
res <- left_join(res, params, by = "param_num")

## Can cleanup later
if (nrow(res[complete.cases(res), ]) < params[i, ]$nrpt) {
  res          <- res %>% mutate(went_extinct = 1)
  went.extinct <- TRUE 

## Remove rows after extinction
res <- res[-which(is.na(res$time)), ]
  
} else {
  res <- res %>% mutate(went_extinct = 0)
  went.extinct <- FALSE
}

  if (!exists("res_all")) {
res_all <- res
  } else {
res_all <- rbind(res_all, res)
  }

if (!went.extinct) {
num_complete <- num_complete + 1
}

  ## Save completed runs with all of the chopped runs in batches of 100 completed runs
if (((num_complete/50) %% 1) == 0) {
  Sys.sleep(1) ## For whatever reason struggles without this, no idea why
  temp_nam <- paste(paste(
    
    paste(
    "batch_runs"
  , paste(model.choice, deterministic, sep = "_")
  , sep = "/"
    )
    
    , paste(num_complete, format(Sys.time(), "%a_%b_%d_%Y"), sep = "_"), sep = "_"), ".Rds", sep = "")
  saveRDS(res_all, temp_nam)
  Sys.sleep(1)
}

  }
  
  if (num_complete == num_points) { break }

}

## Add to the batch counter
j <- j + 1

if (num_complete == num_points) { break }

}

## Final save
  temp_nam <- paste(paste(
    
    paste(
    "batch_runs"
  , paste(model.choice, deterministic, sep = "_")
  , sep = "/"
    )
    
    , paste(num_complete, format(Sys.time(), "%a_%b_%d_%Y"), sep = "_"), sep = "_"), ".Rds", sep = "")
  saveRDS(res_all, temp_nam)
