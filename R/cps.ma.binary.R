#' Simulation-based power estimation for binary outcome multi-arm
#' cluster-randomized trials.
#'

#' This function uses iterative simulations to determine
#' approximate power for multi-arm cluster-randomized controlled trials with
#' binary outcomes of interest. Users can modify a variety of parameters to
#' suit the simulations to their desired experimental situation.
#' This function validates the user's input and passes the necessary
#' arguments to an internal function, which performs the simulations.
#' This function returns the summary power values for each treatment arm.
#'
#' Users must specify the desired number of simulations, number of subjects per
#' cluster, number of clusters per treatment arm, group probabilities, and the
#' between-cluster variance. Significance level, analytic method, progress
#' updates, poor/singular fit override, and whether or not to return the
#' simulated data may also be specified. The internal function can be called
#' directly by the user to return the fitted models rather than the power
#' summaries (see \code{?cps.ma.normal.internal} for details).
#'
#' Because the model for binary outcomes may be slower to fit than those for
#' other distributions, this function may be slower than its normal or
#' count-distributed counterparts. Users can spread the simulated data
#' generation and model fitting tasks across multiple cores using the
#' \code{cores} argument. Users should expect that parallel computing may make
#' model fitting faster than using a single core for more complicated models.
#' For simpler models, users may prefer to use single thread computing
#' (\code{cores}=1), as the processes involved in allocating memory and
#' copying data across cores also may take some time. For time-savings,
#' this function stops execution early if estimated power < 0.5 or more
#' than 25\% of models produce a singular fit or non-convergence warning
#' message, unless \code{poorFitOverride = TRUE}.
#'
#' Non-convergent models are not included in the calculation of exact confidence
#' intervals.
#'
#' @section Testing details:
#' This function has been verified, where possible, against reference values from the NIH's GRT
#' Sample Size Calculator, PASS11, \code{CRTsize::n4prop}, \code{clusterPower::cps.binary}, and
#' \code{clusterPower::cpa.binary}.
#'
#' @param nsim Number of datasets to simulate; accepts integer (required).
#' @param nsubjects Number of subjects per cluster (required); accepts an
#' integer if all are equal and \code{narms} and \code{nclusters} are provided.
#' Alternately, the user can supply a list with one entry per arm if the
#' cluster sizes are the same within the arm, or, if they are not the same
#' within the arms, the user can supply a list of vectors where each vector
#' represents an arm and each entry in the vector is the number of subjects
#' per cluster.
#' @param narms Integer value representing the number of trial arms.
#' @param nclusters An integer or vector of integers representing the number
#' of clusters in each arm.
#' @param probs Expected absolute treatment effect probabilities for each arm;
#' accepts a scalar or a vector of length \code{narms} (required).
#' @param sigma_b_sq Between-cluster variance; accepts a vector of length
#' \code{narms} (required).
#' @param alpha Significance level; default = 0.05.
#' @param allSimData Option to output list of all simulated datasets;
#' default = FALSE.
#' @param method Analytical method, either Generalized Linear Mixed Effects
#' Model (GLMM) or Generalized Estimating Equation (GEE). Accepts c('glmm',
#' 'gee') (required); default = 'glmm'.
#' @param multi_p_method A string indicating the method to use for adjusting
#' p-values for multiple comparisons. Choose one of "holm", "hochberg",
#' "hommel", "bonferroni", "BH", "BY", "fdr", "none". The default is
#' "bonferroni". See \code{?p.adjust} for additional details.
#' @param quiet When set to FALSE, displays simulation progress and estimated completion time; default is FALSE.
#' @param seed Option to set.seed. Default is NULL.
#' @param poorFitOverride Option to override \code{stop()} if more than 25\% of fits fail to converge or
#' power<0.5 after 50 iterations; default = FALSE.
#' @param lowPowerOverride Option to override \code{stop()} if the power
#' is less than 0.5 after the first 50 simulations and every ten simulations
#' thereafter. On function execution stop, the actual power is printed in the
#' stop message. Default = FALSE. When TRUE, this check is ignored and the
#' calculated power is returned regardless of value.
#' @param timelimitOverride Logical. When FALSE, stops execution if the estimated
#' completion time is more than 2 minutes. Defaults to TRUE.
#' @param cores String ("all"), NA, or scalar value indicating the number of cores
#' to be used for parallel computing. Default = NA (no parallel computing).
#' @param tdist Logical value indicating whether simulated data should be
#' drawn from a t-distribution rather than the normal distribution.
#' Default = FALSE.
#' @param nofit Option to skip model fitting and analysis and return the
#' simulated data.
#' Defaults to \code{FALSE}.
#' @param optmethod User-specified optimizer method. Accepts \code{bobyqa},
#' \code{Nelder_Mead} (default), and optimizers wrapped in the \code{optimx} package.
#' @param return.all.models Logical; Returns all of the fitted models and the
#' simulated data.
#' Defaults to FALSE.
#' @return A list with the following components:
#' \describe{
#'   \item{power}{Data frame with columns "power" (Estimated statistical power),
#'                "lower.95.ci" (Lower 95\% confidence interval bound),
#'                "upper.95.ci" (Upper 95\% confidence interval bound).}
#'   \item{model.estimates}{Data frame with columns corresponding
#'   to each arm with descriptive suffixes as follows:
#'                   ".Estimate" (Estimate of treatment effect for a given
#'                   simulation),
#'                   "Std.Err" (Standard error for treatment effect estimate),
#'                   ".zval" (for GLMM) | ".wald" (for GEE), and
#'                   ".pval" (the p-value estimate).}
#'   \item{overall.power}{Table of F-test (when method="glmm") or chi^{2}
#'   (when method="gee") significance test results.}
#'   \item{overall.power.summary}{Summary overall power of treatment model
#'   compared to the null model.}
#'   \item{sim.data}{Produced when allSimData==TRUE. List of \code{nsim}
#'   data frames, each containing:
#'                   "y" (simulated response value),
#'                   "trt" (indicator for treatment group or arm), and
#'                   "clust" (indicator for cluster).}
#'   \item{model.fit.warning.percent}{Character string containing the percent
#'   of \code{nsim} in which the glmm fit was singular or failed to converge,
#'   produced only when method = "glmm" & allSimData = FALSE.
#'   }
#'   \item{model.fit.warning.incidence}{Vector of length \code{nsim} denoting
#'   whether or not a simulation glmm fit triggered a "singular fit" or
#'   "non-convergence" error, produced only when method = "glmm" &
#'   allSimData=TRUE.
#'   }
#'   }
#' If \code{nofit = T}, a data frame of the simulated data sets, containing:
#' \itemize{
#'   \item "arm" (Indicator for treatment arm)
#'   \item "cluster" (Indicator for cluster)
#'   \item "y1" ... "yn" (Simulated response value for each of the \code{nsim} data sets).
#'   }
#'
#' @examples
#' \dontrun{
#' bin.ma.rct.unbal <- cps.ma.binary(nsim = 12,
#'                             nsubjects = list(rep(20, times=15),
#'                             rep(15, times=15),
#'                             rep(17, times=15)),
#'                             narms = 3,
#'                             nclusters = 15,
#'                             probs = c(0.35, 0.43, 0.50),
#'                             sigma_b_sq = c(0.1, 0.1, 0.1),
#'                             alpha = 0.05, allSimData = TRUE,
#'                             seed = 123, cores="all")
#'
#' bin.ma.rct.bal <- cps.ma.binary(nsim = 100, nsubjects = 50, narms=3,
#'                             nclusters=8,
#'                             probs = c(0.35, 0.4, 0.5),
#'                             sigma_b_sq = 0.1, alpha = 0.05,
#'                             quiet = FALSE, method = 'glmm',
#'                             allSimData = FALSE,
#'                             multi_p_method="none",
#'                             seed = 123, cores="all",
#'                             poorFitOverride = FALSE)
#'}
#' @author Alexandria C. Sakrejda (\email{acbro0@@umass.edu}), Alexander R. Bogdan, and Ken Kleinman (\email{ken.kleinman@@gmail.com})
#' @export
cps.ma.binary <- function(nsim = 1000,
                          nsubjects = NULL,
                          narms = NULL,
                          nclusters = NULL,
                          probs = NULL,
                          sigma_b_sq = NULL,
                          alpha = 0.05,
                          quiet = FALSE,
                          method = 'glmm',
                          multi_p_method = "bonferroni",
                          allSimData = FALSE,
                          seed = NULL,
                          cores = NA,
                          tdist = FALSE,
                          poorFitOverride = FALSE,
                          lowPowerOverride = FALSE,
                          timelimitOverride = TRUE,
                          nofit = FALSE,
                          optmethod = "Nelder-Mead",
                          return.all.models = FALSE) {
  converge <- NULL
  # use this later to determine total elapsed time
  start.time <- Sys.time()
  
  if (is.null(narms)) {
    stop("ERROR: narms is required.")
  }
  
  if (narms < 3) {
    stop("ERROR: LRT significance not calculable when narms < 3. Use cps.binary() instead.")
  }
  
  # create nclusters if not provided directly by user
  if (isTRUE(is.list(nsubjects))) {
    if (is.null(nclusters)) {
      nclusters <- vapply(nsubjects, length, 0)
    }
  }
  if (length(nclusters) == 1 & !isTRUE(is.list(nsubjects))) {
    nclusters <- rep(nclusters, narms)
  }
  if (length(nclusters) > 1 & length(nsubjects) == 1) {
    narms <- length(nclusters)
  }
  
  # input validation steps
  if (!is.wholenumber(nsim) || nsim < 1 || length(nsim) > 1) {
    stop("nsim must be a positive integer of length 1.")
  }
  if (isTRUE(is.null(nsubjects))) {
    stop("nsubjects must be specified. See ?cps.ma.binary for help.")
  }
  if (length(nsubjects) == 1 & !isTRUE(is.numeric(nclusters))) {
    stop("When nsubjects is scalar, user must supply nclusters (clusters per arm)")
  }
  if (length(nsubjects) == 1 & length(nclusters) == 1 &
      !isTRUE(is.numeric(narms))) {
    stop("User must provide narms when nsubjects and nclusters are both scalar.")
  }
  
  # nclusters must be whole numbers
  if (sum(is.wholenumber(nclusters) == FALSE) != 0 ||
      nclusters < 1) {
    stop("nclusters must be postive integer values.")
  }
  
  # nsubjects must be whole numbers
  if (sum(is.wholenumber(unlist(nsubjects)) == FALSE) != 0 || 
    any(unlist(nsubjects) < 1)) {
    stop("nsubjects must be positive integer values.")
  }
  
  # Generate nclusters vector when a scalar is provided but nsubjects is a vector
  if (length(nclusters) == 1 & length(nsubjects) > 1) {
    nclusters <- rep(nclusters, length(nsubjects))
  }
  
  # Create nsubjects structure from narms and nclusters
  if (mode(nsubjects) == "list") {
    str.nsubjects <- nsubjects
  } else {
    if (length(nsubjects) == 1) {
      str.nsubjects <- lapply(nclusters, function(x)
        rep(nsubjects, x))
    } else {
      if (length(nsubjects) != narms) {
        stop("nsubjects must be length 1 or length narms if not provided in a list.")
      }
      str.nsubjects <- list()
      for (i in 1:length(nsubjects)) {
        str.nsubjects[[i]] <- rep(nsubjects[i], times = nclusters[i])
      }
    }
  }
  
  # allows for probs, sigma_b_sq to be entered as scalar
  if (length(sigma_b_sq) == 1) {
    sigma_b_sq <- rep(sigma_b_sq, narms)
  }
  if (length(probs) == 1) {
    probs <- rep(probs, narms)
  }
  
  if (length(probs) != narms) {
    stop(
      "Length of probs must equal narms, or be provided as a scalar if probs for all arms are equal."
    )
  }
  
  if (length(sigma_b_sq) != narms) {
    stop(
      "Length of variance parameters sigma_b_sq must equal narms, or be provided as a scalar
         if sigma_b_sq for all arms are equal."
    )
  }
  
  validateVariance(
    dist = "bin",
    alpha = alpha,
    ICC = NA,
    sigma_sq = NA,
    sigma_b_sq = sigma_b_sq,
    ICC2 = NA,
    sigma_sq2 = NA,
    sigma_b_sq2 = NA,
    method = method,
    quiet = quiet,
    all.sim.data = allSimData,
    poor.fit.override = poorFitOverride,
    cores = cores,
    probs = probs
  )
  
  # run the simulations
  binary.ma.rct <- cps.ma.binary.internal(
    nsim = nsim,
    str.nsubjects = str.nsubjects,
    probs = probs,
    sigma_b_sq = sigma_b_sq,
    alpha = alpha,
    quiet = quiet,
    method = method,
    all.sim.data = allSimData,
    seed = seed,
    poor.fit.override = poorFitOverride,
    low.power.override = lowPowerOverride,
    timelimitOverride = timelimitOverride,
    tdist = tdist,
    cores = cores,
    nofit = nofit,
    optmethod = optmethod,
    return.all.models = return.all.models
  )
  
  #option to return simulated data only
  if (nofit == TRUE) {
    return(binary.ma.rct)
  }
  
  models <- binary.ma.rct[[1]]
  
  # Create object containing summary statement
  summary.message = paste0(
    "Monte Carlo Power Estimation based on ",
    nsim,
    " Simulations: Parallel Design, Binary Outcome, ",
    narms,
    " Arms."
  )
  
  # Create method object
  long.method = switch(method, glmm = 'Generalized Linear Mixed Model',
                       gee = 'Generalized Estimating Equation')
  
  # Create object containing group-specific variance parameters
  armnames <- vector(mode = "character", length = narms)
  for (i in 1:narms) {
    armnames[i] <- paste0("Arm.", i)
  }
  
  var.parms = data.frame('sigma_b_sq' = sigma_b_sq,
                         "probs" = probs)
  rownames(var.parms) <- armnames
  
  # Create object containing group-specific cluster sizes
  names(str.nsubjects) <- armnames
  cluster.sizes <- str.nsubjects
  
  
  #Organize output for GLMM
  if (method == "glmm") {
    Estimates = matrix(NA, nrow = nsim, ncol = narms)
    std.error = matrix(NA, nrow = nsim, ncol = narms)
    z.val = matrix(NA, nrow = nsim, ncol = narms)
    p.val = matrix(NA, nrow = nsim, ncol = narms)
    
    for (i in 1:nsim) {
      Estimates[i,] <- models[[i]][[10]][, 1]
      std.error[i,] <- models[[i]][[10]][, 2]
      z.val[i,] <- models[[i]][[10]][, 3]
      p.val[i,] <-
        p.adjust(models[[i]][[10]][, 4], method = multi_p_method)
    }
    
    # Organize the row/col names for the model estimates output
    keep.names <- rownames(models[[1]][[10]])
    
    names.Est <- rep(NA, narms)
    names.st.err <- rep(NA, narms)
    names.zval <- rep(NA, narms)
    names.pval <- rep(NA, narms)
    names.power <- rep(NA, narms)
    
    for (i in 1:length(keep.names)) {
      names.Est[i] <- paste(keep.names[i], ".Estimate", sep = "")
      names.st.err[i] <- paste(keep.names[i], ".Std.Err", sep = "")
      names.zval[i] <- paste(keep.names[i], ".zval", sep = "")
      names.pval[i] <- paste(keep.names[i], ".pval", sep = "")
      names.power[i] <- paste(keep.names[i], ".power", sep = "")
    }
    colnames(Estimates) <- names.Est
    colnames(std.error) <- names.st.err
    colnames(z.val) <- names.zval
    colnames(p.val) <- names.pval
    
    # convergence
    cps.model.temp <-
      data.frame(unlist(binary.ma.rct[[3]]), p.val)
    colnames(cps.model.temp)[1] <- "converge"
    cps.model.temp2 <-
      dplyr::filter(cps.model.temp, converge == TRUE)
    if (nrow(cps.model.temp2) < (.25 * nsim)) {
      warning(paste0(
        nrow(cps.model.temp2),
        " models converged. Check model parameters."
      ),
      immediate. = TRUE)
    }
    
    
    # Organize the LRT output
    LRT.holder <-
      matrix(
        unlist(binary.ma.rct[[2]]),
        ncol = 3,
        nrow = nsim,
        byrow = TRUE,
        dimnames = list(seq(1:nsim),
                        colnames(binary.ma.rct[[2]][[1]]))
      )
    LRT.holder <- cbind(LRT.holder, cps.model.temp["converge"])
    LRT.holder <- LRT.holder[LRT.holder[, "converge"] == TRUE, ]
    sig.LRT <-  ifelse(LRT.holder[, 3] < alpha, 1, 0)
    
    
    # Calculate and store power estimate & confidence intervals
    power.parms <- cbind(confintCalc(
      multi = TRUE,
      alpha = alpha,
      p.val = as.vector(cps.model.temp2[, 3:length(cps.model.temp2)])
    ),
    multi_p_method)
    
    # Store simulation output in data frame
    ma.model.est <-
      data.frame(Estimates, std.error, z.val, p.val, binary.ma.rct[[3]])
    ma.model.est <-
      ma.model.est[, -grep('.*ntercept.*', names(ma.model.est))]
    
    # performance messages
    total.est <-
      as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
    hr.est <-  total.est %/% 3600
    min.est <-  total.est %/% 60
    sec.est <-  round(total.est %% 60, 0)
    message(
      paste0(
        "Simulations Complete! Time Completed: ",
        Sys.time(),
        "\nTotal Runtime: ",
        hr.est,
        'Hr:',
        min.est,
        'Min:',
        sec.est,
        'Sec'
      )
    )
    
    ## Output objects for GLMM
    # Create list containing all output (class 'crtpwr.ma') and return
    
    
    if (allSimData == TRUE && return.all.models == FALSE) {
      complete.output = structure(
        list(
          "overview" = summary.message,
          "nsim" = nsim,
          "power" =
            prop_H0_rejection(
              alpha = alpha,
              nsim = nsim,
              sig.LRT = sig.LRT
            ),
          "beta" = power.parms['Beta'],
          "overall.power2" = power.parms,
          "overall.power" = LRT.holder,
          "method" = long.method,
          "alpha" = alpha,
          "cluster.sizes" = cluster.sizes,
          "n.clusters" = nclusters,
          "variance.parms" = var.parms,
          "probs" = probs,
          "model.estimates" = ma.model.est,
          "convergence" = binary.ma.rct[[3]],
          "sim.data" = binary.ma.rct[["sim.data"]]
        ),
        class = 'crtpwr.ma'
      )
    }
    
    if (return.all.models == TRUE) {
      complete.output = structure(
        list(
          "overview" = summary.message,
          "nsim" = nsim,
          "power" =
            prop_H0_rejection(
              alpha = alpha,
              nsim = nsim,
              sig.LRT = sig.LRT
            ),
          "beta" = power.parms['Beta'],
          "overall.power2" = power.parms,
          "overall.power" = LRT.holder,
          "method" = long.method,
          "alpha" = alpha,
          "cluster.sizes" = cluster.sizes,
          "n.clusters" = nclusters,
          "variance.parms" = var.parms,
          "probs" = probs,
          "model.estimates" = ma.model.est,
          "convergence" = binary.ma.rct[[3]],
          "sim.data" = binary.ma.rct[["sim.data"]],
          "all.models" <-  binary.ma.rct
        ),
        class = 'crtpwr.ma'
      )
    }
    if (return.all.models == FALSE && allSimData == FALSE) {
      complete.output = structure(
        list(
          "overview" = summary.message,
          "nsim" = nsim,
          "power" =
            prop_H0_rejection(
              alpha = alpha,
              nsim = nsim,
              sig.LRT = sig.LRT
            ),
          "beta" = power.parms['Beta'],
          "overall.power2" = power.parms,
          "overall.power" = LRT.holder,
          "method" = long.method,
          "alpha" = alpha,
          "cluster.sizes" = cluster.sizes,
          "n.clusters" = nclusters,
          "variance.parms" = var.parms,
          "probs" = probs,
          "model.estimates" = ma.model.est,
          "convergence" = binary.ma.rct[[3]]
        ),
        class = 'crtpwr.ma'
      )
    }
  } # end of GLMM options
  
  #Organize output for GEE method
  if (method == "gee") {
    # Organize the output
    Estimates = matrix(NA, nrow = nsim, ncol = narms)
    std.error = matrix(NA, nrow = nsim, ncol = narms)
    Wald = matrix(NA, nrow = nsim, ncol = narms)
    Pr = matrix(NA, nrow = nsim, ncol = narms)
    
    for (i in 1:nsim) {
      Estimates[i,] <- models[[i]]$coefficients[, 1]
      std.error[i,] <- models[[i]]$coefficients[, 2]
      Wald[i,] <- models[[i]]$coefficients[, 3]
      Pr[i,] <- models[[i]]$coefficients[, 4]
    }
    
    # Organize the row/col names for the output
    keep.names <- rownames(models[[1]]$coefficients)
    
    names.Est <- rep(NA, length(narms))
    names.st.err <- rep(NA, length(narms))
    names.wald <- rep(NA, length(narms))
    names.pval <- rep(NA, length(narms))
    names.power <- rep(NA, length(narms))
    
    for (i in 1:length(keep.names)) {
      names.Est[i] <- paste(keep.names[i], ".Estimate", sep = "")
      names.st.err[i] <- paste(keep.names[i], ".Std.Err", sep = "")
      names.wald[i] <- paste(keep.names[i], ".wald", sep = "")
      names.pval[i] <- paste(keep.names[i], ".pval", sep = "")
      names.power[i] <- paste(keep.names[i], ".power", sep = "")
    }
    colnames(Estimates) <- names.Est
    colnames(std.error) <- names.st.err
    colnames(Wald) <- names.wald
    colnames(Pr) <- names.pval
    
    # Organize the LRT output
    LRT.holder <-
      matrix(
        unlist(binary.ma.rct[[2]]),
        ncol = 3,
        nrow = nsim,
        byrow = TRUE,
        dimnames = list(seq(1:nsim),
                        c("Df", "X2", "P(>|Chi|)"))
      )
    
    # Proportion of times P(>F)
    converge <- binary.ma.rct[["converged"]]
    LRT.holder <- cbind(LRT.holder, converge)
    LRT.holder <- LRT.holder[LRT.holder[, "converge"] == TRUE, ]
    sig.LRT <-  ifelse(LRT.holder[, 3] < alpha, 1, 0)
    
    # Calculate and store power estimate & confidence intervals
    sig.val <-  ifelse(Pr < alpha, 1, 0)
    pval.power <-
      apply(
        sig.val,
        2,
        FUN = function(x) {
          sum(x, na.rm = TRUE) / nsim
        }
      )
    power.parms <- cbind(confintCalc(
      multi = TRUE,
      alpha = alpha,
      p.val = Pr[, 2:narms]
    ),
    multi_p_method)
    
    # Store GEE simulation output in data frame
    ma.model.est <-  data.frame(Estimates, std.error, Wald, Pr)
    ma.model.est <-
      ma.model.est[, -grep('.*ntercept.*', names(ma.model.est))]
    
    # performance messages
    total.est <-
      as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
    hr.est <-  total.est %/% 3600
    min.est <-  total.est %/% 60
    sec.est <-  round(total.est %% 60, 0)
    message(
      paste0(
        "Simulations Complete! Time Completed: ",
        Sys.time(),
        "\nTotal Runtime: ",
        hr.est,
        'Hr:',
        min.est,
        'Min:',
        sec.est,
        'Sec'
      )
    )
    
    # Create list containing all output (class 'crtpwr.ma') and return
    if (allSimData == TRUE & return.all.models == FALSE) {
      complete.output = structure(
        list(
          "overview" = summary.message,
          "nsim" = nsim,
          "power" =
            prop_H0_rejection(
              alpha = alpha,
              nsim = nsim,
              sig.LRT = sig.LRT
            ),
          "beta" = power.parms['Beta'],
          "overall.power2" = power.parms,
          "overall.power" = LRT.holder,
          "method" = long.method,
          "alpha" = alpha,
          "cluster.sizes" = cluster.sizes,
          "n.clusters" = nclusters,
          "variance.parms" = var.parms,
          "probs" = probs,
          "model.estimates" = ma.model.est,
          "sim.data" = binary.ma.rct[["sim.data"]]
        ),
        class = 'crtpwr.ma'
      )
    }
    if (return.all.models == TRUE) {
      complete.output = structure(
        list(
          "overview" = summary.message,
          "nsim" = nsim,
          "power" =
            prop_H0_rejection(
              alpha = alpha,
              nsim = nsim,
              sig.LRT = sig.LRT
            ),
          "beta" = power.parms['Beta'],
          "overall.power2" = power.parms,
          "overall.power" = LRT.holder,
          "method" = long.method,
          "alpha" = alpha,
          "cluster.sizes" = cluster.sizes,
          "n.clusters" = nclusters,
          "variance.parms" = var.parms,
          "probs" = probs,
          "model.estimates" = ma.model.est,
          "all.models" <-  binary.ma.rct
        ),
        class = 'crtpwr.ma'
      )
    }
    if (return.all.models == FALSE && allSimData == FALSE) {
      complete.output = structure(
        list(
          "overview" = summary.message,
          "nsim" = nsim,
          "power" =
            prop_H0_rejection(
              alpha = alpha,
              nsim = nsim,
              sig.LRT = sig.LRT
            ),
          "beta" = power.parms['Beta'],
          "overall.power2" = power.parms,
          "overall.power" = LRT.holder,
          "method" = long.method,
          "alpha" = alpha,
          "cluster.sizes" = cluster.sizes,
          "n.clusters" = nclusters,
          "variance.parms" = var.parms,
          "probs" = probs,
          "model.estimates" = ma.model.est
        ),
        class = 'crtpwr.ma'
      )
    }
  }# end of GEE options
  return(complete.output)
}# end of fxn
