#############################################################
## Internal validation sampling strategies for exposure 
## measurement error correction
##
## Sample validation data at random/uniform or by sampling the extremes
## lindanab4@gmail.com - 20200221
#############################################################

##############################
# 0 - Load librairies + source code 
##############################

############################## 
# 1 - Helper Functions ----
##############################
# creates a data.frame that is used to sample uniformly. Data is divided in
# n_bins bins with equal distance between lower and upper bound use_variable
# in that bin. It counts the number of subjects in the data (n_data) included
# in that bin and the number of subjects that will be selected in val_data
# between the bounds of that bin.
create_bins <- function(n_bins, n_each_bin, data, use_variable, n_valdata){
  min_var <- min(data[use_variable])
  max_var <- max(data[use_variable])
  # create bounds of the bins using min and max
  bounds_bins <- seq(from = min_var, to = max_var, 
                     length.out = ( n_bins + 1 ))
  bounds_bins <- cbind(c(NA, bounds_bins), 
                       c(bounds_bins, NA))[2:( n_bins + 1 ),]
  # create data.frame with the bounds of a bin and number of subjects in data 
  # in that bin and the number of subjects that will be included in the 
  # validation sub sample from that bind (using the lower and upper bound)
  bins <- data.frame("lower_bound" = bounds_bins[,1],
                     "upper_bound" = bounds_bins[,2], 
                     "n_data_bin" = rep(NA_integer_, n_bins),
                     "n_valdata_bin" = rep(NA_integer_, n_bins))
  # count the number of subjects in one bin in the data
  bins["n_data_bin"] <- apply(bounds_bins, 1, 
                             FUN = count_n_data_bin, 
                             data = data,
                             use_variable = use_variable)
  # fill column n_valdata in bins containing the number of subjects that will
  # be sampled between the bounds of that bin
  bins <- fill_n_valdata_bin(bins, n_each_bin, n_valdata)
  bins
}
# counts the number of subjects in the data between the bounds of that bin 
# (n_data)
count_n_data_bin <- function(bounds_bin, data, use_variable){
  if (max(data[use_variable]) == bounds_bin[2]){
    condition <- data[use_variable] >= bounds_bin[1] &
      data[use_variable] <= bounds_bin[2] 
  } else { 
    condition <- data[use_variable] >= bounds_bin[1] &
      data[use_variable] < bounds_bin[2]
  }
  NROW(data[condition,])
}
# counts the number of subjects that should be sampled in the validation data 
# between the bounds of the bin (n_valdata) and fills data.frame 'bins' with 
# that number.
fill_n_valdata_bin <- function(bins, n_each_bin, n_valdata){
  # n_valdata is equal to n_data if n_data is smaller than the required size
  # of each bin (too few subjects between those bounds)
  # if n_data is equal or greater than the required size of each bin, then
  # the n_valdata is equal to n_data
  while (any(is.na(bins["n_valdata_bin"]))){# stop if n_valdata_bin is filled 
    n_data_bin_too_small <- bins["n_data_bin"] < n_each_bin
    n_valdata_bin_empty <- is.na(bins["n_valdata_bin"])
    if(any(rows <- n_data_bin_too_small & n_valdata_bin_empty)){
      bins[rows, "n_valdata_bin"] <- bins[rows, "n_data_bin"]
    }
    else {
      bins[n_valdata_bin_empty, "n_valdata_bin"] <- n_each_bin
    }
    n_each_bin <- update_n_each_bin(n_each_bin, bins, n_valdata)
  }
  bins
}
# after filling n_valdata the bins containing less subjects than the required
# size of each bin (i.e., n_each_bin), n_each_bin is updated (increased) so that 
# in the end, the total number of subjects in the validation data equals its 
# desired size
update_n_each_bin <- function(n_each_bin, bins, n_valdata){
  n_valdata_now <- n_valdata - sum(bins["n_valdata_bin"], na.rm = T)
  n_bins_not_filled <- length(which (is.na(bins["n_valdata_bin"])))
  round(n_valdata_now / n_bins_not_filled)
}
# selects the row numbers of the subjects that will be included in the 
# validation sample sampled at random
select_subjects_uniform <- function(bin, data, use_variable, seed){
  if (max(data[use_variable]) == bin[["upper_bound"]]){
    in_bin <- data[use_variable] >= bin[["lower_bound"]] & 
      data[use_variable] <= bin[["upper_bound"]]
  } else{
    in_bin <- data[use_variable] >= bin[["lower_bound"]] & 
      data[use_variable] < bin[["upper_bound"]]
  }
  n_valdata_bin <- bin[["n_valdata_bin"]]
  set.seed(seed) # needed to provide that results are reproducible
  sample(which (in_bin), n_valdata_bin)
}

############################## 
# 2 - Work horse that adds column 'in_valdata' to data that indicates if a 
# subject is included in the validation data or not.
##############################
select_valdata <- function(data, 
                           use_variable = NA,
                           size_valdata,
                           sampling_strat,
                           seed = NULL){
  # total number of subjects in data
  n <- NROW(data)
  # desired  number of subjects in valdata
  n_valdata <- ceiling(n * size_valdata)
  if (sampling_strat == "random"){
    if (is.null(seed)){
      stop("There is no seed to select the valdata at random")
    }
    data$in_valdata <- sample(c(rep(0, n - n_valdata), rep(1, n_valdata)), 
                              size = n, replace = FALSE)
  }
  else if (sampling_strat == "uniform"){
    if (is.null(seed)){
      stop("There is no seed to select the valdata uniformly")
    }
    set.seed(seed + 1) 
    # add indicator to data whether subject is included in validation sample (1) 
    # or not (0)
    data$in_valdata <- rep(0, n)
    # to samply uniformly, data is dividided in a number of bins, with equal
    # distance between 'use_variable' within these bins
    n_bins <- 10
    n_each_bin <- round(n_valdata / n_bins) # possibly less people included in
    # validation sample due to rounding
    bins <- create_bins(n_bins, n_each_bin, data, use_variable, n_valdata)

    # get rownumbers of subjects that will be included in validation sample
    rownumbers <- unlist(
      apply(bins, 1, 
            FUN = select_subjects_uniform, 
            data = data, 
            use_variable = use_variable,
            seed = (seed + 1))
      )
    # change those subjects's 0 to 1
    data$in_valdata[rownumbers] <- 1
  }
  else if (sampling_strat == "extremes"){
    # add indicator to data whether subject is included in validation sample (1) 
    # or not (0)
    data$in_valdata <- rep(0, n)
    # order the observations and select the subjects in the extremes
    rownumbers <- c(
      order(data[use_variable])[1:(n_valdata / 2)],
      order(data[use_variable])[(n - n_valdata / 2 + 1):n]
      )
    data$in_valdata[rownumbers] <- 1
  }
  data
}