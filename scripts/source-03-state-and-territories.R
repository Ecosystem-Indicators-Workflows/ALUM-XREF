library(zen4R)
library(here)
library(httr)
output_dir <- here::here("data/source-data/EIW-XREF")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# If files are public, this should work
## download_zenodo('https://doi.org/10.5281/zenodo.24398850', path = output_dir)

readRenviron("~/.Renviron")
token_var <- "ZENODO_TOKEN"
token <- Sys.getenv(token_var)
if (!nzchar(token)) {
  stop(
    sprintf(
      "Missing API token: environment variable `%1$s` is not set.\nAdd `%1$s=\"...\"` to ~/.Renviron and restart R.",
      token_var
    ),
    call. = FALSE
  )
}

# 1. Connect using your Personal Access Token
zenodo <- ZenodoManager$new(
  token = token,
  logger = "INFO"
)

# 2. Fetch your embargoed deposition (use your record ID or DOI)
# rec <- zenodo$getDepositions(
#   q = "doi:%2210.5281/zenodo.24398850",
#   exact = TRUE
# )

ids <- c(WA = "24207312", NSW = "24398850", TAS = "24034201", NT = "24462545")
for (id in ids) {
  rec <- zenodo$getDepositionById(id)
  ## 10.5281/zenodo.24207312

  # 3. Check available files on the record
  rec$listFiles(pretty = TRUE)

  # 4. Download all files (or specify a subset with the `files` argument)

  # rec$downloadFiles(path = output_dir) # does not work with embargoed files

  download_dir <- here(output_dir, sprintf("id%s", rec$getConceptId()))
  dir.create(download_dir, recursive = TRUE, showWarnings = FALSE)

  for (f in rec$files) {
    # Draft depositions store the download link in f$links$download or f$download
    dl_url <- if (!is.null(f$links$download)) f$links$download else f$download
    dest <- file.path(download_dir, basename(f$filename %||% f$key))

    if (!file.exists(dest)) {
      resp <- GET(
        url = URLencode(dl_url),
        add_headers(Authorization = paste("Bearer", token)),
        write_disk(dest, overwrite = FALSE)
      )

      stop_for_status(resp)
      message("Downloaded: ", dest)
    } else {
      message("File found: ", dest)
    }
  }
}
