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

CREATE TABLE IF NOT EXISTS account_logs (
  log_id serial PRIMARY KEY,
  user_nric char(9),
  date_time TIMESTAMPTZ DEFAULT Now(),
  admin_id varchar,
  action_made varchar
);



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

/***********************************************************************************************************************************************************************
********************************************************************************Health Record Database*****************************************************************/

CREATE DATABASE healthrecords;
\c healthrecords;
SET TIMEZONE='Singapore';

begin;
CREATE TABLE IF NOT EXISTS
user_particulars (
  nric char(9) PRIMARY KEY, 
  first_name varchar NOT NULL, 
  last_name varchar NOT NULL, 
  date_of_birth date, 
  age int, 
  gender bit, 
  /** 1 for female, 0 for male **/
  race varchar,
  /** chinese, malay, indian, others **/
  contact_number varchar
);

CREATE TABLE IF NOT EXISTS 
user_address (
  nric char(9) PRIMARY KEY, 
  street_name varchar, 
  unit_number varchar, 
  zip_code varchar, 
  area varchar,
   /** north, south, east, west, central **/
  FOREIGN KEY (nric) references user_particulars (nric) 
);

CREATE TABLE IF NOT EXISTS 
vaccination_results (
  nric char(9) PRIMARY KEY, 
  vaccination_status int default 0,
  /** 0 for not vaccinated, 1 for partially vaccinated, 2 for fully vaccianted **/ 
  vaccine_type varchar,
  /** pfizer, moderna, sinovac **/ 
  vaccination_centre_location varchar, 
  first_dose_date date, 
  second_dose_date date, 
  vaccination_certificate_id SERIAL
);

CREATE TABLE IF NOT EXISTS
covid19_test_results (
  nric char(9) PRIMARY KEY,
  covid19_test_type bit,  
  /** 0 for ART, 1 for PCR **/
  test_result bit,
  /** 1 for positive, 0 for negative **/
  test_date date default CURRENT_DATE, 
  test_id SERIAL
  
);

CREATE TABLE IF NOT EXISTS 
health_declaration (
  nric char(9) PRIMARY KEY, 
  covid_symptoms bit, 
  /** 1 for symptoms visible, 0 for symptoms not visible **/
  temperature float, 
  declaration_date date default CURRENT_DATE,
  health_declaration_id SERIAL
);

/** 1. add_user_particulars: **/
CREATE OR REPLACE PROCEDURE add_user_particulars(nric char(9), first_name varchar, last_name varchar, date_of_birth date, age int, gender bit, race varchar, contact_number varchar)
AS $$ 
  BEGIN
    INSERT INTO user_particulars VALUES (nric, first_name, last_name, date_of_birth, age, gender, race, contact_number);
  END;
$$ LANGUAGE plpgsql;

/** 2. update_contact_number **/
CREATE OR REPLACE PROCEDURE update_contact_number(nric char(9), new_contact_number varchar)
AS $$
  BEGIN
    UPDATE user_particulars
    SET contact_number = new_contact_number
    WHERE nric = nric;
  END;
$$ LANGUAGE plpgsql;


/** 3. add_user_address **/
CREATE OR REPLACE PROCEDURE add_user_address(nric char(9), street_name varchar, unit_number varchar, zip_code varchar, area varchar)
AS $$
  BEGIN
    INSERT INTO user_address VALUES (nric, street_name, unit_number, zip_code, area);
  END;
$$ LANGUAGE plpgsql;

/** 4. update_address **/
CREATE OR REPLACE PROCEDURE update_address(nric char(9), new_street_name varchar, new_unit_number varchar, new_zip_code varchar, new_area varchar)
AS $$ 
  BEGIN
    UPDATE user_address
    SET 
      street_name = new_street_name, 
      unit_number = new_unit_number, 
      zip_code = new_zip_code, 
      area = new_area
    WHERE nric = nric;
  END;
$$ LANGUAGE plpgsql;

/** 5. add_vaccination_results **/
CREATE OR REPLACE PROCEDURE add_vaccination_results(nric char(9), vaccination_status int, vaccine_type varchar, vaccination_centre_location varchar, first_dose_date date, second_dose_date date)
AS $$
  DECLARE 
    curr_vaccination_certificate_id INT;
  BEGIN 
    INSERT INTO vaccination_results(nric, vaccination_status, vaccine_type, vaccination_centre_location, first_dose_date, second_dose_date) VALUES (nric, vaccination_status, vaccine_type, vaccination_centre_location, first_dose_date, second_dose_date) 
    RETURNING vaccination_certificate_id INTO curr_vaccination_certificate_id;
  END;
$$ LANGUAGE plpgsql;

/** 6. add_covid19_result **/
CREATE OR REPLACE PROCEDURE add_covid19_results(nric char(9), covid19_test_type bit,  test_result bit, test_date date) 
AS $$ 
  DECLARE
    curr_test_id INT;
  BEGIN 
    INSERT INTO covid19_test_results(nric, covid19_test_type, test_result, test_date) VALUES (nric,covid19_test_type, test_result, test_date) 
    RETURNING test_id INTO curr_test_id;
  END;
$$ LANGUAGE plpgsql;

/** 7. add_health_declaration **/
CREATE OR REPLACE PROCEDURE add_health_declaration(nric char(9), declaration_date date, covid_symptoms bit, temperature float)
AS $$ 
  DECLARE 
    curr_health_declaration_id INT;
  BEGIN
    INSERT INTO health_declaration (nric, declaration_date, covid_symptoms, temperature) VALUES (nric, declaration_date, covid_symptoms, temperature)
    RETURNING health_declaration INTO curr_health_declaration_id;
  END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS record_logs (
  user_nric char(9) PRIMARY KEY,
  date_time TIMESTAMPTZ DEFAULT Now(),/**e.g 2017-03-18 09:41:26.208497+07 **/
  table_affected varchar,
  action_made varchar
);
/** Function to add into record logs **/
CREATE OR REPLACE PROCEDURE add_record_logs(user_nric char(9),table_affected varchar,action_made varchar)
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
