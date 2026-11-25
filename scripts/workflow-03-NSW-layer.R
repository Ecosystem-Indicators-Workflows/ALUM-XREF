library(terra)
library(here)
library(geco)
library(dplyr)
library(readr)


#| label: Custom functions and options
source(here::here("scripts", "functions.R"))

gisdata_dir <- here::here("data/source-data")
out_dir <- here::here("results/output2-NSW-extant")
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}
output_files <- c(
  "IUCN-GET-pixel-lookup.csv",
  "NSW-extant-EFG-target.clr",
  "NSW-extant-EFG-target.qml",
  "NSW-extant-EFG-target.tiff",
  "NSW-extant-EFG-target.tiff.vat.dbf"
)
output_files <- file.path(out_dir, output_files)
names(output_files) <- c(
  "efg_lookup_table",
  "target_clr_table",
  "target_qml_style",
  "target_tiff",
  "target_vat"
)


A <- rast("results/NSWPCT-xref-target.tiff")
B <- rast("results/ALUM-xref-target-NSW.tiff")

out <- cover(B, A)

# keep only A extent/data footprint
out <- mask(out, A)


pixel_counts <- data.frame(table(values(out)), stringsAsFactors = FALSE)
colnames(pixel_counts) <- c("Value", "Counts")

pixel_counts$Value <- as.numeric(as.character(pixel_counts$Value))

t5_6_info <- tibble(
  EFG = "T5.6",
  efg_name = "Semi-arid woodlands",
  efg_pixel_value = 35,
  efg_hex_code = "#EEB4B4",
  efg_rgb_code = "238,180,180"
) #rosybronw2

efg_info <- geco::geco_efg_data() |>
  dplyr::select(
    efg_code,
    efg_name,
    efg_pixel_value,
    efg_hex_code,
    efg_rgb_code
  ) |>
  dplyr::rename("EFG" = "efg_code") |>
  dplyr::bind_rows(t5_6_info) |>
  dplyr::arrange(efg_pixel_value)

efg_lookup_tbl <- pixel_counts |>
  left_join(efg_info, by = c("Value" = "efg_pixel_value"))


#' ## Step 4 Outputs

write_csv(efg_lookup_tbl, output_files["efg_lookup_table"], na = "")

#' Export colour file

clr_lines <- efg_lookup_tbl |>
  tidyr::separate(efg_rgb_code, into = c("R", "G", "B"), sep = ",") |>
  transmute(
    line = sprintf(
      "%d %s %s %s 255 %s %s",
      Value,
      R,
      G,
      B,
      EFG,
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
      Value,
      efg_hex_code,
      EFG,
      efg_name
    )
  ) |>
  pull(entry)

writeLines(qml_lines(qml_entries), output_files["target_qml_style"])


ctab <- efg_info |>
  filter(EFG %in% efg_lookup_tbl$EFG) |>
  transmute(value = efg_pixel_value, color = efg_hex_code)
coltab(out) <- ctab

raster_attributes <- efg_lookup_tbl |>
  transmute(
    id = Value,
    label = paste(EFG, efg_name, sep = " ")
  )
levels(out) <- as.data.frame(raster_attributes)


rast_metadata <- c(
  PROJECT = "Ecosystem Indicators Workflows",
  TITLE = "Extant ecosystem functional group",
  DESCRIPTION = "Synthesis of crossreference from NSW SVTM and ALUM V8 to IUCN GET"
)

cat(sprintf(" metadata..."))
metags(out) <- rast_metadata

cat(sprintf(" write output..."))
writeRaster(
  out,
  output_files["target_tiff"],
  datatype = "INT1U",
  overwrite = TRUE
)


### Export value attribute table AFTER creating the raster, otherwise it will be deleted

vat_data <- efg_lookup_tbl |>
  tidyr::separate(efg_rgb_code, into = c("Red", "Green", "Blue"), sep = ",") |>
  transmute(
    Value = Value,
    Count = Counts,
    Class = paste(EFG, efg_name, sep = " "),
    Red,
    Green,
    Blue,
    Alpha = 255,
    Color = efg_hex_code
  ) |>
  as.data.frame()

library(foreign)
write.dbf(vat_data, file = output_files["target_vat"])

cat(sprintf(" Done!\n\n"))
