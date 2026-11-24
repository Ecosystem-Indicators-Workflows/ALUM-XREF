SRC_PRE=data/source-data/EIW-XREF/id24398849/NSWPCT-xref-target.tiff
SCR_LUL=
TGT_LUL=
TGT_COMB=

gdalinfo $SRC_PRE | grep -E "Size is|Pixel Size|NoData"
gdalinfo $SCR_LUL | grep -E "Size is|Pixel Size|NoData"

gdalwarp \
  -te $(gdalinfo $SRC_PRE | awk '
      /Upper Left/ {gsub(/[(),]/,""); xmin=$3; ymax=$4}
      /Lower Right/ {gsub(/[(),]/,""); xmax=$3; ymin=$4}
      END{print xmin,ymin,xmax,ymax}
    ') \
  -r near \
  -dstnodata 255 \
  $SRC_LUL $TRG_LUL
 
gdal_calc.py \
  -A $SRC_PRE \
  -B $TGT_LUL \
  --outfile=$TGT_COMB \
  --calc="where(A==255,255,where(B!=255,B,A))" \
  --NoDataValue=255