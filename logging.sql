CREATE TABLE IF NOT EXISTS account_logs (
  user_nric varchar PRIMARY KEY,
  mod_date date,
  mod_time time,
  admin_id varchar,
  action_made varchar,
);

CREATE TABLE IF NOT EXISTS record_logs (
  user_nric varchar PRIMARY KEY,
  mod_date date,
  mod_time time,
  table_affected varchar,
  action_made varchar,
);
