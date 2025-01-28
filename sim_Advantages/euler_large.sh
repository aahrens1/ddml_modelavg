#!/bin/sh
module load gcc/8.2.0 python/3.9.9 stata/16

# N=99150
#Seed="3132 2465 982 9402 4220 9135 9471 7116 8384 9068 1018 6144 136 1478 4369 3300 2269 9957 1332 1251 4531 48109 38766 25777 94988 77033"
#for val in $Seed; do
#sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=1000 --wrap="stata-se -b do sim_Adv $val 9915 ols 10 2 large"
#sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=1000 --wrap="stata-se -b do sim_Adv $val 9915 gradboost 10 2 large"
#done

# N=99150
Seed="531 4305 746 3253 172 1678 3975 65 3466 7992"
for val in $Seed; do
sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=1000 --wrap="stata-se -b do sim_Adv $val 9915 ols 10 2 large"
sbatch -n 1 --time=5-0 -e error.txt -o output.txt --mem-per-cpu=1000 --wrap="stata-se -b do sim_Adv $val 9915 gradboost 10 2 large"
done