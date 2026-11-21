here::i_am("scripts/01-download-ALUM-data.R")
data_url <- 'https://www.agriculture.gov.au/sites/default/files/documents/NLUM_v7_1_250m_ALUMV8_2020_21_alb_20260814.zip'

gisdata_dir <- here::here("data/source-data")
zip_file <- here::here(gisdata_dir, basename(data_url))
download.file(data_url, zip_file)

unzip(zipfile = zip_file, exdir = gisdata_dir)
