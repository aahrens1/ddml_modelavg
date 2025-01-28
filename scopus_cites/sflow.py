"""
Scriptflow for ddml simulations in R.

Adapt hpc parameters to your specifications. Then run via the command:
> scriptflow run [FLOW-NAME]
"""

import scriptflow as sf
import os
import itertools
import numpy as np

# set global scriptflow parameters
sf.init({
    "executors":{
        "slurm":{
            "maxsize": 200,
            "account": 'pi-chansen1',
            "user": 'wiemann',
            "partition": 'standard',
            "modules": 'R/4.2/4.2.2',
            "walltime": '3-23:59:59'
        } 
    },
    'debug': True,
    'notify': "thomas"
})

# sf.init({ # local runner
#     "executors":{
#         "local": {
#             "maxsize" : 1
#         } 
#     },
#     'debug':True
# })

# create directory to store results in
res_dir = "cv_res"
if not os.path.exists(res_dir):
    os.mkdir(res_dir)

# ==============================================================================

# Extract BERT features from parquet data

# Estimate coefficients
async def flow_data_prep():

    # Generate BERT features
    task_BERT = sf.Task(
        cmd = f"Rscript --vanilla Code/save_BERT_features.R",
        outputs = "Data/bert_data.csv",
        name = f"bert").set_retry(0).set_cpu(8).set_memory(4)
    
    # Generate Unigram
    task_unigram = sf.Task(
        cmd = f"Rscript --vanilla Code/generate_dfm.R",
        outputs = "Data/unigram.RData",
        name = f"unigram").set_retry(0).set_cpu(8).set_memory(4)
    
    # Schedule tasks (and wait for completion)
    await sf.bag(*[task_BERT, task_unigram])
    
    # Prepare final data
    task_final = sf.Task(
        cmd = f"Rscript --vanilla Code/data_prep.R",
        outputs = "Data/all_data_prepared.rds",
        name = f"data").set_retry(0).set_cpu(8).set_memory(4)
    
    # Schedule final task
    await task_final

# Estimate coefficients
async def flow_ddml_all():

    # hyperparameters
    counter_vec = [1, 2, 3, 4, 5]
    shortstack_vec = [0, 1]
    threshold_vec = [60, 70, 90]
    parameter_vec = [(counter, sstack, threshold) for (counter, sstack, threshold) in itertools.product(counter_vec, shortstack_vec, threshold_vec)]
    seed_vec = [61370, 45196, 35152, 84285, 97181, 50524, 53184, 30372, 79369, 65117, 88341, 53888,
                95052, 74075, 82190, 49675, 46856, 73250, 75094, 83719, 95454, 22019, 42236, 98414,
                44079, 47552, 55368, 21078, 93695, 54812]
    seed_vec_wlogs = [92553, 85320, 45845, 92183, 35194, 12380, 57375, 12264, 36919, 84691, 43066, 
                      86021, 11125, 84929, 29098, 52762, 66851, 18883, 20658, 57732, 80518, 41641, 
                      73673, 32687, 26356, 38754, 46966, 64451, 84911, 30854]

    # Generate tasks
    temp_dir = "temp"
    tasks = [
        sf.Task(
        cmd = f"Rscript --vanilla Code/run_ddml.R {parameter_vec[i][0]} {parameter_vec[i][1]} {seed_vec[i]} 0 {temp_dir} {parameter_vec[i][2]}",
        outputs = temp_dir + f"/fit1_sstack{parameter_vec[i][1]}_thres{parameter_vec[i][2]}_{parameter_vec[i][0]}.rds",
        name = f"bert1_l-{parameter_vec[i][1]}_{parameter_vec[i][2]}_{parameter_vec[i][0]}").set_retry(0).set_cpu(4).set_memory(8)
        for (i) in range(30)
    ]

    # Generate tasks
    temp_dir = "temp/wlogs"
    tasks_wlogs = [
        sf.Task(
        cmd = f"Rscript --vanilla Code/run_ddml.R {parameter_vec[i][0]} {parameter_vec[i][1]} {seed_vec_wlogs[i]} 1 {temp_dir} {parameter_vec[i][2]}",
        outputs = temp_dir + f"/fit1_sstack{parameter_vec[i][1]}_thres{parameter_vec[i][2]}_{parameter_vec[i][0]}.rds",
        name = f"bert1_l-{parameter_vec[i][1]}_{parameter_vec[i][2]}_{parameter_vec[i][0]}").set_retry(0).set_cpu(4).set_memory(8)
        for (i) in range(30)
    ]

    # Schedule tasks
    tasks_all = tasks #+ tasks_wlogs
    await sf.bag(*tasks_all)