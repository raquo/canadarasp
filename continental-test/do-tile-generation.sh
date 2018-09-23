#!/bin/bash

# Usage:
# ./do-tile-generation.sh $YEAR $MONTH $DAY $HOUR
# where $YEAR $MONTH $DAY are forecast date (UTC) $HOUR is 00, 06, 12 or 18 forecast hour (UTC)
# outputs tiles to tiles/lon1:lon2:lat1:lat2/

# Environmental options
#  NOCLIP  - don't clip terrain
#  NOFIX   - don't fix labels on TGL_120 and TGL_40
#  NOTILES - don't generate tiles/ output

echo "$0 $@"
echo "Starting TILE GENERATION at `date`"
export GRIB2TABLE=/home/ubuntu/continental-test/grib2tables
WGRIB2=wgrib2
PARALLELSUB=15 # for fixing of file names which doesn't use any internal parallelization of wgrib2
PARALLELTILE=15 # WGRIB2 goes nuts if you set this to more than 1 and don't set OMP_NUM_THREADS=1
PARALLELNCL=14
NOCLIP=1 # we don't need to clip... not used for windgrams
START_PATH=`pwd`
YEAR=${1:-$YEAR}
MONTH=${2:-$MONTH}
DAY=${3:-$DAY}
HOUR=${4:-$HOUR}
source ./model-parameters.sh $MODEL
echo Generating tiles from $YEAR-$MONTH-$DAY for ${#TIMES[@]} hours
export OMP_NUM_THREADS=1
if [ -z $NOFIX ] ; then
    echo FIXING files starts at `date`
    # fix level info for TGL files
    FILES=( $OUTPUTDIR/*TGL_120*.grib2 )
    echo "Fixing TGL_120 level on ${#FILES[@]} files"
    rm -f /mnt/paralleljobs
    for F in ${FILES[@]}
    do
	echo $WGRIB2 -v0 $F -set_grib_type c2 -set_lev \"120 m above ground\" -grib_out $F.fixed >> /mnt/paralleljobs
    done
    parallel --gnu -j $PARALLELSUB < /mnt/paralleljobs
    for F in ${FILES[@]}
    do
	mv $F.fixed $F
    done
    FILES=( $OUTPUTDIR/*TGL_40*.grib2 )
    echo "Fixing TGL_40 levels on ${#FILES[@]} files"
    rm -f /mnt/paralleljobs
    for F in ${FILES[@]}
    do
	echo $WGRIB2 $F -v0 -set_grib_type c2 -set_lev \"40 m above ground\" -grib_out $F.fixed >> /mnt/paralleljobs
    done
    parallel --gnu -j $PARALLELSUB < /mnt/paralleljobs
    for F in ${FILES[@]}
    do
	mv $F.fixed $F
    done
    echo FIXING files ends at `date`
fi
export -n OMP_NUM_THREADS
# determine which hours we will process and plot

for Y in ${YVALS[@]}
do
    for X in ${XVALS[@]}
    do
	DIRECTORYNAME=$TILEDIR/$X:$((X+XSTEP)):$Y:$((Y+YSTEP))
	mkdir -p $DIRECTORYNAME
    done
done

if [ -z $NOTILES ]; then
   # The tiles will be generated actually 10% larger than required in the east west direction, and then we will clip by 10%.  This lets us ignore the rotated grid for all the lat/lons we care about.
   echo "Generating commands starts at `date`" # This actually takes two minutes or so!
   rm -f /mnt/parallel-jobs
   rm -f /mnt/args
   ARGSFILES=""
   for H in ${TIMES[*]}
   do
      echo ./generate-tile-commands.lisp $YEAR $MONTH $DAY $HOUR $H /mnt/args$H >> /mnt/parallel-jobs
      ARGSFILE+="/mnt/args$H "
   done
   parallel --gnu -n 1 -j $PARALLELTILE < /mnt/parallel-jobs
   cat $ARGSFILE > /mnt/args
   echo "Done generating commands at `date`"
   echo "Generating grib tiles starts at `date`"
   export OMP_NUM_THREADS=1
   time parallel --gnu -n 1 -j $PARALLELTILE < /mnt/args
   export -n OMP_NUM_THREADS
   echo "Done generating grib tiles at `date`"
fi
rm -f /mnt/args
rm -f /mnt/parallel-jobs
echo "Starting concatenating files for each hour at `date`"
if [ -z $NOTILES ]; then
    for H in ${TIMES[*]}
    do
	for Y in ${YVALS[@]}
	do
	    for X in ${XVALS[@]}
	    do
		DIRECTORYNAME=$TILEDIR/$X:$((X+XSTEP)):$Y:$((Y+YSTEP))
		P=$DIRECTORYNAME
		OUTPUT=$DIRECTORYNAME/$MODEL"_"$YEAR-$MONTH-$DAY-run$HOUR"_P0"$H".grib2"
		CATLIST="$P/*VGRD_ISBL_*_P0$H$TAIL $P/*UGRD_ISBL_*_P0$H$TAIL $P/*DEPR_ISBL_*_P0$H$TAIL $P/*TMP_ISBL_*_P0$H$TAIL $P/*HGT_SFC*_P0$H$TAIL $P/*HGT_ISBL*_P0$H$TAIL $P/*TGL*_P0$H$TAIL $P/*PRATE*_P0$H$TAIL $P/*TCDC_SFC*_P0$H$TAIL $P/*PRMSL*_P0$H$TAIL  $P/*HTFL*_P0$H$TAIL"
		cat $CATLIST > $OUTPUT
		# $P/*CAPE*_P0$H-00.grib2
		# $P/*VVEL*_P0$H-00.grib2
		rm $CATLIST
	    done
	done
    done
fi
echo "Done concatenating files for each hour at `date`"
echo "Done TILE GENERATION at `date`"

