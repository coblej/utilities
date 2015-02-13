#!/bin/sh
scan_directory(){
	dir=$1
	mkdir -p $OUTDIR/$dir
	NOW=$(date +%F-%T)
	NOWOUT=$OUTDIR/$dir/$NOW.out
	NOWSRT=$OUTDIR/$dir/$NOW.srt
	sha256deep -rl $dir > $NOWOUT
	sort -k2 $NOWOUT > $NOWSRT
}

FILEDIR="/Users/coblej/Support/TUCASI_CIFS2/dpc-archive/Archived_NoAccess"
OUTDIR="/Users/coblej/Support/fixity/non_fedora"
cd $FILEDIR
for d in na_JWC na_VIC; do
	scan_directory $d
done
