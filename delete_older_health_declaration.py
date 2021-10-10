import psycopg2
import psycopg2 as pg
import sys
from psycopg2 import OperationalError, errorcodes, errors

def show_psycopg2_exception(err):
    # get details about the exception
    err_type, err_obj, traceback = sys.exc_info()
    # get the line number when exception occured
    line_n = traceback.tb_lineno
    # print the connect() error
    print("\npsycopg2 ERROR:", err, "on line number:", line_n)
    print("psycopg2 traceback:", traceback, "-- type:", err_type)
    # psycopg2 extensions.Diagnostics object attribute
    print("\nextensions.Diagnostics:", err.diag)
    # print the pgcode and pgerror exceptions
    print("pgerror:", err.pgerror)
    print("pgcode:", err.pgcode, "\n")

connection = pg.connect("host=group3-1-i.comp.nus.edu.sg dbname=healthrecords "
                        "port= 5435 user=postgres password=mysecretpassword")
connection.autocommit = True

if connection != None:

    try:
        cursor = connection.cursor();
        # Dropping table iris if exists
        cursor.execute("CALL delete_older_health_declaration();")

        #sql = '''CALL delete_older_health_declaration();'''

        #cursor.execute(sql);

        # Closing the cursor & connection
        cursor.close()
        connection.close()
    except OperationalError as err:
        # pass exception to function
        show_psycopg2_exception(err)
        # set the connection to 'None' in case of error
        conn = None
