#######################################################
### Set up parameter values for the stochastic runs ###
#######################################################

######
## Set up parameter values to explore:
## 1) Time to equilibrium
## 2) Movement away from equilibrium / sd around equilibrium
## 3) Feedback of population size, mutation probability and sd on eco-evo feedbacks and 1 and 2 above
######

######
## Biological assumptions
## 1) Traits evolve either with 0 bias or with a bias towards inf host recovery rate
## 2) Parasites don't take a hit on efficiency when evolving in recovery or take a small hit
  ## another way to say this is 0 correlation in trait evolution or negative. No positive
######

######
## Set up parameter values to range over for tradeoff only model:
## A) start alpha -- starting parasite recovery rate
 # qunif(lhs, min = 0.01, max = 0.99)
## 1) mu          -- mutation rate
 # qunif(lhs, min = 0.005, max = 0.20)
## 2) mut_mean    -- mean in mutation (bias)
 # 0
## 3) mut_sd      -- sd in mutation
 # qunif(lhs, min = 0.05, max = 0.20)
## 4) power_c     -- height of tradeoff curve
 # qunif(lhs, min = 0.005, max = 0.1)
## 5) power_exp   -- slope of tradeoff curve
 # qunif(lhs, min = 1.5, max = 5.5)
## 6) gamma       -- host intrinsic recovery rate
 # qunif(lhs, min = 0.01, max = 0.4)
## 7) N           -- population size
 # qunif(lhs, min = 100, max = 2500)

## Additional parameters to include for efficiency model:
## B) start eff   -- starting parasite efficiency parameter
 # qunif(lhs, min = 0.01, max = 0.99)
## 8) eff_hit     -- size of negative correlation between parasite evo in alpha and efficiency
 # qunif(lhs, min = 0.01, max = 1)
##### 

######
## We will want to explore variation in these parameter values between:
## 1) Tradeoff curve with no second trait. 
  ## tradeoff_only = TRUE; parasite_tuning = FALSE; agg_eff_adjust = FALSE
## 2) Tradeoff curve with proportional beta
  ## tradeoff_only = FALSE; parasite_tuning = FALSE; agg_eff_adjust = FALSE
##### 

## Set up the parameter values over which to sample
num_runs      <- 1
deterministic <- FALSE
num_points    <- 1500

## Some latin hypercube sampling stuff for tradeoff only, need an extra column for efficiency runs
 ## Expand this to have two different files for tradeoff only and efficiency separately
if (!file.exists("lhs_samps.csv")) {
lhs     <- randomLHS(6000, 7) 
write.csv(lhs, "lhs_samps.csv")
} else {
lhs     <- read.csv("lhs_samps.csv")
lhs     <- lhs[, -1]
}

params        <- data.frame(
   parasite_tuning     = FALSE
 , tradeoff_only       = FALSE
 , agg_eff_adjust      = TRUE
## for efficiency runs only add this as a hypercube sample
 , eff_hit             = qunif(lhs[, 8], min = 0.00, max = 1.00) # 0.5
 , num_points          = num_points
 , mut_var             = "beta"
 , mu                  = qunif(lhs[, 1], min = 0.001, max = 0.10) # 0.01 # 
 , mut_mean            = 0
 , mut_sd              = qunif(lhs[, 2], min = 0.01, max = 0.30) # 0.1  # 
## Ignored under conditions of no tuning
 , alpha0              = qunif(lhs[, 3], min = 0.01, max = 0.99) # 0.03 # 
 , tune0               = 0.30 # qunif(lhs, min = 0.01, max = 0.99) # 
 , power_c             = qunif(lhs[, 4], min = 0.005, max = 0.1) # 0.01 # 
 , power_exp           = qunif(lhs[, 5], min = 1.5, max = 5.5) # 3    # 
 , N                   = round(qunif(lhs[, 6], min = 100, max = 2500)) # 600  # 
 , gamma0              = qunif(lhs[, 7], min = 0.01, max = 0.4) # 0.2
 , eff_scale           = 30
 , R0_init             = 2
 , deterministic       = deterministic
)

## duplicate these parameter values for each stochastic run 
num_param <- nrow(params)
params    <- params[rep(seq_len(nrow(params)), each = num_runs), ]
params    <- transform(params, run = rep(seq(1, num_runs), num_param))

## Add in number of time steps based on the mutation rate
params <- transform(params, nt = 0)
for (i in 1:nrow(params)) {
  if (params$mu[i] <= 0.005) {
      params$nt[i] <- 1e6
  } else if (params$mu[i] > 0.005 & params$mu[i] <= 0.01) {
      params$nt[i] <- 5e5
  } else {
      params$nt[i] <- 3e5
  }
}

params <- params %>% mutate(
  rptfreq = max(nt / num_points, 1)
) %>% mutate(
  nrpt    = nt %/% rptfreq
)

params <- transform(params
  , param_num = seq(1, nrow(params))
  , seed      = sample(1:1e5, nrow(params), replace = FALSE)
  , biology   = "efficiency"
  #, biology   = "tradeoff_only"
  )

## Transform the params to include the optimum alpha
params <- transform(params, opt_alpha = 0)
for (i in 1:nrow(params)) {
params[i, ]$opt_alpha <- with(params[i, ],
  seq(0.01, 0.99, by = 0.01)[which.max(
  power_tradeoff(
  alpha = seq(0.01, 0.99, by = 0.01)
, c     = power_c
, curv  = power_exp) / 
    (1 - (1 - seq(0.01, 0.99, by = 0.01)) * (1 - gamma0))
)]
)
}

i = 1
 ## Nov 28: currently at i = 56 for tradeoff only
 ## Nov 28: currently at i = 13 for efficiency
for (i in 1:nrow(params)) {
  
  print(i / nrow(params))
  
  time_check <- print(system.time(
    res_1000 <- try(
      with(params
        , run_sim(
   debug4              = F
 , nt                  = nt[i]
 , rptfreq             = rptfreq[i]
 , mut_var             = mut_var[i]
 , seed                = seed[i]
 , mu                  = mu[i]
 , gamma0              = gamma0[i]
 , alpha0              = alpha0[i]
 , tune0               = tune0[i]
 , mut_mean            = mut_mean[i]
 , mut_sd              = mut_sd[i]
 , power_c             = power_c[i]
 , power_exp           = power_exp[i]
 , N                   = N[i]
 , agg_eff_adjust      = agg_eff_adjust[i]
 , tradeoff_only       = tradeoff_only[i]
 , eff_hit             = eff_hit[i]
 , parasite_tuning     = parasite_tuning[i]
 , eff_scale           = eff_scale[i]
 , progress            = "text"
 , R0_init             = R0_init[i]
 , deterministic       = deterministic[i]
## Some defaults here for deterministic run. ALl parameters from here down are ignored if deterministic = FALSE
 , determ_length       = 400
 , determ_timestep     = 1
 , lsoda_hini          = 0.50
## Choose these from the parameter values data frame so that the deterministic run starts from the 
 ## same place as the stochastic run
 , Imat_seed           = c(
#   which(c(round(seq(0.01, 0.99, by = 0.01), 2), 0.999) == params$alpha0[i])
# , which(c(round(seq(0.01, 0.99, by = 0.01), 2), 0.999) == params$tune0[i]))
   15        ## tune
 , 85        ## alpha
          )))
      , silent = TRUE
      )))
  
  if (class(res_1000) != "try-error") {
 
  ## clean up run i (add parameters and remove NA if the system went extinct)   
res_1000 <- res_1000 %>% mutate(param_num = i, elapsed_time = time_check[3])  
res_1000 <- left_join(res_1000, params, by = "param_num")
res_1000 <- res_1000[complete.cases(res_1000), ]

  if (i == 1) {
res_1000_all <- res_1000
  } else {
res_1000_all <- rbind(res_1000_all, res_1000)
  }

}

if ((i/50 %% 1) == 0) {
  if (params$tradeoff_only[i] == TRUE) {
  temp_nam <- paste(paste("res_1000_all_stochas_to", format(Sys.time(), "%a_%b_%d_%Y"), sep = "_"), ".Rds", sep = "")
  } else {
  temp_nam <- paste(paste("res_1000_all_stochas_eff", format(Sys.time(), "%a_%b_%d_%Y"), sep = "_"), ".Rds", sep = "")  
  }
  saveRDS(res_1000_all, temp_nam)
}

}

### Plotting code copied and pasted here for some debugging to check parameter value ranges
res_1000_stochas <- res_1000_all
# res_1000_stochas <- res_1000_stochas %>% filter(param_num == 55)

res_1000_stochas_s <- res_1000_stochas %>%
  group_by(time) %>%
  summarize(
    q05_mean_plalpha = quantile(mean_plalpha, 0.05)
  , q25_mean_plalpha = quantile(mean_plalpha, 0.25)
  , q50_mean_plalpha = quantile(mean_plalpha, 0.50)
  , q75_mean_plalpha = quantile(mean_plalpha, 0.75)
  , q95_mean_plalpha = quantile(mean_plalpha, 0.95)
  , q05_mean_plbeta  = quantile(mean_plbeta, 0.05)
  , q25_mean_plbeta  = quantile(mean_plbeta, 0.25)
  , q50_mean_plbeta  = quantile(mean_plbeta, 0.50)
  , q75_mean_plbeta  = quantile(mean_plbeta, 0.75)
  , q95_mean_plbeta  = quantile(mean_plbeta, 0.95)
  , q50_mean_beta    = quantile(mean_beta, 0.50)) %>%
  mutate(R0 = 0)

ggplot(res_1000_stochas_s, aes(time, tlink$linkinv(q50_mean_plalpha))) + geom_path()
ggplot(res_1000_stochas_s, aes(time, tlink$linkinv(q50_mean_plbeta))) + geom_path()
ggplot(res_1000_stochas_s, aes(time, q50_mean_beta)) + geom_path()

tlink <- make.link("cloglog")

## Further exploration of optimum

power_R0       <- function (alpha, c, curv, gamma, N) {
  ( N * c * alpha ^ (1 / curv) )  / ( 1 - ((1 - alpha) * (1 - gamma)) )
}

plot(
data.frame(
  alpha = seq(0.01, 0.99, by = 0.01)
, R0    = power_R0(
  alpha = seq(0.01, 0.99, by = 0.01)
, c     = res_1000_stochas$power_c[1]
, curv  = res_1000_stochas$power_exp[1]
, gamma = res_1000_stochas$gamma0[1]
, N     = res_1000_stochas$N[1])
)
)

## Some initial plotting of these hypercube results.
 ## Remember we want:
## 1) Time to equilibrium. Treat this as first passage time. 
 ## First need to add equilibrium to the output. Added to params
 ## !*! May want some sort of eps to check if the mean has come within?
## 2) Transient movement when approaching equilibrium
 ## Not quite sure about this one but for plotting purposes treat as sd prior to equilibrium for now
## 3) SD around equilibrium
 ## Mean SD after first passage
## 4) ... 

## Jump through some hoops to determine when the chains reached equilibrium
res_1000_all_s <- res_1000_all %>%
  mutate(
    higher_start = ifelse(alpha0 > opt_alpha, 1, 0)
  , lower_start  = ifelse(alpha0 < opt_alpha, 1, 0)
  , higher_equil = ifelse(mean_alpha > opt_alpha, 1, 0)
  , lower_equil  = ifelse(mean_alpha < opt_alpha, 1, 0)) %>%
  mutate(
  first_pass_setup = ifelse(lower_start > 1
      , ifelse(mean_alpha > opt_alpha, 1, 0)
      , ifelse(mean_alpha < opt_alpha, 1, 0))
  ) %>% 
  group_by(param_num) %>%
  mutate(
    time_point = row_number()
  ) %>%
  mutate(
    when_equil = min(which(first_pass_setup == 1))
  ) %>% 
  mutate(
    at_equil = ifelse(time_point >= when_equil, 1, 0)
  ) %>% 
  mutate(
    cum_time = cumsum(rptfreq)
  )

## Then calc sd prior and after equilibirum. Could also consider looking at some sort of
 ## transient max or min or something
res_1000_all_s.a <- res_1000_all_s %>%
  filter(at_equil == 1) %>%
  group_by(param_num) %>%
  summarize(
    first_equil    = mean(when_equil)
  , alpha.sd_after = mean(sd_alpha)
  , beta.sd_after  = mean(sd_beta)
  , time_to_equil  = min(cum_time))

res_1000_all_s.b <- res_1000_all_s %>%
  filter(at_equil == 0) %>%
  group_by(param_num) %>%
  summarize(
    alpha.sd_before = mean(sd_alpha)
  , beta.sd_before = mean(sd_beta))

## Melt first to get the variables of interest with names and values and then add back parameter values
res_1000_all_s.gg <- left_join(res_1000_all_s.a, res_1000_all_s.b)
res_1000_all_s.gg <- res_1000_all_s.gg[, -2]
## take log of first_equil then melt
res_1000_all_s.gg <- transform(res_1000_all_s.gg, time_to_equil = log(time_to_equil))
res_1000_all_s.gg <- melt(res_1000_all_s.gg, "param_num")

## melt the parameter values as well
params.s    <- params %>% dplyr::select(param_num, mu, mut_sd, alpha0, power_c, power_exp, N, gamma0
  , eff_hit)
params.melt <- melt(params.s, "param_num")

## Add pack the parameter values for plotting
res_1000_all_s.gg        <- left_join(res_1000_all_s.gg, params.melt, by = "param_num")
names(res_1000_all_s.gg) <- c("param_num", "Out.Name", "Out.Value", "Param.Name", "Param.Value")
res_1000_all_s.gg        <- as.data.frame(res_1000_all_s.gg)

## add in a column to color by 
res_1000_all_s.gg <- left_join(res_1000_all_s.gg, params.s[, c(1, 2)], "param_num")

## remove the rows with NA where the chains get to equil before the first time point
res_1000_all_s.gg <- res_1000_all_s.gg[complete.cases(res_1000_all_s.gg), ]

## gg pairs plotting of the hypercube results
ggplot(res_1000_all_s.gg, aes(Param.Value, Out.Value)) +
    geom_point(aes(colour = mu)) +
    facet_grid(Out.Name ~ Param.Name, scale = "free") +
    scale_color_viridis() 

power_trade_dat_prob <- data.frame(
    alpha = seq(0.01, 1.0, by = 0.01)
  , beta  = power_tradeoff(alpha = seq(0.01, 1.0, by = 0.01), c = 0.75, curv = 2)
  , R0    = power_tradeoff(alpha = seq(0.01, 1.0, by = 0.01), c = 0.75, curv = 2) / 
    (1 - (1 - seq(0.01, 1.0, by = 0.01)) * (1 - 0.20) * (1 - 0.01))
  )

power_trade_dat_prob <- power_trade_dat_prob %>%
  mutate(
    beta_rel = beta / max(beta)
  , R0_rel   = R0 / max(R0)
  )





