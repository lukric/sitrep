context("age pyramid tests")

set.seed(2018-01-15)
ages <- cut(sample(80, 150, replace = TRUE),
           breaks = c(0, 5, 10, 30, 50, 80, 100), right = FALSE)
sex  <- sample(c("Female", "Male"), 150, replace = TRUE)
ill  <- sample(0:1, 150, replace = TRUE)
dat  <- data.frame(AGE = ages, sex = sex, ill = ill, stringsAsFactors = FALSE)
ap1  <- plot_age_pyramid(dat, age_group = "AGE")
ap2  <- plot_age_pyramid(dat, age_group = "AGE", split_by = "ill")

test_that("age pyramid returns a ggplot2 object", {
  expect_is(ap1, "ggplot")
  expect_is(ap2, "ggplot")
})

test_that("choosing a column that doesn't exist results in an error", {
  expect_error(plot_age_pyramid(dat, age_group = "pourg_ega"))
})

test_that("plot by sex default works", {
  expect_true("sex" %in% colnames(ap1$data))
  expect_equal(unique(ap1$data$sex), c("Female", "Male"))
})

test_that("plot by sex default works", {
  expect_true("sex" %in% colnames(ap1$data))
  expect_true("AGE" %in% colnames(ap1$data))
  expect_false("ill" %in% colnames(ap1$data))
  expect_equal(unique(ap1$data$sex), c("Female", "Male"))
})

test_that("plot by ill works", {
  expect_true("ill" %in% colnames(ap2$data))
  expect_true("AGE" %in% colnames(ap2$data))
  expect_false("sex" %in% colnames(ap2$data))
  expect_equal(unique(ap2$data$ill), as.character(0:1))
})

test_that("missing levels are still plotted", {
  datd <- dat[dat$AGE != levels(dat$AGE)[2], , drop = FALSE]
  ap3 <- plot_age_pyramid(datd, age_group = "AGE")
  # Complete data has both groups
  expect_equal(sum(ap1$data$AGE == levels(dat$AGE)[2]), 2)
  # Incomplete data has groups replaced with NA
  expect_equal(sum(ap3$data$AGE == levels(dat$AGE)[2]), 1)
})

test_that("missing split data are removed before plotting", {
  dat$sex[69] <- NA
  expect_warning(plot_age_pyramid(dat, age_group = "AGE"),
                 "removing 1 observations with missing values in the sex column")
})
