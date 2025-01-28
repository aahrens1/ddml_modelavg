#!/bin/sh
module load gcc/8.2.0 python/3.9.9 stata/16
Seed="53356 84685 36931 58248 26898 3928 923 8756 3702 232"
Models="1 2 3 4"
for m in $Models; do
for s in $Seed; do
sbatch -n 5 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=5000 --wrap="stata-se -b do GWG $s $m"
done
done