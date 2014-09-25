#!/bin/sh
FILEDIR="/Users/coblej/Support/TUCASI_CIFS2/dpc-archive/Archived_NoAccess"
OUTDIR="/Users/coblej/Support/fixity/non_fedora"
cd $FILEDIR
for d in na_JWC; do
	NOW=$(date +%F-%T)
	NOWOUT=$OUTDIR/$d/$NOW
	mkdir -p $OUTDIR/$d
	PREVOUT=$(ls ${OUTDIR}/${d}/*.srt)
	sha256deep -rl $d > $NOWOUT.out
	sort -k2 $NOWOUT.out > $NOWOUT.srt
	diff $PREVOUT $NOWOUT.srt > $NOWOUT.diff
done
