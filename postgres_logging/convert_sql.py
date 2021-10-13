import sys
import glob
import os

list_of_files = glob.glob('/home/sadm/IFS/db_docker/logs/*') # * means all if need specific format then *.csv
latest_file = max(list_of_files, key=os.path.getctime)


with open(latest_file) as f:
    sys.stdout = open("load_user_address.sql", "w")
    for line in f:
        log_time = line.split('UTC')[0]
        activity_done = line.split('UTC')[1]
        # print("Log Time: " + log_time)
        # print("Activity: " + activity_done)

        print("CALL add_logs_data('" + log_time + "', '" + activity_done + "');")
    sys.stdout.close()
