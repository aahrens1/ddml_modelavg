#!/bin/sh
rm -rf log
rm -rf out
mkdir log
mkdir out
module load gcc/8.2.0 python/3.9.9 stata/16
Seed="64407 12731 62874 70097 55491 78148 61172 15230 55309 55090 9993 85753 36723 48340 49191 25663 81674 78321 23545 574 99242 5173 36384 33286 99792 64032 68204 35846 42757 26669 15429 42628 35125 11722 61964 60046 10506 92199 92229 96445"
Folds="2 10"
for val in $Seed; do
for f in $Folds; do
sbatch -n 1 --time=4-0 -e error.txt -o output.txt --mem-per-cpu=4000 --wrap="stata-se -b do simWZ $val 200 1 $f 5"
sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=4000 --wrap="stata-se -b do simWZ $val 400 1 $f 5"
sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=4000 --wrap="stata-se -b do simWZ $val 600 1 $f 5"
sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=4000 --wrap="stata-se -b do simWZ $val 800 1 $f 5"
sbatch -n 1 --time=6-0 -e error.txt -o output.txt --mem-per-cpu=4000 --wrap="stata-se -b do simWZ $val 1200 1 $f 5"
sbatch -n 1 --time=6-0 -e error.txt -o output.txt --mem-per-cpu=4000 --wrap="stata-se -b do simWZ $val 1600 1 $f 5"
done
done
Seed="64407 12731 62874 70097 55491"
for val in $Seed; do
for f in $Folds; do
sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=4000 --wrap="stata-se -b do simWZ $val 9915 0 $f 5"
done
done
