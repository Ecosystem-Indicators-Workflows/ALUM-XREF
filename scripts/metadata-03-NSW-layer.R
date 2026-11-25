# ----- Setup -----

# Libraries

## tidyverse libraries
library(dplyr)
library(readr)
library(ecoSynthesis)

## Read and write other formats
library(jsonlite)

## Spatial data
library(terra)

## Generating descriptions
library(glue) # for evaluating r expressions in-place within chr strings
library(cli) # for cli::pluralize

# Paths
library(here)
# here::i_am("scripts/01-data-checks.R") #TODO: fails when script name does not exist yet

# Helper functions
source(here::here("scripts/functions.R"))

out_dir <- here::here("results/output2-NSW-extant")
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

# ----- Metadata creation and writing -----

# Get data from here:
# codemeta <- read_json(here::here("codemeta.json"))
codeRepository <- "https://github.com/Ecosystem-Indicators-Workflows/ALUM-XREF"
version <- "0.1.0"

# Update these:
metadata <- read_json(here::here("results/template-zenodo.json"))
datapkg <- read_json(here::here("results/template-datapackage.json"))

# Write here:

metadata_out <- here::here(out_dir, ".zenodo.json")
datapkg_out <- here::here(out_dir, "datapackage.json")

# Input files

input_filenames <- c(
  efg_lookup_file = "IUCN-GET-pixel-lookup.csv",
  xref_tiff_file = "NSW-extant-EFG-target.tiff",
  xref_clr_file = "NSW-extant-EFG-target.clr",
  xref_aux_file = "NSW-extant-EFG-target.tiff.aux.xml",
  xref_vat_file = "NSW-extant-EFG-target.tiff.vat.dbf",
  xref_qml_file = "NSW-extant-EFG-target.qml"
)
input_files <- here::here(out_dir, input_filenames)
names(input_files) <- names(input_filenames)

input_files_info <- file_checks(
  input_files,
  here::here("data/metadata/data-checksums.txt"),
  "input"
)

xref_tiff_filename <- input_filenames["xref_tiff_file"]
efg_lookup_filename <- input_filenames["efg_lookup_file"]

efg_lookup_tbl <- read_csv(input_files["efg_lookup_file"])
r_target <- rast(input_files["xref_tiff_file"])


## ----- resources for datapackage -----

rs <- list()


# nr_pct_list <- xref_best_tbl |>
#   dplyr::filter(in_pct_list, eligible) |>
#   n_distinct("PCTID")
# nr_pct_extra <- how_many_units - nr_pct_list
# nr_assigned <- xref_best_tbl |>
#   dplyr::filter(!is.na(EFG)) |>
#   n_distinct("PCTID")
# nr_assigned_map <- xref_best_tbl |>
#   dplyr::filter(!is.na(EFG), on_map) |>
#   n_distinct("PCTID")
# total_rounds <- max(the_round, na.rm = TRUE)
# nr_eligible <- xref_best_tbl |>
#   dplyr::filter(eligible) |>
#   n_distinct("PCTID")
nr_targets <- n_distinct(efg_lookup_tbl$EFG, na.rm = TRUE)

# Spatial grid statistics
crs_info <- crs(r_target, describe = TRUE)
crs_label <- sprintf(
  "%s (%s:%s)",
  crs_info$name[1],
  crs_info$authority[1],
  crs_info$code[1]
)

res_xy <- res(r_target)

pixel_km2 <- prod(res_xy) / 1e6
pixel_ha <- prod(res_xy) / 1e4 #TODO: check downstream usage, does not appear to be used
n_rows <- nrow(r_target)
n_cols <- ncol(r_target)
n_bands <- nlyr(r_target)
total_cells <- ncell(r_target) #TODO: check downstream usage, does not appear to be used
ext_bbox <- as.vector(ext(r_target)) # xmin, xmax, ymin, ymax

dimensions <- list(
  rows = n_rows,
  columns = n_cols,
  bands = n_bands
)

datapkg$spatial <-
  c(
    crs = paste(crs_info[2:3], collapse = ":"),
    crs_name = crs_info$name,
    bbox = list(ext_bbox),
    resolution_meters = list(res_xy),
    dimensions = dimensions
  )

### ----- 'Cross-reference summary' (`xref_best_tbl`) datapackage resource -----

# descriptions <- c(
#   PCTID = "Plant Community Type (PCT) identifier in the NSW Master List of PCTs (release C3.0, under prep.) for the source units.",
#   PCTName = "Name of the Plant Community Type.",
#   status = "PCT status in the NSW Master List of PCTs (Approved or Decommissioned).",
#   eligible = "Whether the source unit is eligible for cross-referencing to an ecosystem concept in the IUCN GET (TRUE for PCTs with status Approved).",
#   in_pct_list = "Whether the PCT is in the NSW Master List of PCTs (release C3.0).",
#   on_map = "Whether the PCT is present in the SVTM Preclearing map (release C3.0).",
#   class = "Vegetation class of the PCT (NSW Master List).",
#   formation = "Vegetation formation of the PCT (NSW Master List).",
#   EFG = "Best-candidate IUCN Global Ecosystem Typology Level 3 Ecosystem Functional Group code (e.g., T2.5). Empty when no interpreter cross-referenced the PCT.",
#   efg_name = "Full name of the best-candidate IUCN GET Ecosystem Functional Group.",
#   efg_pixel_value = glue::glue(
#     "Standard integer pixel value used in {xref_tiff_filename} and the Global Ecosystems Atlas (geco package)."
#   ),
#   efg_hex_code = "Standard hexadecimal color code (#RRGGBB) for the EFG from the geco package.",
#   efg_rgb_code = "Comma-separated RGB color values (R,G,B) for the EFG.",
#   round = glue::glue(
#     "Expert elicitation round number used for synthesis ({the_round} = revised assessment after group discussion)."
#   ),
#   prop_memb = glue::glue(
#     "Proportion of total Round {the_round} membership values across all interpreters assigned to the best-candidate EFG (0 to 1)."
#   ),
#   total_memb = cli::pluralize(
#     "Sum of membership values across all interpreters for the PCT in Round {the_round} (data range: {min_memb} to {max_memb} indicates errors, should be equal to {total_experts * 1.0} when {total_experts} interpreter{?s} assessed the unit with weight{?s} summing to 1)."
#   ),
#   supporting = cli::pluralize(
#     "Number of interpreters in Round {the_round} who assigned a non-zero membership (> 0) to the best-candidate EFG (range: {min_supporting} to {max_supporting}).",
#     "{qty(as.integer(min_supporting == max_supporting))} {?Not every} interpreter assessed every PCT."
#   ),
#   total_interp = pluralize(
#     "Number of interpreters who assessed the PCT (1 to {total_experts}). {?Not every} interpreter assessed every PCT."
#   )
# )

# finfo <- input_files_info |> slice(match("xref_best_file", shortname))

# rs[[1]] <- list(
#   name = "Crossreference summary",
#   path = finfo$file_name,
#   profile = "tabular-data-resource",
#   format = "csv",
#   mediatype = "text/csv",
#   hash = unname(finfo$md5sum),
#   encoding = guess_encoding(names(finfo$md5sum))$encoding[1],
#   description = glue::glue(
#     "Synthesised best-candidate cross-reference table linking all {nr_pct_list} PCTs of the NSW Master List (release C3.0, under prep.), as well as {nr_pct_extra} PCTs not in that list, to IUCN GET Level 3 Ecosystem Functional Groups from Round {total_rounds} expert elicitation. {nr_assigned} were assigned, of which {nr_assigned_map} were mapped."
#   ),
#   schema = list(
#     primaryKey = "PCTID",
#     fields = list_schema_fields_tbl(xref_best_tbl, descriptions)
#   )
# )

### ----- 'EFG Lookup Table' (`efg_lookup_tbl`) datapackage resource -----

min_pixel <- min(efg_lookup_tbl$Value)
max_pixel <- max(efg_lookup_tbl$Value)

descriptions <- c(
  Value = glue::glue(
    "Integer pixel value encoded in {xref_tiff_filename} ({min_pixel} to {max_pixel})."
  ),
  Counts = "Number of raster cells per Ecosystem Functional Group",
  EFG = "IUCN GET Level 3 Ecosystem Functional Group code (e.g., T2.3, TF1.6).",
  efg_name = "Full name of the Ecosystem Functional Group.",
  # realm_id = "IUCN GET Level 1 Realm code (T, TF, F, MT, MFT).",
  # realm_name = "IUCN GET Level 1 Realm name.",
  # biome_id = "IUCN GET Level 2 Functional Biome code.",
  # biome_name = "IUCN GET Level 2 Functional Biome name.",
  efg_hex_code = "Standard hexadecimal color code (#RRGGBB).",
  efg_rgb_code = "Comma-separated RGB color components (R,G,B)."
  # n_PCT_units = "Number of PCTs on the map assigned to this EFG as their best candidate."
)


finfo <- input_files_info |> slice(match("efg_lookup_file", shortname))

rs[[1]] <- list(
  name = "Pixel Lookup table",
  path = finfo$file_name,
  profile = "tabular-data-resource",
  format = "csv",
  mediatype = "text/csv",
  hash = unname(finfo$md5sum),
  encoding = guess_encoding(names(finfo$md5sum))$encoding[1],
  description = glue::glue(
    "Lookup table for the {nr_targets} IUCN Global Ecosystem Typology Level 3 Ecosystem Functional Groups mapped as best candidates in New South Wales, including integer raster pixel values, realm/biome hierarchy, and color codes."
  ),
  schema = list(
    primaryKey = "efg_pixel_value",
    fields = list_schema_fields_tbl(efg_lookup_tbl, descriptions)
  )
)

### ----- 'Best candidate EFG raster' datapackage resource -----

finfo <- input_files_info |> slice(match("xref_tiff_file", shortname))

rs[[2]] <- list(
  name = "Best candidate EFG raster",
  path = finfo$file_name,
  format = "GeoTIFF",
  mediatype = "image/tiff; application=geotiff",
  hash = unname(finfo$md5sum),
  description = glue::glue(
    "90 m raster of the best-candidate IUCN GET Ecosystem Functional Group (integer pixel values {min_pixel} to {max_pixel} matching {efg_lookup_filename}, with embedded color table) in {crs_label}."
  )
)

### ----- 'Best candidate EFG sidecar file' datapackage resource -----

finfo <- input_files_info |> slice(match("xref_aux_file", shortname))

rs[[3]] <- list(
  name = "Best candidate EFG sidecar file",
  path = finfo$file_name,
  format = "XML",
  mediatype = "application/xml",
  hash = unname(finfo$md5sum),
  description = glue::glue(
    "Persistent Auxiliary Metadata (PAM) with categorical information for {xref_tiff_filename}."
  )
)


finfo <- input_files_info |> slice(match("xref_vat_file", shortname))

rs[[4]] <- list(
  name = "Best candidate EFG sidecar file",
  path = finfo$file_name,
  format = "dbf",
  mediatype = "application/dbase",
  hash = unname(finfo$md5sum),
  description = glue::glue(
    "Raster Value Attribute Table (VAT) storing cell values, labels and colour codes for {xref_tiff_filename}."
  )
)

### ----- 'Best candidate EFG colour file' datapackage resource -----

finfo <- input_files_info |> slice(match("xref_clr_file", shortname))

rs[[5]] <- list(
  name = "Best candidate EFG colour file",
  path = finfo$file_name,
  format = "CLR",
  mediatype = "text/plain",
  hash = unname(finfo$md5sum),
  description = glue::glue(
    "GDAL / ArcGIS RGBA color map file for {xref_tiff_filename}."
  )
)

### ----- 'Best candidate EFG style file' datapackage resource -----

finfo <- input_files_info |> slice(match("xref_qml_file", shortname))

rs[[6]] <- list(
  name = "Best candidate EFG style file",
  path = finfo$file_name,
  format = "QML",
  mediatype = "application/xml",
  hash = unname(finfo$md5sum),
  description = glue::glue(
    "QGIS layer style file providing automatic paletted rendering and EFG code/name legend labels for {xref_tiff_filename}."
  )
)


### ----- Best candidate -----

metadata$title <- datapkg$title <- "Extant distribution of Ecosystem Funcional Groups of the IUCN Global Ecosystem Typology in New South Wales: 90m Best-Candidate Spatial Dataset"

datapkg$name <- "nsw--extant-EFG-iucn-get-90m-best-candidate"

datapkg$description <- cli::pluralize(
  "Spatial dataset (90 m GeoTIFF rasters) of the extant distribution of Level 3 Ecosystem Functional Groups (EFGs) of the <strong>IUCN Global Ecosystem Typology (IUCN GET)</strong> in NSW based on a combination of two products: a) a synthesis of cross-referencing the Plant Community Types (<strong>PCT</strong>) of the NSW State Vegetation Type Map (SVTM Pre-clearing C3.0) and b) a cross-reference of Land Use Map classes."
)
datapkg$contributors <- metadata$creators
datapkg$created <- metadata$publication_date <- format(
  Sys.Date(),
  format = "%Y-%m-%d"
)

metadata$description <- glue::glue(
  "<p>This dataset provides a 90 m spatial dataset of the extant distribution of Level 3 Ecosystem Functional Groups (EFGs) of the <strong>IUCN Global Ecosystem Typology (IUCN GET)</strong> in NSW based on a combination of two products: a) a synthesis of cross-referencing the Plant Community Types (<strong>PCT</strong>) of the NSW State Vegetation Type Map (SVTM Pre-clearing C3.0) and b) a cross-reference of Land Use Map classes.</p>

<p>Anthropogenic EFGs derived from land use data are overlaid on top of natural EFGs representing pre-clearing vegetation.</p>

<p>The EFG <strong>T5.6 Semi-arid woodlands</strong> is used by the interpreters but is not in the IUCN GET Level 3 list; it is mapped with pixel value 35.</p>

<p><strong>Attribution requirement:</strong> Spatial layers are derived from the NSW State Vegetation Type Map (SVTM) Pre-clearing PCT, release C3.0, &copy; State Government of NSW and NSW Department of Climate Change, Energy, the Environment and Water 2020, available via the <a href=\"https://datasets.seed.nsw.gov.au/dataset/nsw-state-vegetation-type-map\">SEED portal</a> and Land use of Australia 2020–21 layer, version 7.1, &copy; Australian Bureau of Agricultural and Resource Economics and Sciences, Canberra, available through DOI:<a href=\"https://doi.org/10.25814/n0z4-5y98\">10.25814/n0z4-5y98</a>.</p>"
)

metadata$related_identifiers <- c(
  metadata$related_identifiers,
  list(
    list(
      identifier = codeRepository,
      relation = "isDerivedFrom",
      resource_type = "software",
      scheme = "url"
    ),
    list(
      identifier = "https://datasets.seed.nsw.gov.au/dataset/nsw-state-vegetation-type-map",
      relation = "isDerivedFrom",
      resource_type = "dataset",
      scheme = "url"
    ),
    list(
      identifier = "https://www.environment.nsw.gov.au/publications/bionet-plant-community-type-data",
      relation = "isDerivedFrom",
      resource_type = "dataset",
      scheme = "url"
    ),
    list(
      identifier = "10.5281/zenodo.24464308",
      relation = "isDerivedFrom",
      resource_type = "dataset",
      scheme = "doi"
    )
  )
)

source_note <- glue::glue(
  "NSW State Vegetation Type Map (SVTM) Pre-clearing, release C3.0, NSW Department of Climate Change, Energy, the Environment and Water, ",
  "\u00A9; State Government of NSW and NSW Department of Climate Change, Energy, the Environment and Water 2020, via the SEED portal; ",
  "Plant Community Types from BioNet, NSW Department of Climate Change, Energy, the Environment and Water."
)
# metadata$notes <- sprintf(metadata$notes, source_note)
metadata$version <- datapkg$version <- version
datapkg$homepage <- codeRepository
datapkg$licenses <- c(
  datapkg$licenses,
  list(
    list(
      name = "source attribution",
      title = "Source SVTM data &copy; State Government of NSW and NSW Department of Climate Change, Energy, the Environment and Water 2020 (Creative Commons Attribution 4.0)",
      path = "https://datasets.seed.nsw.gov.au/dataset/nsw-state-vegetation-type-map"
    ),
    list(
      name = "source attribution",
      title = "Land use of Australia 2010–11 to 2020–21 (version 7.1, 2026). &copy; Australian Bureau of Agricultural and Resource Economics and Sciences, Canberra (Creative Commons Attribution 4.0)",
      path = "https://doi.org/10.25814/n0z4-5y98"
    )
  )
)

# metadata$keywords <- c(unlist(metadata$keywords), "New South Wales")

datapkg$resources <- rs

write_json(
  metadata,
  metadata_out,
  auto_unbox = TRUE,
  pretty = TRUE
)

write_json(
  datapkg,
  datapkg_out,
  auto_unbox = TRUE,
  pretty = TRUE
)

if (fs::file_exists(datapkg_out) & fs::file_exists(metadata_out)) {
  cli::cli_alert_success(
    "Output metadata written: {basename(metadata_out)}, {basename(datapkg_out)}"
  )
} else {
  cli::cli_alert_danger(
    "Output metadata not successfully written: {basename(metadata_out)}, {basename(datapkg_out)}"
  )
}
