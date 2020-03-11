context("neotoma doi retrieval")
library(neotoma2lipd)

test_that("known doi retrieval", {
  expect_match(get_neotoma_doi(12), "10.21233/ZNEX-SP94")
})
