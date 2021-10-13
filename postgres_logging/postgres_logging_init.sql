CREATE TABLE IF NOT EXISTS 
logs_data (
  log_time varchar, 
  activity varchar
);

CREATE OR REPLACE PROCEDURE add_logs_data(log_time varchar, activity varchar)
AS $$
  BEGIN
    INSERT INTO logs_data VALUES (log_time, activity);
  END;
$$ LANGUAGE plpgsql;

