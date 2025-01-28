#!/bin/sh
module load gcc/8.2.0 python/3.9.9 stata/16

rm error.txt
rm output.txt

# last started on June 24, 2024
# N < 9915
Seed="408919 205243 427782 687491 624129 341297 565407 398490 538213 541858 82612 56555"
Folds="2 10"
for val in $Seed; do
	for f in $Folds; do
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 200 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 200 gradboost 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 400 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 400 gradboost 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 800 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 800 gradboost 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 1600 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 1600 gradboost 1 $f small"
  	done
done

## we only need K=5 for timings
Seed="408919"
Folds="5"
for val in $Seed; do
	for f in $Folds; do
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 200 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 200 gradboost 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 400 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 400 gradboost 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 800 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 800 gradboost 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 1600 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=500 --wrap="stata-se -b do sim_Adv $val 1600 gradboost 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=750 --wrap="stata-se -b do sim_Adv $val 9915 ols 1 $f small"
  	sbatch -n 1 --time=1-0 -e error.txt -o output.txt --mem-per-cpu=750 --wrap="stata-se -b do sim_Adv $val 9915 gradboost 1 $f small"
  	done
done

## N == 9915
Seed="408919 205243 427782 687491 624129 341297 565407 398490 538213 541858 38718 39051 13127 24151 71186 13525 37253 84666 75606 79051"
for val in $Seed; do
	sbatch -n 1 --time=2-0 -e error.txt -o output.txt --mem-per-cpu=750 --wrap="stata-se -b do sim_Adv $val 9915 ols 1 2 small"
	sbatch -n 1 --time=2-0 -e error.txt -o output.txt --mem-per-cpu=750 --wrap="stata-se -b do sim_Adv $val 9915 gradboost 1 2 small"
	sbatch -n 1 --time=3-0 -e error.txt -o output.txt --mem-per-cpu=750 --wrap="stata-se -b do sim_Adv $val 9915 ols 1 10 small"
	sbatch -n 1 --time=3-0 -e error.txt -o output.txt --mem-per-cpu=750 --wrap="stata-se -b do sim_Adv $val 9915 gradboost 1 10 small"
done