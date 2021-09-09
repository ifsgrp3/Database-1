CREATE DATABASE credentials;
\c credentials;
SET TIMEZONE='Singapore';

begin;
CREATE TABLE IF NOT EXISTS admins(
  admin_id int PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS login_credentials (
  nric char(9) PRIMARY KEY,
  hashed_password varchar NOT NULL,
  user_salt varchar,
  password_attempts int default 0,
  ble_serial_number varchar,
  account_status bit default '1',
  /** Boolean use 1, 0, or NULL**/
  account_role int,
  /** 1 for admin, 2 for cp, 3 for user**/
  admin_id int REFERENCES admins
  /*need to add account type as well for validation*/ 
);
CREATE SCHEMA accountlogs;
SET SEARCH_PATH to accountlogs;
CREATE TABLE IF NOT EXISTS account_logs (
  log_id serial PRIMARY KEY,
  user_nric char(9),
  date_time TIMESTAMPTZ DEFAULT Now(),
  admin_id varchar,
  action_made varchar
);
SET SEARCH_PATH to accountlogs,public;




/** Trigger for account status and password_attempts**/
CREATE OR REPLACE FUNCTION change_account_status() RETURNS TRIGGER
AS $$
    BEGIN
      IF (NEW.password_attempts > 10) THEN
        RAISE NOTICE 'User has exceed max login tries';  
      END IF;
      OLD.account_status := 0;
      RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER max_password_attempts
AFTER UPDATE OR INSERT ON login_credentials
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION change_account_status();

/** Trigger for invalid account, no such NRIC or no account status deactivated**/

CREATE OR REPLACE FUNCTION reject_account_change() RETURNS TRIGGER
AS $$
    BEGIN
      IF (OLD.account_status = '0') THEN
        RAISE EXCEPTION 'The account has been deactivated';  
      END IF;
      RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

/**cannot use before??**/
CREATE CONSTRAINT TRIGGER invalid_account_type
AFTER UPDATE ON login_credentials
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION reject_account_change();


/** Function for admin to add accounts **/
CREATE OR REPLACE PROCEDURE add_user(nric char(9), hashed_password varchar, user_salt varchar, ble_serial_number varchar,account_role int,admin_id int)
AS $$
  INSERT INTO login_credentials (nric, hashed_password, user_salt,ble_serial_number,account_role,admin_id) Values (nric, hashed_password, user_salt,ble_serial_number,account_role,admin_id);
$$ LANGUAGE sql;      


/** Function for admin to reset password attempts **/
CREATE OR REPLACE PROCEDURE reset_attempts(update_nric char(9))
AS $$
  UPDATE login_credentials
  SET password_attempts = 0
  WHERE nric = update_nric;
$$ LANGUAGE sql;

/** Function for admin to deactivate account **/
CREATE OR REPLACE PROCEDURE deactivate_account(update_nric char(9))
AS $$
  UPDATE login_credentials
  SET account_status = '0'
  WHERE nric = update_nric;
$$ LANGUAGE sql;

/** Function to add into account logs **/
CREATE OR REPLACE PROCEDURE add_account_logs(user_nric char(9), admin_id varchar,action_made varchar)
AS $$
  INSERT INTO account_logs ( user_nric,admin_id,action_made) Values (user_nric,admin_id,action_made);
$$ LANGUAGE sql; 

/** Trigger to add into account logs **/
CREATE OR REPLACE FUNCTION account_log_func() RETURNS TRIGGER AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
  INSERT INTO account_logs ( user_nric,admin_id,action_made) Values (NEW.nric,NEW.admin_id,'CREATE');
ELSEIF (TG_OP = 'DELETE') THEN
  INSERT INTO account_logs ( user_nric,admin_id,action_made) Values (OLD.nric,NEW.admin_id,'DELETE');
ELSIF (TG_OP = 'UPDATE') THEN
  INSERT INTO account_logs ( user_nric,admin_id,action_made) Values (NEW.nric,NEW.admin_id,'UPDATE');
END IF;
RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER account_log_trigger
AFTER INSERT OR DELETE OR UPDATE ON public.login_credentials
FOR EACH ROW EXECUTE FUNCTION account_log_func();
END;







