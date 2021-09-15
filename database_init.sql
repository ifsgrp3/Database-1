CREATE DATABASE credentials;
\c credentials;
SET TIMEZONE='Singapore';
begin;
CREATE TABLE IF NOT EXISTS admins(
  admin_id int PRIMARY KEY
);
insert into admins(admin_id) values (0),(1),(2),(3),(4);
CREATE TABLE IF NOT EXISTS login_credentials (
  nric char(9) PRIMARY KEY,
  hashed_password varchar(64) NOT NULL,
  user_salt varchar(32), 
  password_attempts int default 0,
  ble_serial_number varchar(64), 
  account_status bit default '1',
  /** Boolean use 1, 0, or NULL**/
  account_role int,
  /** 1 for admin, 2 for cp, 3 for user**/
  admin_id int REFERENCES admins 
);
/**CREATE SCHEMA accountlogs;
SET SEARCH_PATH to accountlogs;**/
CREATE TABLE IF NOT EXISTS account_logs (
  log_id serial PRIMARY KEY,
  user_nric char(9),
  date_time TIMESTAMPTZ DEFAULT Now(),
  admin_id varchar,
  action_made varchar
);
/**SET SEARCH_PATH to accountlogs,public;**/


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

CREATE DATABASE healthrecords;
\c healthrecords;
SET TIMEZONE='Singapore';

begin;
CREATE TABLE IF NOT EXISTS
user_particulars (
  nric char PRIMARY KEY, 
  first_name varchar NOT NULL, 
  last_name varchar NOT NULL, 
  date_of_birth date, 
  age int, 
  gender bit, 
  /** 1 for female, 0 for male **/
  race varchar,
  /** chinese, malay, indian, others **/
  contact_number varchar, 
  user_role int
  /** 1 for admin, 2 for cp, 3 for public **/
);

CREATE TABLE IF NOT EXISTS 
user_address (
  nric char PRIMARY KEY, 
  street_name varchar, 
  unit_number varchar, 
  zip_code varchar, 
  area varchar,
   /** north, south, east, west, central **/
  FOREIGN KEY nric references user_particulars (nric) 
);

CREATE TABLE IF NOT EXISTS 
vaccination_results (
  nric char PRIMARY KEY, 
  vaccination_status int default 0,
  /** 0 for not vaccinated, 1 for partially vaccinated, 2 for fully vaccianted **/ 
  vaccine_type varchar,
  /** pfizer, moderna, sinovac **/ 
  vaccination_centre_location varchar, 
  first_dose_date date, 
  second_dose_date date, 
  vaccination_certificate_id varchar
);

CREATE TABLE IF NOT EXISTS
covid19_test_results (
  nric char PRIMARY KEY, 
  test_result bit,
  /** 1 for positive, 0 for negative **/
  test_date date, 
  test_id varchar, 
  covid19_test_type bit
  /** 0 for ART, 1 for PCR **/
);

CREATE TABLE IF NOT EXISTS 
health_declaration (
  nric char PRIMARY KEY, 
  declaration_date date, 
  covid_symptoms bit, 
  /** 1 for symptoms visible, 0 for symptoms not visible **/
  temperature float, 
  health_declaration_id varchar
);



CREATE OR REPLACE PROCEDURE add_user_particulars(nric char, first_name varchar, last_name varchar, date_of_birth date, age int, gender bit, race varchar, contact_number varchar, user_role int)
AS $$
BEGIN
  INSERT INTO user_particulars (nric, first_name, last_name, date_of_birth, age) VALUES (nric,, first_name, last_name, date_of_birth, age);
  IF user_role = 'admin' then 
  INSERT INTO user_particulars(user_role) VALUES 1
  E
  
END;
$$ LANGUAGE sql; 

CREATE TABLE IF NOT EXISTS record_logs (
  user_nric char PRIMARY KEY,
  date_time TIMESTAMPTZ DEFAULT Now(),/**e.g 2017-03-18 09:41:26.208497+07 **/
  table_affected varchar,
  action_made varchar
);
/** Function to add into record logs **/
CREATE OR REPLACE PROCEDURE add_record_logs(user_nric char,table_affected varchar,action_made varchar)
AS $$
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (user_nric,table_affected,action_made);
$$ LANGUAGE sql; 

/** Trigger to add into record logs **/
/**user_particulars**/
CREATE OR REPLACE FUNCTION record_log_func1() RETURNS TRIGGER AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (NEW.nric, 'user_particulars', 'CREATE');
  RETURN NEW;
ELSEIF (TG_OP = 'DELETE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'user_particulars', 'DELETE');
  RETURN OLD;
ELSIF (TG_OP = 'UPDATE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'user_particulars', 'UPDATE');
  RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER record_log_trigger1
AFTER INSERT OR DELETE OR UPDATE ON public.user_particulars
FOR EACH ROW EXECUTE FUNCTION record_log_func1();

/**user_address**/
CREATE OR REPLACE FUNCTION record_log_func2() RETURNS TRIGGER AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (NEW.nric, 'user_address', 'CREATE');
  RETURN NEW;
ELSEIF (TG_OP = 'DELETE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'user_address', 'DELETE');
  RETURN OLD;
ELSIF (TG_OP = 'UPDATE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'user_address', 'UPDATE');
  RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER record_log_trigger2
AFTER INSERT OR DELETE OR UPDATE ON public.user_address
FOR EACH ROW EXECUTE FUNCTION record_log_func2();

/**vaccination_results**/
CREATE OR REPLACE FUNCTION record_log_func3() RETURNS TRIGGER AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (NEW.nric, 'vaccination_results', 'CREATE');
  RETURN NEW;
ELSEIF (TG_OP = 'DELETE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'vaccination_results', 'DELETE');
  RETURN OLD;
ELSIF (TG_OP = 'UPDATE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'vaccination_results', 'UPDATE');
  RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER record_log_trigger3
AFTER INSERT OR DELETE OR UPDATE ON public.vaccination_results
FOR EACH ROW EXECUTE FUNCTION record_log_func3();

/**covid19_test_results**/
CREATE OR REPLACE FUNCTION record_log_func4() RETURNS TRIGGER AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (NEW.nric, 'covid19_test_results', 'CREATE');
  RETURN NEW;
ELSEIF (TG_OP = 'DELETE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'covid19_test_results', 'DELETE');
  RETURN OLD;
ELSIF (TG_OP = 'UPDATE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'covid19_test_results', 'UPDATE');
  RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER record_log_trigger4
AFTER INSERT OR DELETE OR UPDATE ON public.covid19_test_results
FOR EACH ROW EXECUTE FUNCTION record_log_func4();

/**health_declaration**/
CREATE OR REPLACE FUNCTION record_log_func5() RETURNS TRIGGER AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (NEW.nric, 'health_declaration', 'CREATE');
  RETURN NEW;
ELSEIF (TG_OP = 'DELETE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'health_declaration', 'DELETE');
  RETURN OLD;
ELSIF (TG_OP = 'UPDATE') THEN
  INSERT INTO  record_logs ( user_nric,table_affected,action_made) Values (OLD.nric, 'health_declaration', 'UPDATE');
  RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER record_log_trigger5
AFTER INSERT OR DELETE OR UPDATE ON public.health_declaration
FOR EACH ROW EXECUTE FUNCTION record_log_func5();
END;
