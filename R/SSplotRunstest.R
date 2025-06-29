#' Runs Test for Residuals
#'
#' This function uses randtests::runs.test to do perform a runs test on
#' residuals to determine if they are randomly distributed. It also calculates
#' the 3 x sigma limits
#'

#' runs test is conducted with `library(randtests)`
#'
#' @param x residuals from CPUE fits
#' @param type only `c("resid","observations")`
#' @param mixing `c("less","greater","two.sided")`. Default less is checking
#' for positive autocorrelation only
#'
#' @return runs p value and 3 x sigma limits
#'
#' @keywords diags runsTest
#'

#' @export
#'
#' @author Henning Winker (JRC-EC) and Laurence Kell (Sea++)
ssruns_sig3 <- function(x, type = NULL, mixing = "less") {
  if (is.null(type)) type <- "resid"
  if (type == "resid") {
    mu <- 0
  } else {
    mu <- mean(x, na.rm = TRUE)
  }
  alternative <- c("two.sided", "left.sided")[which(c("two.sided", "less") %in% mixing)]
  # Average moving range
  mr <- abs(diff(x - mu))
  amr <- mean(mr, na.rm = TRUE)
  # Upper limit for moving ranges
  ulmr <- 3.267 * amr
  # Remove moving ranges greater than ulmr and recalculate amr, Nelson 1982
  mr <- mr[mr < ulmr]
  amr <- mean(mr, na.rm = TRUE)
  # Calculate standard deviation, Montgomery, 6.33
  stdev <- amr / 1.128
  # Calculate control limits
  lcl <- mu - 3 * stdev
  ucl <- mu + 3 * stdev
  if (nlevels(factor(sign(x))) > 1) {
    # Make the runs test non-parametric
    runstest <- randtests::runs.test(x, threshold = 0, alternative = alternative)
    if (is.na(runstest[["p.value"]])) p.value <- 0.001
    pvalue <- round(runstest[["p.value"]], 3)
  } else {
    pvalue <- 0.001
  }

  return(list(sig3lim = c(lcl, ucl), p.runs = pvalue))
}


#' Residual Diagnostics
#'
#' Function for residual diagnostics. Plots residuals and 3x sigma limits for
#' indices or mean age or length and outputs a runs test table. Note, if you do
#' not want to plot the residuals, use [ss3diags::SSrunstest()].
#'
#' @param ss3rep Stock Synthesis output as read by [r4ss::SS_output()]
#' @param mixing `c("less","greater","two.sided")`. Default less is checking
#' for positive autocorrelation only
#' @param subplots optional flag for:
#' \itemize{
#'  \item `"cpue"` Index of abundance data
#'  \item `"len"` Length composition data
#'  \item `"size"` Generalized size composition data
#'  \item `"age"` Age composition data
#'  \item `"con"` Conditional age-at-length data
#' }
#' @param indexselect Vector of fleet numbers for each model for which to
#' compare
#' @param miny the absolute value of the min and max value for `ylim`.
#' Default is 1
#' @param legend  Flag to enable legend to plot. TRUE by default.
#' @param legendloc Location of legend. Either a string like "topleft" or a
#' vector of two numeric values representing the fraction of the maximum in
#' the x and y dimensions, respectively. See `help("legend")` for more info
#' on the string options.
#' @param legendcex Allows to adjust legend cex
#' @param ylim Optional, values for y-axis range to display on plot.
#' The default: `"default"`, will range from -1 to 1.
#'
#' @inheritParams SSplotGeneric
#' @inheritParams SSplotGenericPar
#'
#' @return a dataframe with runs test p-value, if the test has passed or failed,
#' 3x sigma high and low limits, and the type of data used. Rows are for each
#' fleet. Note, runs test passed if p-value > 0.05 (residuals are random) and
#' failed if p-value < 0.5 (residuals are not random)
#'
#' @author Henning Winker (JRC-EC) and Laurance Kell (Sea++)
#'
#' @keywords ssplot runsTest
#'
#' @importFrom lifecycle deprecated
#'
#' @export
#'

SSplotRunstest <- function(ss3rep,
                           mixing = "less",
                           subplots = c("cpue", "len", "age", "size", "con")[1],
                           plot = TRUE,
                           print = deprecated(),
                           print_plot = FALSE,
                           png = deprecated(),
                           use_png = print_plot,
                           pdf = deprecated(),
                           use_pdf = FALSE,
                           indexselect = NULL,
                           miny = 0.5,
                           col = NULL,
                           pch = 21,
                           lty = 1,
                           lwd = 2,
                           tickEndYr = FALSE,
                           xlim = "default",
                           ylim = "default",
                           ylimAdj = 1.2,
                           xaxs = "i",
                           yaxs = "i",
                           xylabs = TRUE,
                           type = "o",
                           legend = TRUE,
                           legendloc = "top",
                           legendcex = 1,
                           pwidth = 7,
                           pheight = 5.0,
                           punits = "in",
                           res = 300,
                           ptsize = 12,
                           cex.main = 1,
                           plotdir = NULL,
                           filenameprefix = "",
                           par = list(mar = c(5, 4, 1, 1) + .1, family = "sans"),
                           verbose = TRUE,
                           new = TRUE,
                           add = TRUE) {
  # Parameter DEPRECATION checks
  if (lifecycle::is_present(print)) {
    lifecycle::deprecate_warn("2.0.0", "SSplotRunstest(print)", "SSplotRunstest(print_plot)")
    print_plot <- print
  }

  if (lifecycle::is_present(png)) {
    lifecycle::deprecate_warn("2.0.0", "SSplotRunstest(png)", "SSplotRunstest(use_png)")
    use_png <- png
  }

  if (lifecycle::is_present(pdf)) {
    lifecycle::deprecate_warn("2.0.0", "SSplotRunstest(pdf)", "SSplotRunstest(use_pdf)")
    use_pdf <- pdf
  }

  if (!isTRUE(plot)) {
    lifecycle::deprecate_warn(
      when = "2.0.0",
      what = "SSplotRunsTest(plot)",
      details = "The ability to explictly disable plot windows or plot subplots is unused and will be defunct in a future version"
    )
  }

  if (!isTRUE(new)) {
    lifecycle::deprecate_warn(
      when = "2.0.0",
      what = "SSplotRunsTest(new)",
      details = "The ability to explicitly disable new plot windows is unused and will be removed in a future version"
    )
  }


  #-------------------------------------------
  # r4ss plotting functions and coding style
  #-------------------------------------------
  # subfunction to write png files
  if (!add) graphics.off()
  if (add) {
    print_plot <- F
    use_png <- F
  }

  subplots <- subplots[1]
  datatypes <- c("Index", "Mean length", "Mean age", "Conditional age-at-length")
  ylabel <- datatypes[which(c("cpue", "len", "age", "con") %in% subplots)]
  if (verbose) message("Running Runs Test Diagnostics w/ plots for", datatypes[which(c("cpue", "len", "age", "con") %in% subplots)])
  if (subplots == "cpue") {
    cpue <- ss3rep[["cpue"]]
    cpue[["residuals"]] <- ifelse(is.na(cpue[["Obs"]]) | is.na(cpue[["Like"]]), NA, log(cpue[["Obs"]]) - log(cpue[["Exp"]]))

    if (is.null(cpue[["Fleet_name"]])) { # Deal with Version control
      cpue[["Fleet_name"]] <- cpue[["Name"]]
    }
    Res <- cpue
  }

  if (subplots == "len" | subplots == "age" | subplots == "size") {
    comps <- SScompsTA1.8(ss3rep, fleet = NULL, type = subplots, plotit = FALSE)[["runs_dat"]]
    comps[["residuals"]] <- ifelse(is.na(comps[["Obs"]]), NA, log(comps[["Obs"]]) - log(comps[["Exp"]]))
    if (is.null(comps[["Fleet_name"]])) { # Deal with Version control
      comps[["Fleet_name"]] <- comps[["Name"]]
    }
    Res <- comps
  }

  if (subplots == "con") {
    cond <- SScompsTA1.8(ss3rep, fleet = NULL, type = subplots, plotit = FALSE)[["runs_dat"]]
    cond[["residuals"]] <- ifelse(is.na(cond[["Obs"]]), NA, log(cond[["Obs"]]) - log(cond[["Exp"]]))
    if (is.null(cond[["Fleet_name"]])) { # Deal with Version control
      cond[["Fleet_name"]] <- cond[["Name"]]
    }
    Res <- cond
  }

  # save_png <- function(file) {
  #   # if extra text requested, add it before extention in file name
  #   file <- paste0(filenameprefix, file)
  #   # open png file
  #   png(
  #     filename = file.path(plotdir, file),
  #     width = pwidth, height = pheight, units = punits, res = res, pointsize = ptsize
  #   )
  #   # change graphics parameters to input value
  #   par(par)
  # }

  # subset if indexselect is specified
  if (is.null(indexselect) == F & is.numeric(indexselect)) {
    iname <- unique(Res[["Fleet_name"]])[indexselect]
    if (TRUE %in% is.na(iname)) stop("One or more index numbers exceed number of available indices")
    Res <- Res[Res[["Fleet_name"]] %in% iname, ]
  }

  # Define indices
  indices <- unique(Res[["Fleet_name"]])
  n.indices <- length(indices)
  series <- 1:n.indices



  if (use_png) print_plot <- TRUE
  if (use_png & is.null(plotdir)) {
    stop("to print PNG files, you must supply a directory as 'plotdir'")
  }

  # check for internal consistency
  if (use_pdf & use_png) {
    stop("To use 'use_pdf', set 'print_plot' or 'use_png' to FALSE.")
  }
  if (use_pdf) {
    if (is.null(plotdir)) {
      stop("to write to a PDF, you must supply a directory as 'plotdir'")
    }
    pdffile <- file.path(
      plotdir,
      paste0(
        filenameprefix, "SSplotComparisons_",
        format(Sys.time(), "%d-%b-%Y_%H.%M"), ".pdf"
      )
    )
    pdf(file = pdffile, width = pwidth, height = pheight)
    if (verbose) message("PDF file with plots will be:", pdffile, "\n")
    par(par)
  }

  #---------------------------------------
  plot_runs <- function(resid) {
    labels <- c(
      "Year", # 1
      "Residuals", # 2
      "Log index"
    ) # 3



    # open new window if requested
    if (plot & use_png == FALSE) {
      if (!add) dev.new(width = pwidth, height = pheight, pointsize = ptsize, record = TRUE)
    } else {
      if (!add) par(par)
    }


    # get quantities for plot
    yr <- resid[["Yr"]]
    ti <- resid[["Time"]]
    ylab <- paste(ylabel, "residuals")

    ### make plot of index fits

    # Do runs test
    runstest <- ssruns_sig3(x = as.numeric(resid[["residuals"]]), type = "resid", mixing = mixing)

    # if no values included in subset, then set ylim based on all values
    if (ylim[1] == "default") {
      ylim <- c(min(-miny, runstest[["sig3lim"]][1] * ylimAdj), max(miny, runstest[["sig3lim"]][2] * ylimAdj))
    } else {
      ylim <- ylim * ylimAdj
    }


    if (xlim[1] == "default") xlim <- c(floor(min(ti, yr) - .1), ceiling(max(ti, yr) + 0.1))

    plot(0,
      type = "n", xlim = xlim, yaxs = yaxs,
      ylim = ylim, xlab = ifelse(xylabs, "Year", ""), ylab = ifelse(xylabs, ylab, ""), axes = FALSE
    )

    lims <- runstest[["sig3lim"]]
    cols <- c("#E15759", "#59A14F")[ifelse(runstest[["p.runs"]] < 0.05, 1, 2)]
    point_cols <- ifelse(resid[["residuals"]] < lims[1] | resid[["residuals"]] > lims[2], "#f01e2c", "#ffffff")
    n_point_cols <- length(unique(point_cols))
    if (n_point_cols == 2) {
      point_labels <- c("Extreme Residual", "Residual")
    } else {
      point_labels <- "Residual"
    }

    rect(min(resid[["Yr"]] - 1), lims[1], max(resid[["Yr"]] + 1), lims[2], col = cols, border = cols) # only show runs if RMSE >= 0.1

    abline(h = 0, lty = 2)
    for (j in 1:length(resid[["Yr"]])) {
      lines(c(resid[["Time"]][j], resid[["Time"]][j]), c(0, resid[["residuals"]][j]))
    }
    points(resid[["Time"]], resid[["residuals"]], pch = pch, bg = point_cols, cex = 1)
    if (legend) {
      legend(legendloc, paste(resid[["Fleet_name"]][1]), bty = "n", y.intersp = -0.2, cex = legendcex + 0.1)
      legend("topright", legend = c(point_labels, "sigma3 limit"), pch = c(rep(21, n_point_cols), 22), pt.bg = c(unique(point_cols), cols))
    }

    axis(1, at = resid[["Yr"]])
    if (tickEndYr) axis(1, at = max(resid[["Yr"]]))

    axis(2)
    box()

    return(runstest)
  } # End of plot_runs function
  #------------------------------------------------------------


  if (verbose) message("Plotting Residual Runs Tests")
  if (plot) {
    # LOOP through fleets
    nfleets <- n.indices

    if (print_plot) {
      runs <- NULL
      for (fi in 1:nfleets) {
        resid <- Res[Res[["Fleet_name"]] == indices[fi], ]
        # save_png(paste0("residruns_", indices[fi], ".png", sep = ""))
        plotinfo <- NULL
        r4ss::save_png(
          plotinfo = plotinfo,
          file = paste0("residruns_", indices[fi], ".png", sep = ""),
          plotdir = plotdir,
          pwidth = pwidth,
          pheight = pheight,
          punits = punits,
          res = res,
          ptsize = ptsize,
          filenameprefix = filenameprefix
        )
        par(par)
        if (nrow(resid) > 3 & (max(resid[["Time"]]) - min(resid[["Time"]])) > 3) {
          get_runs <- plot_runs(resid)
          dev.off()
          runs <- rbind(runs, c(get_runs[["p.runs"]], get_runs[["sig3lim"]]))
        } else {
          runs <- rbind(runs, c(NA, NA, NA))
        }
      } # End of Fleet Loop
    }


    runs <- NULL
    for (fi in 1:nfleets) {
      resid <- Res[Res[["Fleet_name"]] == indices[fi], ]
      if (nrow(resid) > 3 & (max(resid[["Time"]]) - min(resid[["Time"]])) > 3) {
        if (!add) (par)
        get_runs <- plot_runs(resid)
        runs <- rbind(runs, c(get_runs[["p.runs"]], get_runs[["sig3lim"]]))
        # End of Fleet Loop
      } else {
        runs <- rbind(runs, c(NA, NA, NA))
      }
    }
  }

  runstable <- data.frame(Index = indices, runs.p = as.matrix(runs)[, 1], Test = ifelse(is.na(as.matrix(runs)[, 1]), "Excluded", ifelse(as.matrix(runs)[, 1] < 0.05, "Failed", "Passed")), sigma3.lo = as.matrix(runs)[, 2], sigma3.hi = as.matrix(runs)[, 3], type = subplots)
  colnames(runstable) <- c("Index", "runs.p", "test", "sigma3.lo", "sigma3.hi", "type")
  if (verbose) cat(paste0("Residual Runs Test (/w plot) stats by ", datatypes[which(c("cpue", "len", "age", "con") %in% subplots)], ":", "\n"))
  return(runstable)
} # end of SSplotRuns()
#-----------------------------------------------------------------------------------------
#' Residual Diagnostics Plot
#'
#' Function for residual diagnostics. Outputs a runs test table that gives runs
#' test p-values, if the runs test passed (p-value > 0.05, residuals are random)
#' or failed (p-value < 0.05, residuals are not random), the 3x sigma limits for
#' indices or mean age or length and the type of input data (cpue, length comp,
#' age comp, size comp, or conditional age-at-length).
#'
#' @param ss3rep Stock Synthesis output as read by [r4ss::SS_output()]
#' @param mixing `c("less","greater","two.sided")`. Default less is checking for
#' positive autocorrelation only
#' @param quants optional use of `c("cpue","len","age","con")`, default uses
#' `"cpue"`.
#' \itemize{
#'  \item `"cpue"` Index of abundance data
#'  \item `"len"` Length composition data
#'  \item `"age"` Age composition data
#'  \item `"con"` Conditional age-at-length data
#' }
#' @param indexselect Vector of fleet numbers for each model for which to
#' compare
#' @param verbose Report progress to R GUI?
#'
#' @return a dataframe with runs test p-value, if the test has passed or failed,
#' 3x sigma high and low limits, and the type of data used. Rows are for each
#' fleet. Note, runs test passed if p-value > 0.05 (residuals are random) and
#' failed if p-value < 0.5 (residuals are not random)
#'
#' @author Henning Winker (JRC-EC) and Laurance Kell (Sea++)
#'
#' @keywords diags runsTest
#'
#' @export

SSrunstest <- function(ss3rep,
                       mixing = "less",
                       quants = c("cpue", "len", "age", "con")[1],
                       indexselect = NULL,
                       verbose = TRUE) {
  datatypes <- c("Index", "Mean length", "Mean age", "Conditional age-at-length")
  subplots <- quants
  ylabel <- datatypes[which(c("cpue", "len", "age", "con") %in% subplots)]
  if (verbose) cat("Running Runs Test Diagnosics for", datatypes[which(c("cpue", "len", "age", "con") %in% subplots)], "\n")
  if (subplots == "cpue") {
    cpue <- ss3rep[["cpue"]]
    cpue[["residuals"]] <- ifelse(is.na(cpue[["Obs"]]) | is.na(cpue[["Like"]]), NA, log(cpue[["Obs"]]) - log(cpue[["Exp"]]))

    if (is.null(cpue[["Fleet_name"]])) { # Deal with Version control
      cpue[["Fleet_name"]] <- cpue[["Name"]]
    }
    Res <- cpue
  }

  if (subplots == "len" | subplots == "age") {
    comps <- SScompsTA1.8(ss3rep, fleet = NULL, type = subplots, plotit = FALSE)[["runs_dat"]]
    comps[["residuals"]] <- ifelse(is.na(comps[["Obs"]]), NA, log(comps[["Obs"]]) - log(comps[["Exp"]]))
    if (is.null(comps[["Fleet_name"]])) { # Deal with Version control
      comps[["Fleet_name"]] <- comps[["Name"]]
    }
    Res <- comps
  }

  if (subplots == "con") {
    cond <- SScompsTA1.8(ss3rep, fleet = NULL, type = subplots, plotit = FALSE)[["runs_dat"]]
    cond[["residuals"]] <- ifelse(is.na(cond[["Obs"]]), NA, log(cond[["Obs"]]) - log(cond[["Exp"]]))
    if (is.null(cond[["Fleet_name"]])) { # Deal with Version control
      cond[["Fleet_name"]] <- cond[["Name"]]
    }
    Res <- cond
  }
  # subset if indexselect is specified
  if (is.null(indexselect) == F & is.numeric(indexselect)) {
    iname <- unique(Res[["Fleet_name"]])[indexselect]
    if (TRUE %in% is.na(iname)) stop("One or more index numbers exceed number of available indices")
    Res <- Res[Res[["Fleet_name"]] %in% iname, ]
  }

  # Define indices
  indices <- unique(Res[["Fleet_name"]])
  n.indices <- length(indices)
  series <- 1:n.indices




  #---------------------------------------
  doruns <- function(resid) {
    # get quantities for plot
    yr <- resid[["Yr"]]
    ti <- resid[["Time"]]
    ylab <- paste(ylabel, "residuals")

    ### make plot of index fits

    # Do runs test
    runstest <- ssruns_sig3(x = as.numeric(resid[["residuals"]]), type = "resid", mixing = mixing)

    # if no values included in subset, then set ylim based on all values
    lims <- runstest[["sig3lim"]]

    return(runstest)
  } # End of runs function
  #------------------------------------------------------------


  if (verbose) message("Computing Residual Runs Tests")
  # LOOP through fleets
  nfleets <- n.indices
  runs <- NULL
  for (fi in 1:nfleets) {
    resid <- Res[Res[["Fleet_name"]] == indices[fi], ]
    if (nrow(resid) > 3 & (max(resid[["Time"]]) - min(resid[["Time"]])) > 3) {
      get_runs <- doruns(resid)
      runs <- rbind(runs, c(get_runs[["p.runs"]], get_runs[["sig3lim"]]))
      # End of Fleet Loop
    } else {
      runs <- rbind(runs, c(NA, NA, NA))
    }
  }

  runstable <- data.frame(Index = indices, runs.p = as.matrix(runs)[, 1], Test = ifelse(is.na(as.matrix(runs)[, 1]), "Excluded", ifelse(as.matrix(runs)[, 1] < 0.05, "Failed", "Passed")), sigma3.lo = as.matrix(runs)[, 2], sigma3.hi = as.matrix(runs)[, 3], type = subplots)
  colnames(runstable) <- c("Index", "runs.p", "test", "sigma3.lo", "sigma3.hi", "type")
  if (verbose) cat(paste0("Residual Runs Test stats by ", datatypes[which(c("cpue", "len", "age", "con") %in% subplots)], ":", "\n"))
  return(runstable)
} # end of SSplotRuns()
#-----------------------------------------------------------------------------------------
