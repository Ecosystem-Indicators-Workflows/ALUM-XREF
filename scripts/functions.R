# Lines of a QGIS style file (.qml) for a paletted raster, given the
# <paletteEntry .../> lines (template from WAVSA-XREF
# 10-create-output-best-candidate.R)

qml_lines <- function(qml_entries) {
  c(
    "<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>",
    '<qgis version="3.34.0" minScale="1e+08" maxScale="0" hasScaleBasedVisibilityFlag="0" styleCategories="AllStyleCategories">',
    "  <pipe>",
    "    <provider>",
    '      <resampling enabled="false" maxOversampling="2" zoomedInResamplingMethod="nearestNeighbour" zoomedOutResamplingMethod="nearestNeighbour"/>',
    "    </provider>",
    '    <rasterrenderer band="1" type="paletted" opacity="1" alphaBand="-1" nodataColor="">',
    "      <rasterTransparency/>",
    "      <minMaxOrigin>",
    "        <limits>None</limits>",
    "        <extent>WholeRaster</extent>",
    "        <statAccuracy>Estimated</statAccuracy>",
    "        <cumulativeCutLower>0.02</cumulativeCutLower>",
    "        <cumulativeCutUpper>0.98</cumulativeCutUpper>",
    "        <stdDevFactor>2</stdDevFactor>",
    "      </minMaxOrigin>",
    "      <colorPalette>",
    qml_entries,
    "      </colorPalette>",
    "    </rasterrenderer>",
    '    <brightnesscontrast brightness="0" contrast="0" gamma="1"/>',
    '    <huesaturation colorizeGreen="128" colorizeOn="0" colorizeRed="255" colorizeBlue="128" grayscaleMode="0" saturation="0" colorizeStrength="100"/>',
    '    <rasterresampler maxOversampling="2"/>',
    "  </pipe>",
    "  <blendMode>0</blendMode>",
    "</qgis>"
  )
}

### Custom functions for md5sum checks

file_checks <- function(
  x,
  md5sum_file,
  what = c("input", "output"),
  skip_checks = FALSE
) {
  message("using `file_checks` from scripts/functions.R")
  require(stringr)
  require(tools)

  what <- match.arg(what)
  message(sprintf("\nCheck %s %s files:\n", length(x), what))

  # Read lines from the checksum file
  lines <- readLines(md5sum_file)
  lines <- lines[nzchar(lines)] # Remove empty lines

  # Split each line into the expected hash and the relative file path
  expected_hashes <- sub("\\s+.*$", "", lines)
  file_names <- sub("^[0-9a-fA-F]+\\s+\\*?", "", lines)

  # Create a summary data frame
  md5hash <- data.frame(
    file_path = file_names,
    expected = tolower(expected_hashes)
  )
  root_path <- here::here()
  rel_path <- str_replace(x, root_path, "") |> str_replace("^/", "")

  results <- tibble(
    shortname = names(x),
    file_name = basename(x),
    size = file.size(x),
    md5sum = md5sum(x),
    file_path = rel_path
  ) |>
    left_join(md5hash, by = "file_path") |>
    transmute(
      shortname,
      file_name,
      md5sum,
      expected,
      check = if_else(md5sum == expected, "Ok", "Not Ok :("),
      size,
      file_path
    )

  message(sprintf(
    "\n\tCheck completed %s/%s files matched\n\n",
    sum(results$check %in% "Ok"),
    length(x)
  ))
  if (what == "input") {
    if (any(results$check %nin% "Ok")) {
      message(
        c(
          "Wait! Something is wrong!",
          "\tFiles missing or their content changed since last run",
          "\tCheck inputs and recalculate md5sum if needed!"
        )
      )
      if (!skip_checks) {
        print(results)
        stop(
          "You should not continue until you fix the input files"
        )
      }
    } else {
      message(
        c(
          "All files match expected md5sum hash",
          "\tThis is good for reproducibility!"
        )
      )
    }
  }
  if (what == "output") {
    if (any(results$check %in% "Ok")) {
      message(c(
        "Some outputs match expected values"
      ))
      if (!skip_checks) {
        print(results)
        stop(
          "Stopping here to avoid overwriting!\n\tIf you want to rerun the analysis, remove older files."
        )
      } else {
        message(c(
          "\tThis is good news for reproducibility!",
          "\tCheck inputs and outputs to make sure they are consistent."
        ))
      }
    }
  }
  return(results)
}

## Functions for metadata processing

#' List metadata schema fields for a tbl
#'
#' @param tbl A tibble or data.frame
#' @param descriptions A named character vector of variables descriptions
#' @return A list whose length is equal to the length of `descriptions` and the number of columns in `tbl`, which must be equal.
#' @details
#' For each variable name in `tbl` a tupple of name, type and description is returned.
list_schema_fields_tbl <- function(tbl, descriptions) {
  stopifnot(setequal(names(tbl), names(descriptions)))
  purrr::imap(tbl, \(x, nm) {
    list(name = nm, type = class(x)[1], description = unname(descriptions[nm]))
  }) |>
    unname()
}
