#############################################################
## Internal validation sampling strategies for exposure 
## measurement error correction
##
## Executive script that produces output of the simulation study
## lindanab4@gmail.com - 20200305
#############################################################

##############################
# 0 - Load librairies + source code 
##############################
source(file = "./rcode/sim/run_sim.R")
args <- commandArgs(trailingOnly = TRUE)
args <- as.numeric(args)
# Select datagen_scenarios and analysis_scenarios to be used
# args <- c(1, 5000)
use_datagen_scenarios <- datagen_scenarios()[args[1] + 1, ] # row 1 is scen_num 0
use_analysis_scenarios <- subset(analysis_scenarios(), sampling_strat == "uniform")
# seeds
source(file = "./rcode/tools/remove_data.R")
analysis_scenario <- use_analysis_scenarios[1, ] # for each scen_num seeds are identical
analysis_scenario$sampling_strat = "random"
file <- seek_files_analysis_scenario(analysis_scenario,
                                     use_datagen_scenarios,
                                     data_dir = "./data/output")
seeds <- readRDS(file)[,5]
seeds <- c(rep(0, args[1] * args[2]), seeds) # little weird work around to get
# seeds[(rep * scen_num + i)] in perform_one_run (run_sim.R) equal to the seeds

##############################
# 1 - Run simulation study 
##############################
# Run simulation study
run_sim(rep = args[2],
        use_datagen_scenarios = use_datagen_scenarios,
        use_analysis_scenarios = use_analysis_scenarios,
        seeds = seeds)