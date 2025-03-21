# Get Data from the site

suppressPackageStartupMessages({
  library(tidyverse)
  library(httr)
  library(jsonlite)
})

template <-
  "https://kinase-library.phosphosite.org/api/scorer/score-site/{modified}/200/OCHOA/true/false/true"

data <- read_csv(file.path("data", "input_sequence_data.csv")) |>
  mutate(request = str_glue(template, modified = prepared_sequence))

process_request <- function(peptide_id, sequence, chip, url) {
  output_file <- file.path(
    "data",
    "individual",
    chip,
    str_glue("{peptide_id}.csv")
  )

  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

  col_spec <- cols(
    .default = col_character(),
    sitePosition = col_double(),
    score = col_double(),
    scoreQuantile = col_double(),
    scorePosition = col_double(),
    scoreDistributionSize = col_double(),
    scoreRank = col_double(),
    quantileRank = col_double(),
    id = col_double(),
    weakCatalyticActivity = col_logical()
  )

  if (!file.exists(output_file)) {
    message(str_glue("Downloading data for {peptide_id}"))
    Sys.sleep(1)
    res <- GET(url)

    data <- content(res, as = "text", encoding = "utf8") |>
      fromJSON() |>
      as_tibble() |>
      unnest(scores) |>
      unnest(motif) |>
      mutate(
        peptide_id = peptide_id,
        sequence = sequence
      ) |>
      select(-visibility) |>
      write_csv(output_file)
  } else {
    message(str_glue("Data for {peptide_id} already downloaded"))
    data <-
      read_csv(output_file,
        col_types = col_spec,
        show_col_types = FALSE
      )
  }
}

all_data <- data |>
  select(ID, prepared_sequence, chip_type, request) |>
  pmap_dfr(~ process_request(..1, ..2, ..3, ..4)) |>
  write_csv("results/complete_kinase_specificity_map_raw.csv.gz") |>
  select(
    peptide_id,
    sequence,
    siteLabel,
    kinase_name = name,
    gene_name = geneName,
    kinase_group = motifGroup,
    kinase_type = type,
    score,
    score_quantile = scoreQuantile,
    score_rank = scoreRank,
    quantile_rank = quantileRank,
    score_position = scorePosition,
    score_distribution_size = scoreDistributionSize,
    weak_activity = weakCatalyticActivity
  ) |>
  write_csv("results/complete_kinase_specificity_map.csv.gz")
