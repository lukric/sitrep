#' MSF data dictionaries and dummy datasets
#'
#' These function reads in MSF data dictionaries and produces randomised
#' datasets based on values defined in the dictionaries.  The randomised
#' dataset produced should mimic an excel export from DHIS2.  A third function
#' (switch_vals) is used to recode variables defined in the dictionaries from
#' coded to named form (e.g. 0/1 to No/Yes).
#'
#' @param disease Specify which disease you would like to use.
#' Currently supports "Cholera", "Measles" and "Meningitis".
#' @param dictionary Specify which dictionary you would like to use.
#' Currently supports "Cholera", "Measles", "Meningitis" and "Mortality".
#' @param varnames Specify name of column that contains varnames. Currently
#' default set to "Item".  (this can probably be deleted once dictionaries
#' standardise) If `dictionary` is "Mortality", `varnames` needs to be "column_name"`.
#' @param numcases For fake data, specify the number of cases you want (default is 300
#' @param tibble Return data dictionary as a tidyverse tibble (default is TRUE)
#' @param compact If TRUE, returns a neat data dictionary in single data frame.
#' If FALSE, returns a list with two data frames, one with variables and the
#' other with content options.
#' @param df A dataframe (e.g. your linelist) which is passed to switch_vals function.
#' @param copy_to_clipboard. if `TRUE` (default), the rename template will be
#' copied to the user's clipboard with [clipr::write_clip()]. If `FALSE`, the
#' rename template will be printed to the user's console.
#' @importFrom rio import
#' @importFrom epitrix clean_labels
#' @importFrom tibble as_tibble
#' @export


# function to pull outbreak data dicationaries together
msf_dict <- function(disease, name = "MSF-outbreak-dict.xlsx", tibble = TRUE,
                     compact = TRUE) {

  # get excel file path (need to specify the file name)
  path <- system.file("extdata", name, package = "sitrep")

  # read in categorical variable content options
  dat_opts <- rio::import(path, which = "OptionCodes")

  # read in data set - pasting the disease name for sheet
  dat_dict <- rio::import(path, which = disease)

  # clean col names
  colnames(dat_dict) <- epitrix::clean_labels(colnames(dat_dict))
  colnames(dat_opts) <- epitrix::clean_labels(colnames(dat_opts))

  # clean future var names
  # excel names (data element shortname)
  # csv names (data_element_name)
  dat_dict$data_element_shortname <- epitrix::clean_labels(dat_dict$data_element_shortname)
  dat_dict$data_element_name      <- epitrix::clean_labels(dat_dict$data_element_name)

  # Adding hardcoded var types to options list
  # 3 types added to - BOOLEAN, TRUE_ONLY and ORGANISATION-UNIT
  BOOLEAN           <- data.frame(option_code = c(1, 0),
                         option_name = c("[1] Yes", "[0] No"),
                         option_uid = c(NA, NA),
                         option_order_in_set = c(1,2),
                         optionset_uid = c("BOOLEAN", "BOOLEAN")
                         )

  TRUE_ONLY         <- data.frame(option_code = c(1, "NA"),
                          option_name = c("[1] TRUE", "[NA] Not TRUE"),
                          option_uid = c(NA, NA),
                          option_order_in_set = c(1,2),
                          optionset_uid = c("TRUE_ONLY", "TRUE_ONLY")
                          )
  ORGANISATION_UNIT <- data.frame(option_code = c("HO", "CL", "HP"),
                          option_name = c("[HO] Hospital", "[CL] Clinic", "[HP] Health post"),
                          option_uid = c(NA, NA, NA),
                          option_order_in_set = c(1,2,3),
                          optionset_uid = c("ORGANISATION_UNIT", "ORGANISATION_UNIT", "ORGANISATION_UNIT")
                          )

  # bind these on to the bottom of dat_opts (option list) as rows
  dat_opts <- do.call("rbind", list(dat_opts, BOOLEAN, TRUE_ONLY, ORGANISATION_UNIT))



  # add the unique identifier to link above three in dictionary to options list
  for (i in c("BOOLEAN", "TRUE_ONLY", "ORGANISATION_UNIT")) {
    dat_dict$used_optionset_uid[dat_dict$data_element_valuetype == i] <- i
  }

  # remove back end codes from frent end var in the options list
  dat_opts$option_name <- gsub(".*] ", "", dat_opts$option_name)

  # produce clean compact data dictionary for use in gen_data
  if (compact == TRUE) {
    # change dat_opts to wide format
    # remove the optionset_UID for treatment_facility_site
    # (is just numbers 1:50 and dont want it in the data dictionary)
    a <- aggregate(option_code ~ optionset_uid,
                   dat_opts[dat_opts$optionset_uid != "MilOli6bHV0",], I) # spread wide based on UID
    obs <- sapply(a$option_code, length) # count length of var opts for each
    highest <- seq_len(max(obs)) # create sequence for pulling out of list
    out <- t(sapply(a$option_code, "[", i = highest)) # pull out of list and flip to make dataframe
    colnames(out) <- sprintf("Code%d", seq(ncol(out))) # rename with code and num of columns

    # bind to above
    a$option_code <- NULL
    a <- cbind(a, out)

    # repeat above for names
    b <- aggregate(option_name ~ optionset_uid,
                   dat_opts[dat_opts$optionset_uid != "MilOli6bHV0",], I) # spread wide based on UID
    obs <- sapply(b$option_name, length) # count length of var opts for each
    highest <- seq_len(max(obs)) # create sequence for pulling out of list
    out <- t(sapply(b$option_name, "[", i = highest)) # pull out of list and flip to make dataframe
    colnames(out) <- sprintf("Name%d", seq(ncol(out))) # rename with code and num of column

    b$option_name <- NULL
    b$optionset_uid <- NULL
    b <- cbind(b, out)

    # bind code and name together
    combiner <- cbind(a, b)

    # merge with data dicationry
    outtie <- merge(dat_dict, combiner,
                    by.x = "used_optionset_uid", by.y = "optionset_uid",
                    all.x = TRUE)

    # return a tibble
    if (tibble == TRUE) {
      outtie <- tibble::as_tibble(outtie)
    }

  }

  # Return second option of list with data dictionary and category options seperate
  if (compact == FALSE) {

    if (tibble == TRUE) {
      outtie <- list(dictionary = tibble::as_tibble(dat_dict),
                     options = tibble::as_tibble(dat_opts)
                     )
    }

    if (tibble == FALSE) {
      outtie <- list(dictionary = dat_dict,
                     options = dat_opts)
    }

  }

  # return dictionary dataset
  outtie
}

#' @export
#' @rdname msf_dict
msf_dict_rename_helper <- function(disease, varnames = "data_element_shortname", copy_to_clipboard = TRUE) {
  # get msf disease specific data dictionary
  dat_dict <- msf_dict(disease = disease, tibble = FALSE, compact = TRUE)
  msg <- "## Add the appropriate column names after the equals signs\n\n"
  msg <- paste0(msg, "linelist_cleaned <- rename(linelist_cleaned,\n")
  the_renames <- sprintf("  %s =   , # %s",
                         format(dat_dict[[varnames]]),
                         dat_dict[["data_element_valuetype"]])
  the_renames[length(the_renames)] <- gsub(",", " ", the_renames[length(the_renames)])
  msg <- paste0(msg, paste(the_renames, collapse = "\n"), "\n)\n")
  if (copy_to_clipboard) {
    x <- try(clipr::write_clip(msg), silent = TRUE)
    if (inherits(x, "try-error")) {
      if (interactive()) cat(msg)
      return(invisible())
    }
    message("rename template copied to clipboard. Paste the contents to your RMarkdown file and enter in the column names from your data set.")
  } else {
    cat(msg)
  }
}


# function to generate fake dataset based on data dictionary
#' @export
#' @rdname msf_dict
gen_data <- function(dictionary, varnames = "data_element_shortname", numcases = 300) {

  # Three datasets:
  # 1) dat_dict = msf data dicationary generated by (msf_dict)
  # 2) dat_output = formatting of data dictionary to make use for sampling
  # 3) dis_output = dictionary dataset generated from sampling (exported)

  # get msf dictionary specific data dictionary
  if (dictionary == "Mortality") {
    dat_dict <- msf_dict_mortality(tibble = FALSE)
  } else if (dictionary %in% c("Cholera", "Measles", "Meningitis")) {
    dat_dict <- msf_dict(disease = dictionary, tibble = FALSE, compact = TRUE)
  } else {
    stop("'dictionary' must be one of: 'Cholera', 'Measles', 'Meningitis', 'Mortality'")
  }


  # drop extra columns (keep varnames and code options)
  varcol <- which(names(dat_dict) == varnames)
  codecol <- grep("Code", names(dat_dict))
  dat_output <- dat_dict[, c(varcol, codecol), drop = FALSE]

  # use the var names as rows
  row.names(dat_output) <- dat_output[[varnames]]
  # remove the var names column
  dat_output <- dat_output[-1]
  # flip the dataset
  dat_output <- data.frame(t(dat_output))
  # remove rownames
  row.names(dat_output) <- NULL

  # define variables that do not have any contents in the data dictionary

  # create a NEW empty dataframe with the names from the data dictionary
  dis_output <- data.frame(matrix(ncol = ncol(dat_output), nrow = numcases) )
  colnames(dis_output) <- colnames(dat_output)

  # take samples for vars with defined options (non empties)
  categories <- lapply(dat_output, function(i) i[!is.na(i)])
  categories <- categories[lengths(categories) > 0]
  for (i in names(categories)) {
    dis_output[[i]] <- sample(categories[[i]], numcases, replace = TRUE)
  }


  # Use data dictionary to define which vars are dates
  datevars <- dat_dict[dat_dict$data_element_valuetype == "DATE", varnames]

  # sample between two dates
  posidates <- seq(as.Date("2018-01-01"), as.Date("2018-04-30"), by = "day")

  # fill the date columns with dates
  for (i in datevars) {
    dis_output[[i]] <- sample(posidates, numcases, replace = TRUE)
  }

  if (dictionary != "Mortality") {
    # Fix DATES
    # exit dates before date of entry
    # just add 20 to admission.... (was easiest...)
    dis_output$date_of_exit[dis_output$date_of_exit <=
                              dis_output$date_of_consultation_admission] <-
      dis_output$date_of_consultation_admission[dis_output$date_of_exit <=
                                                  dis_output$date_of_consultation_admission] + 20
    # lab sample dates before admission
    # add 2 to admission....
    dis_output$date_lab_sample_taken[dis_output$date_lab_sample_taken <=
                                       dis_output$date_of_consultation_admission] <-
      dis_output$date_of_consultation_admission[dis_output$date_of_exit <=
                                                  dis_output$date_of_consultation_admission] + 2

    # vaccination dates after admission
    # minus 20 to admission...
    dis_output$date_of_last_vaccination[dis_output$date_of_exit >
                                          dis_output$date_of_consultation_admission] <-
      dis_output$date_of_consultation_admission[dis_output$date_of_exit >
                                                  dis_output$date_of_consultation_admission] - 20
    # symptom onset after admission
    # minus 20 to admission...
    dis_output$date_of_onset[dis_output$date_of_onset >
                               dis_output$date_of_consultation_admission] <-
      dis_output$date_of_consultation_admission[dis_output$date_of_onset >
                                                  dis_output$date_of_consultation_admission] - 20


    # Patient identifiers
    dis_output$case_number <- sprintf("A%d", seq(numcases))

    # treatment site facility
    dis_output$treatment_facility_site <- sample(1:50,
                                                 numcases, replace = TRUE)

    # patient origin
    dis_output$patient_origin_free_text <- sample(c("Village A", "Village B", "Village C", "Village D"),
                                                  numcases, replace = TRUE)
  }

  # sample age_month and age_days if appropriate
  age_year_var <- grep("age.*year", names(dis_output), value = TRUE)[1]
  age_month_var <- grep("age.*month", names(dis_output), value = TRUE)[1]
  age_day_var <- grep("age.*day", names(dis_output), value = TRUE)[1]

  # set_age_na controlls if age_year_var should be set to NA if age_month_var is sampled
  # same is done for age_month_var and age_day_var
  set_age_na <- TRUE
  if (dictionary == "Mortality")
    set_age_na <- FALSE

  if (!is.na(age_year_var)) {
    # sample 0:120
    dis_output[, age_year_var] <- sample(0:120, numcases, replace = TRUE)
    U2_YEARS <- which(dis_output[, age_year_var] <= 2)
    if (set_age_na)
      dis_output[U2_YEARS, age_year_var] <- NA

    if (!is.na(age_month_var)) {
      # age_month
      if (length(U2_YEARS) > 0) {
        dis_output[U2_YEARS, age_month_var] <- sample(0:23,
                                                      length(U2_YEARS),
                                                      replace = TRUE)
        U2_MONTHS <- which(dis_output[, age_month_var] <= 2)
        if (set_age_na)
          dis_output[U2_MONTHS, age_month_var] <- NA
      }

      if (!is.na(age_day_var)) {
        # age_days
        if (length(U2_MONTHS) > 0) {
          dis_output[U2_MONTHS, age_day_var] <- sample(0:60,
                                                       length(U2_MONTHS),
                                                       replace = TRUE)
        }
      }
    }
  }



  if (dictionary == "Cholera" | dictionary == "Measles") {
    # fix pregnancy stuff
    dis_output$pregnant[dis_output$sex != "F"] <- "NA"
    PREGNANT_FEMALE <- which(dis_output$sex != "F" |
                               dis_output$pregnant != "Y")

    dis_output$foetus_alive_at_admission[PREGNANT_FEMALE]  <- NA
    dis_output$trimester[PREGNANT_FEMALE]                  <- NA
    dis_output$delivery_event[PREGNANT_FEMALE]             <- "NA"
    dis_output$pregnancy_outcome_at_exit[PREGNANT_FEMALE]   <- NA
    dis_output$pregnancy_outcome_at_exit[dis_output$delivery_event != "1"] <- NA
  }


  if (dictionary == "Cholera") {
    dis_output$ors_consumed_litres <- sample(1:10, numcases, replace = TRUE)
    dis_output$iv_fluids_received_litres <- sample(1:10, numcases, replace = TRUE)
  }

  if (dictionary == "Measles") {
    dis_output$baby_born_with_complications[PREGNANT_FEMALE &
                                             dis_output$delivery_event != "1"] <- NA
  }

  if (dictionary == "Meningitis") {
    # T1 lab sample dates before admission
    # add 2 to admission....
    dis_output$date_ti_sample_sent[dis_output$date_ti_sample_sent <=
                                       dis_output$date_of_consultation_admission] <-
      dis_output$date_of_consultation_admission[dis_output$date_ti_sample_sent <=
                                                  dis_output$date_of_consultation_admission] + 2

    # fix pregnancy delivery
    dis_output$delivery_event[dis_output$sex != "F"] <- "NA"
  }

  if (dictionary == "Mortality") {
    # q53_cq4a ("Why is no occupant agreeing to participate?") shoud be NA if
    # Head of Household answers the questions (q49_cq3)
    dis_output$q53_cq4a[dis_output$q49_cq3 == "Yes"] <- NA
    # assume person is not born during study when age > 1
    dis_output$q87_q32_born[dis_output$q155_q5_age_year > 1] <- "No"
    dis_output$q88_q33_born_date[dis_output$q155_q5_age_year > 1] <- NA
    # pregnancy set to NA for males
    dis_output$q152_q7_pregnant[dis_output$q4_q6_sex == "Male"] <- NA

    # set Columns that are relate to "death" as NA if "q136_q34_died" is "No"
    died <- dis_output$q136_q34_died == "No"
    dis_output[died, c("q137_q35_died_date", "q138_q36_died_cause",
                       "q141_q37_died_violence", "q143_q41_died_place",
                       "q145_q43_died_country")] <- NA
    # more plausibility checks of generated data might be implemented in the future
  }

  # return dataset as a tibble
  dplyr::as_tibble(dis_output)

}




# function to switch from coded to named values (based on data dictionaries)
#' @export
#' @rdname msf_dict
switch_vals <- function(df, disease) {
  # read in appropriate dictionary as a list
  dat_dict <- msf_dict(disease, compact = FALSE)

  # returns the row number which dataset names match to dictionary names
  matchers <- match(names(df), dat_dict$dictionary$data_element_shortname, nomatch = 0)
  # returns lookup IDs based on
  ids <- dat_dict$dictionary$used_optionset_uid[matchers]


  for (i in matchers[!is.na(ids)]) {

    # returns the name of variable currently being looped
    var <- dat_dict$dictionary$data_element_shortname[i]

    # returns the rows in options which match to variable lookups
    subsetter <- which(dat_dict$options$optionset_uid %in%
                         dat_dict$dictionary$used_optionset_uid[i])

    # changes the values from backend(code) to front end (names)
    df[[var]] <- plyr::mapvalues(df[[var]],
                                from = dat_dict$options$option_code[subsetter],
                                to = dat_dict$options$option_name[subsetter])
  }
  df
}







