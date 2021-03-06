###################################
## Parameters for the simulation ##
###################################

nt            <- 1e5
num_points    <- 600 
rptfreq       <- max(nt / num_points, 1) 
num_runs      <- 5
deterministic <- TRUE ## run the model via reaction-diffusion deterministic?

## Need to cover a range of: (over a number of replicate runs)
 ## mutation frequency
 ## mutation standard deviation
 ## starting mortality rate
 ## starting efficiency
 ## efficiency scale
## Also need to consider running across different shapes of the tradeoff curve
 ## power_c
 ## power_exp

## Set up parameters in a manner to correspond to output data frame
params <- expand.grid(
   nt                  = nt
 , rptfreq             = rptfreq
 , deterministic       = deterministic
  ## ** !! key parameters.
  ## (TRUE, --, --) for tuning
  ## (FALSE, TRUE, --) for just tradeoff curve
  ## (FALSE, FALSE, FALSE) for _no_ parasite beta setback with evo change in alpha
  ## (FALSE, FALSE, TRUE) for parasite beta setback with evo change in alpha
  ## for nearly neutral see Ben's results and use Ben's script
 , parasite_tuning     = FALSE
 , tradeoff_only       = TRUE
 , agg_eff_adjust      = FALSE
 , mut_var             = "beta"
 , d                   = 0.01
## Need to convert this to a rate of diffusion if deterministic == TRUE
 , mu                  = if (!deterministic) {
                             c(0.01)
                             ## c(1E-5, 5E-5, 1E-4, 5E-4, 1E-3, 5E-3, 1E-2)
                         } else {
                             ##  0.025
                             0.002
                                        #  0.20
                         }
 , mut_mean            = 0 # -0.4
 , mut_sd              = c(0.15)  #  c(0.01, 0.05, 0.10, 0.15, 0.20, 0.25) 
## If deterministic == TRUE, start with a whole array of possible strain values for virulence (done internally)
 , alpha0              = 0.01 # c(0.05, 0.95) c(0.05, 0.05, 0.21, 0.45, 0.81) 
 , tune0               = 0.03 # 0.97 # c(0.05, 0.95)
 , tol0                = 1
 , res0                = 1
## min recovery rate driven by the host. For SIS without host mortality can't allow parasites to drop recovery to 0 without
 ## any other background mortality or recovery or hosts will evolve to either 0 recovery or max recovery depending on whether
  ## the tradeoff gamma is > or < 1
 , gamma0              = 0.2
 , run                 = seq(1, num_runs, by = 1)
 , mut_host_mean_shift = 1      
 , mut_host_sd_shift   = 1
 , mut_host_mu_shift   = 100000000000 # need some huge number here
 , mut_host_res_bias   = 0
 , host_dyn_only       = FALSE
 , power_c             = if (!deterministic) {
                             0.01 #  0.75
                         } else {
                             10
                         } 
 , power_exp           = 3 # 2
 , b_decay             = 2.3
 , b                   = 0.5
 , N                   = 400
 , birth_type          = "fill"
 , eff_scale           = 30 # c(10, 30, 50, 70, 90)
  )

params <- transform(params
  , param_num = seq(1, nrow(params))
  , seed      = sample(1:1e5, nrow(params), replace = FALSE))

## Also run AD version?
AD_also <- FALSE

