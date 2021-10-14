import sys
import glob
import os

list_of_files = glob.glob('/home/sadm/IFS/db_docker/logs/*') # * means all if need specific format then *.csv
latest_file = max(list_of_files, key=os.path.getctime)
list_of_files = ["logs/10-12_log0000.log","logs/10-13_log0000.log","logs/10-14_log0000.log"]
sys.stdout = open("load_logs.data", "w")
for name in list_of_files:
    with open(name) as f:

        for line in f:
            if line is not None:
                log_time = line.split('UTC')[0]
                activity_done = line.split('UTC')[1]
                print(log_time + ";" + activity_done)
                #print("CALL add_logs_data('" + log_time + "', '" + activity_done + "');")
sys.stdout.close()
