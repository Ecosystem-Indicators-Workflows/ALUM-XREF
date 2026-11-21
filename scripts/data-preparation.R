library(readxl)
library(readr)
library(dplyr)
library(stringr)
library(ecoSynthesis)
library(geco)
library(terra)

here::i_am("scripts/data-preparation.R")
gisdata_dir <- here::here("data/source-data")
out_dir <- here::here("results/best-candidate")
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}


#| label: Custom functions and options
source(here::here("scripts", "functions.R"))

#' ## Step 1 Check input and output files
#'
#| label: Check input files
input_files <- c(
  xref_tbl = file.path(gisdata_dir, "Crosswalks/ALUM-IUCNGET.xlsx"),
  source_lut = file.path(gisdata_dir, "NLUM_v7_1_250m_ALUMV8_2020_21_alb.csv"),
  source_tif = file.path(gisdata_dir, "NLUM_v7_1_250m_ALUMV8_2020_21_alb.tif")
)
input_files_info <- file_checks(
  input_files,
  here::here("data/metadata/data-checksums.txt"),
  "input"
)

#| label: output paths
output_files <- c(
  "ALUM-xref-best-candidate.csv",
  "IUCN-GET-pixel-lookup.csv",
  "ALUM-xref-target.clr",
  "ALUM-xref-target.qml",
  "ALUM-xref-target.tiff"
)
output_files <- file.path(out_dir, output_files)
names(output_files) <- c(
  "best_candidate_table",
  "efg_lookup_table",
  "target_clr_table",
  "target_qml_style",
  "target_tiff"
)


xref_ALUM <- read_excel(input_files["xref_tbl"], sheet = "SSSOM") |>
  transmute(
    ID = str_replace(`rdf:subject`, "alum:", ""),
    alum_label = `sssom:subject_label`,
    obj_id = str_replace(`rdf:object`, "get:groups/", ""),
    obj_label = `sssom:object_label`,
    id = `dcterms:creator`,
    interpreter = `sssom:creator_label`,
    date_created = `dcterms:created`,
    membership = 1,
    round = 1
  ) |>
  membership_tbl(source_id = "ID", target_id = "obj_id", round = "round")

IUCN_GET_LUT <- lookup_tbl(IUCN_GET_LUT, id = "efg_id", name = "efg_name")

ALUM_LUT <- read_csv(input_files["source_lut"]) |>
  mutate(
    ID = str_extract(TERTV8, "[0-9\\.]+"),
    eligible = !is.na(ID)
  ) |>
  lookup_tbl(id = "ID", name = "TERTV8", "eligible")

xref_ALUM_filtered <- xref_ALUM |>
  filter(ID %in% ALUM_LUT$ID, obj_id %in% IUCN_GET_LUT$efg_id)

check_membership(xref_ALUM_filtered, source = ALUM_LUT, target = IUCN_GET_LUT)

table(xref_ALUM_filtered$obj_id)


ALUMV8 <- rast(input_files["source_tif"])

efg_info <- geco_efg_data() |>
  select(efg_code, efg_name, efg_pixel_value, efg_hex_code, efg_rgb_code) |>
  arrange(efg_pixel_value)

xref_best_tbl <- xref_ALUM_filtered |>
  left_join(ALUM_LUT, by = "ID") |>
  left_join(efg_info, by = c("obj_id" = "efg_code")) |>
  select(
    Value,
    ID,
    alum_label,
    eligible,
    efg_code = obj_id,
    efg_name,
    efg_pixel_value,
    efg_hex_code,
    efg_rgb_code,
    round,
    membership,
    interpreter
  )


#' ## Step 4 Outputs
cat(sprintf("Export tabular results\n"))
write_csv(xref_best_tbl, output_files["best_candidate_table"], na = "")
cat(sprintf("Export tabular lookup table (EFGs present on the map)\n"))

efg_lookup_tbl <- xref_best_tbl |>
  #   filter(!is.na(EFG), on_map) |>
  filter(!is.na(efg_code)) |>
  summarise(
    n_ALUM_units = n_distinct(ID),
    .by = c(efg_pixel_value, efg_code, efg_name, efg_hex_code, efg_rgb_code)
  ) |>
  left_join(
    as_tibble(IUCN_GET_LUT) |>
      select(efg_id, realm_id, realm_name, biome_id, biome_name),
    by = c("efg_code" = "efg_id")
  ) |>
  select(
    efg_pixel_value,
    efg_code,
    efg_name,
    realm_id,
    realm_name,
    biome_id,
    biome_name,
    efg_hex_code,
    efg_rgb_code,
    n_ALUM_units
  ) |>
  arrange(efg_pixel_value)

write_csv(efg_lookup_tbl, output_files["efg_lookup_table"], na = "")

#' Export colour file
cat(sprintf("Export colour tables and style files\n"))

clr_lines <- efg_lookup_tbl |>
  tidyr::separate(efg_rgb_code, into = c("R", "G", "B"), sep = ",") |>
  transmute(
    line = sprintf(
      "%d %s %s %s 255 %s %s",
      efg_pixel_value,
      R,
      G,
      B,
      efg_code,
      efg_name
    )
  ) |>
  pull(line)

writeLines(clr_lines, output_files["target_clr_table"])

### Export style file

qml_entries <- efg_lookup_tbl |>
  transmute(
    entry = sprintf(
      '        <paletteEntry value="%d" color="%s" alpha="255" label="%s %s"/>',
      efg_pixel_value,
      efg_hex_code,
      efg_code,
      efg_name
    )
  ) |>
  pull(entry)

writeLines(qml_lines(qml_entries), output_files["target_qml_style"])


class_matrix <- xref_best_tbl |>
  filter(!is.na(efg_code)) |>
  transmute(Value, efg_pixel_value)

ALUMV8_GET <- classify(ALUMV8, rcl = class_matrix, others = NA)


ctab <- efg_info |>
  filter(efg_code %in% efg_lookup_tbl$efg_code) |>
  transmute(value = efg_pixel_value, color = efg_hex_code)
coltab(ALUMV8_GET) <- ctab

raster_attributes <- efg_lookup_tbl |>
  transmute(
    id = efg_pixel_value,
    label = paste(efg_code, efg_name, sep = " ")
  )
levels(ALUMV8_GET) <- as.data.frame(raster_attributes)


rast_metadata <- c(
  PROJECT = "Ecosystem Indicators Workflows",
  TITLE = "Best candidate ecosystem functional group",
  DESCRIPTION = "Synthesis of crossreference from ALUM V8 to IUCN GET"
)

cat(sprintf(" metadata..."))
metags(ALUMV8_GET) <- rast_metadata

cat(sprintf(" write output..."))
writeRaster(
  ALUMV8_GET,
  output_files["target_tiff"],
  datatype = "INT1U",
  overwrite = TRUE
)
cat(sprintf(" Done!\n\n"))
