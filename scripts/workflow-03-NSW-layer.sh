SRC_PRE=data/source-data/EIW-XREF/id24398849/NSWPCT-xref-target.tiff
SCR_LUL=results/output1-landuse-overlay/ALUM-xref-target.tiff
TGT_PRE=results/preliminaries/NSWPCT-xref-target.tiff
TGT_LUL=results/preliminaries/ALUM-xref-target-NSW.tiff
TGT_COMB=results/preliminaries/NSW-extant-xref-target.tiff

gdalinfo $SRC_PRE | grep -E "Size is|Pixel Size|NoData"
gdalinfo $SCR_LUL | grep -E "Size is|Pixel Size|NoData"

gdalinfo $SRC_PRE | awk '/Upper Left|Lower Right/'
# Crop and align B to A

 gdalwarp \
  -t_srs "$(gdalsrsinfo -o wkt $SRC_PRE)" \
  -tr $(gdalinfo $SRC_PRE | awk -F'[(), ]+' '/Pixel Size/ {print $4,$5}') \
  -te $(gdalinfo $SRC_PRE | awk '
      /Upper Left/ {gsub(/[(),]/,""); xmin=$3; ymax=$4}
      /Lower Right/ {gsub(/[(),]/,""); xmax=$3; ymin=$4}
      END{print xmin,ymin,xmax,ymax}
    ') \
  -tap \
  -r near \
  -dstnodata 255 \
  $SCR_LUL $TGT_LUL


 gdalwarp \
  -t_srs "$(gdalsrsinfo -o wkt $SRC_PRE)" \
  -tr $(gdalinfo $SRC_PRE | awk -F'[(), ]+' '/Pixel Size/ {print $4,$5}') \
  -te $(gdalinfo $SRC_PRE | awk '
      /Upper Left/ {gsub(/[(),]/,""); xmin=$3; ymax=$4}
      /Lower Right/ {gsub(/[(),]/,""); xmax=$3; ymin=$4}
      END{print xmin,ymin,xmax,ymax}
    ') \
  -tap \
  -r near \
  -dstnodata 255 \
  $SRC_PRE $TGT_PRE

# gdal raster reproject \
#   --like $SRC_PRE \
#   --resampling near \
#   --input $SCR_LUL \
#   --output $TGT_LUL

# gdal_calc.py \
#   -A $TGT_PRE \
#   -B $TGT_LUL \
#   --outfile=$TGT_COMB \
#   --calc="where(A==255,255,where(B==255,A,B))" \
#   --NoDataValue=255

# gdal raster calc \
#   -i "A=$TGT_PRE" \
#   -i "B=$TGT_LUL" \
#   -o "$TGT_COMB" \
#   --calc "A == 255 ? 255 : (B == 255 ? A : B)" \
#   --overwrite