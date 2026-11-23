# epsg_code <- "EPSG:9473" # Australian Albers

gdal pipeline ! read EIW-XREF/id24034200/TASVEG-xref-target.tiff ! reproject --dst-crs EPSG:9473 --resampling nearest --resolution 90,90 ! write TASVEG-xref-target.tiff --overwrite

gdal pipeline ! read EIW-XREF/id24398849/NSWPCT-xref-target.tiff ! reproject --dst-crs EPSG:9473 --resampling nearest --resolution 90,90 ! write NSWPCT-xref-target.tiff --overwrite

gdal pipeline ! read EIW-XREF/id24462545/ntveg-xref-target.tiff ! reproject --dst-crs EPSG:9473 --resampling nearest --resolution 90,90 ! write NTVEG-xref-target.tiff --overwrite


gdal raster mosaic --output-format COG NSWPCT-xref-target.tiff TASVEG-xref-target.tiff EIW-XREF/id24207311/DPIRD-xref-target.tiff  NTVEG-xref-target.tiff AUS-XREF.tif

# gdal raster mosaic --output-format COG --creation-option BIGTIFF=YES *.tif mosaic.tif