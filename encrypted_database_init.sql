CREATE DATABASE credentials_encrypted;
\c credentials_encrypted;
SET TIMEZONE='Singapore';
CREATE EXTENSION pgcrypto;
begin;



CREATE TABLE IF NOT EXISTS login_credentials (
  nric char(9) PRIMARY KEY,
  hashed_password varchar NOT NULL, /**encrypted**/
  user_salt varchar, /**encrypted**/
  password_attempts varchar default '0',
  ble_serial_number varchar, /**encrypted**/
  account_status varchar default '1',
  /** Boolean use 1, 0, or NULL**/
  account_role varchar /**encrypted**/
  /** 1 for admin, 2 for cp, 3 for user**/
);

CREATE TABLE IF NOT EXISTS account_logs (
  log_id serial PRIMARY KEY,
  user_nric char(9),
  date_time TIMESTAMPTZ DEFAULT Now(),
  action_made varchar
);

CREATE TABLE IF NOT EXISTS online_users(
	nric char(9) references login_credentials (nric),
	iv varchar
);

/** Function to add online users **/
CREATE OR REPLACE PROCEDURE add_online_user(new_nric char(9),new_iv varchar)
AS $$
  INSERT INTO  online_users (nric,iv) VALUES (new_nric,new_iv);
$$ LANGUAGE sql;


/** Function to delete online users **/
CREATE OR REPLACE PROCEDURE delete_online_user(new_nric char(9))
AS $$
  DELETE FROM online_users
  WHERE online_users.nric = new_nric;
$$ LANGUAGE sql;

/** Trigger for account status and password_attempts**/
CREATE OR REPLACE FUNCTION change_account_status() RETURNS TRIGGER
AS $$
    BEGIN
      IF (NEW.password_attempts > '9') THEN
        RAISE NOTICE 'User has exceed max login tries';  
      END IF;
      OLD.account_status := pgp_sym_encrypt('0','Y61PAgMBAAE');
      RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER max_password_attempts
AFTER UPDATE OR INSERT ON login_credentials
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION change_account_status();

/** Function for admin to add accounts **/
CREATE OR REPLACE PROCEDURE add_user(nric char(9), hashed_password varchar, user_salt varchar, ble_serial_number varchar, account_role varchar)
AS $$
  BEGIN
    INSERT INTO login_credentials (nric, hashed_password, user_salt, ble_serial_number,account_role) VALUES 
      (nric, hashed_password,  
	    pgp_sym_encrypt(user_salt, 'Y61PAgMBAAE'),
 	    pgp_sym_encrypt(ble_serial_number, 'Y61PAgMBAAE'),
 	    pgp_sym_encrypt(account_role, 'Y61PAgMBAAE'));
  END;
$$ LANGUAGE plpgsql;




/** Function for admin to deactivate account **/
CREATE OR REPLACE PROCEDURE deactivate_account(update_nric char(9))
AS $$
  UPDATE login_credentials
  SET account_status = pgp_sym_encrypt('0','Y61PAgMBAAE')
  WHERE nric = update_nric;
$$ LANGUAGE sql;

 /**Update user password**/
CREATE OR REPLACE PROCEDURE update_user_password(update_nric char(9), new_hashed_password varchar )
AS $$
  UPDATE login_credentials
  SET hashed_password = pgp_sym_encrypt(new_hashed_password,'Y61PAgMBAAE')
  WHERE nric = update_nric; 
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE update_user_ble(update_nric char(9), new_ble_serial_number varchar )
AS $$
  UPDATE login_credentials
  SET ble_serial_number = pgp_sym_encrypt(new_ble_serial_number ,'Y61PAgMBAAE')
  WHERE nric = update_nric; 
 
$$ LANGUAGE sql;

/** Update user role **/
CREATE OR REPLACE PROCEDURE update_user_role(update_nric char(9), new_account_role varchar )
AS $$
  UPDATE login_credentials
  SET account_role = pgp_sym_encrypt(new_account_role,'Y61PAgMBAAE')
  WHERE nric = update_nric;
$$ LANGUAGE sql;

/** Function to add into account logs **/
CREATE OR REPLACE PROCEDURE add_account_logs(user_nric char(9),action_made varchar)
AS $$
  INSERT INTO account_logs ( user_nric,action_made) Values (user_nric,action_made);
$$ LANGUAGE sql; 

/** Trigger to add into account logs **/
CREATE OR REPLACE FUNCTION account_log_func() RETURNS TRIGGER AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
  INSERT INTO account_logs ( user_nric,action_made) Values (NEW.nric,'CREATE');
ELSEIF (TG_OP = 'DELETE') THEN
  INSERT INTO account_logs ( user_nric,action_made) Values (OLD.nric,'DELETE');
ELSIF (TG_OP = 'UPDATE') THEN
  INSERT INTO account_logs ( user_nric,action_made) Values (NEW.nric,'UPDATE');
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

CREATE DATABASE healthrecord_encrypted;
\c healthrecord_encrypted;
SET TIMEZONE='Singapore';
CREATE EXTENSION pgcrypto;

begin;
CREATE TABLE IF NOT EXISTS
user_particulars (
  nric char(9) PRIMARY KEY, 
  first_name varchar NOT NULL, 
  last_name varchar NOT NULL, 
  date_of_birth varchar, 
  age varchar, 
  gender varchar, 
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
  FOREIGN KEY (nric) references user_particulars (nric) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS 
vaccination_results (
  nric char(9) PRIMARY KEY, 
  vaccination_status varchar,
  /** 0 for not vaccinated, 1 for partially vaccinated, 2 for fully vaccianted **/ 
  vaccine_type varchar,
  /** pfizer, moderna, sinovac **/ 
  vaccination_centre_location varchar, 
  first_dose_date varchar , 
  second_dose_date varchar, 
  vaccination_certificate_id SERIAL, 
  FOREIGN KEY (nric) references user_particulars (nric) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS
covid19_test_results (
  nric char(9) ,
  covid19_test_type varchar,  
  /** 0 for ART, 1 for PCR **/
  test_result varchar,
  /** 1 for positive, 0 for negative **/
  test_date varchar default CURRENT_DATE, 
  test_id SERIAL PRIMARY KEY,
  FOREIGN KEY (nric) references user_particulars (nric) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS 
health_declaration (
  nric char(9), 
  covid_symptoms varchar, 
  /** 1 for symptoms visible, 0 for symptoms not visible **/
  temperature varchar, 
  declaration_date varchar default CURRENT_TIMESTAMP,
  health_declaration_id SERIAL PRIMARY KEY,
  FOREIGN KEY (nric) references user_particulars (nric) ON DELETE CASCADE
);



/** 1. add_user_particulars: **/
CREATE OR REPLACE PROCEDURE add_user_particulars(nric char(9), first_name varchar, last_name varchar, date_of_birth varchar, age varchar, gender varchar, race varchar, contact_number varchar)
AS $$ 
  BEGIN
    INSERT INTO user_particulars VALUES
      (nric, 
      pgp_sym_encrypt(first_name, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(last_name, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(date_of_birth, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(age, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(gender, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(race, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(contact_number, 'Y61PAgMBAAE'));
  END;
$$ LANGUAGE plpgsql;

/** 2. update_user_first_last_name **/
CREATE OR REPLACE PROCEDURE update_user_first_last_name(curr_nric char(9), new_last_name varchar, new_first_name varchar)
AS $$
  BEGIN 
    UPDATE user_particulars SET (last_name, first_name) = (
      pgp_sym_encrypt(new_last_name, 'Y61PAgMBAAE'),
      pgp_sym_encrypt(new_first_name, 'Y61PAgMBAAE')
    ) WHERE nric = curr_nric;
  END;
$$ LANGUAGE plpgsql; 

/** 3. update_contact_number **/
CREATE OR REPLACE PROCEDURE update_contact_number(curr_nric char(9), new_contact_number varchar)
AS $$
  BEGIN
    UPDATE user_particulars SET contact_number = (
      pgp_sym_encrypt(new_contact_number, 'Y61PAgMBAAE')
    ) WHERE nric = curr_nric;
  END;
$$ LANGUAGE plpgsql;

/** 4. remove_user_particulars **/
CREATE OR REPLACE PROCEDURE remove_user_particulars(curr_nric char(9))
AS $$ 
  BEGIN 
    DELETE FROM user_particulars where nric = curr_nric;
  END;
$$ LANGUAGE plpgsql;

/** 5. add_user_address **/
CREATE OR REPLACE PROCEDURE add_user_address(nric char(9), street_name varchar, unit_number varchar, zip_code varchar, area varchar)
AS $$
  BEGIN
    INSERT INTO user_address(nric, street_name, unit_number, zip_code, area) VALUES
      (nric, 
      pgp_sym_encrypt(street_name, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(unit_number, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(zip_code, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(area, 'Y61PAgMBAAE'));
  END;
$$ LANGUAGE plpgsql;

/** 6. update_address **/
CREATE OR REPLACE PROCEDURE update_address(curr_nric char(9), new_street_name varchar, new_unit_number varchar, new_zip_code varchar, new_area varchar)
AS $$ 
  BEGIN
    UPDATE user_address SET (street_name, unit_number, zip_code, area) = (
      pgp_sym_encrypt(new_street_name, 'Y61PAgMBAAE'),
      pgp_sym_encrypt(new_unit_number, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(new_zip_code, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(new_area, 'Y61PAgMBAAE')
    ) WHERE nric = curr_nric;
  END;
$$ LANGUAGE plpgsql;

/** 7. add_vaccination_results **/
CREATE OR REPLACE PROCEDURE add_vaccination_results(nric char(9), vaccination_status varchar, vaccine_type varchar, vaccination_centre_location varchar, first_dose_date varchar, second_dose_date varchar)
AS $$
  DECLARE 
    curr_vaccination_certificate_id INT;
  BEGIN
    INSERT INTO vaccination_results (nric, vaccination_status, vaccine_type, vaccination_centre_location, first_dose_date, second_dose_date) VALUES (
      nric, 
      pgp_sym_encrypt(vaccination_status, 'Y61PAgMBAAE'),
      pgp_sym_encrypt(vaccine_type, 'Y61PAgMBAAE'),
      pgp_sym_encrypt(vaccination_centre_location, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(first_dose_date, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(second_dose_date, 'Y61PAgMBAAE')
    ) RETURNING vaccination_certificate_id INTO curr_vaccination_certificate_id;
  END;
$$ LANGUAGE plpgsql;

/** 8. update_vaccination_status_to_partially**/
CREATE OR REPLACE PROCEDURE update_vaccination_status_to_partially(curr_nric char(9))
AS $$
  BEGIN
    UPDATE vaccination_results SET vaccination_status = (
      pgp_sym_encrypt('1', 'Y61PAgMBAAE')
    ) WHERE nric = curr_nric;
  END;
$$ LANGUAGE plpgsql;

/** 9. update_vaccination_status_to_fully**/
CREATE OR REPLACE PROCEDURE update_vaccination_status_to_fully(curr_nric char(9))
AS $$
  BEGIN
     UPDATE vaccination_results SET vaccination_status = (
      pgp_sym_encrypt('2', 'Y61PAgMBAAE')
    ) WHERE nric = curr_nric;
  END;
$$ LANGUAGE plpgsql;


/** 10. add_covid19_result **/
CREATE OR REPLACE PROCEDURE add_covid19_results(nric char(9), covid19_test_type varchar,  test_result varchar) 
AS $$ 
  DECLARE
    curr_test_id INT;
  BEGIN
    INSERT INTO covid19_test_results(nric, covid19_test_type, test_result) VALUES (
      nric, 
      pgp_sym_encrypt(covid19_test_type, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(test_result, 'Y61PAgMBAAE')
    ) RETURNING test_id INTO curr_test_id;
  END;
$$ LANGUAGE plpgsql;

/** 11. add_health_declaration **/
CREATE OR REPLACE PROCEDURE add_health_declaration(nric char(9), covid_symptoms varchar, temperature varchar)
AS $$ 
  DECLARE 
    curr_health_declaration_id INT;
  BEGIN
    INSERT INTO health_declaration (nric, covid_symptoms, temperature) VALUES (
      nric,
      pgp_sym_encrypt(covid_symptoms, 'Y61PAgMBAAE'),
      pgp_sym_encrypt(temperature, 'Y61PAgMBAAE')
    ) RETURNING health_declaration_id INTO curr_health_declaration_id;
  END;
$$ LANGUAGE plpgsql;

/** 12. delete_older_health_declaration **/
CREATE OR REPLACE PROCEDURE delete_older_health_declaration()
AS $$
  BEGIN
    DELETE from health_declaration 
    WHERE declaration_date < NOW() - INTERVAL '30 DAY';
  END;
$$ LANGUAGE plpgsql;

/** 13. add_new_registration **/
CREATE OR REPLACE PROCEDURE 
add_new_registration(nric char(9), first_name varchar, last_name varchar, date_of_birth varchar, age varchar, gender varchar, race varchar, contact_number varchar, street_name varchar, unit_number varchar, zip_code varchar, area varchar, vaccination_status varchar, vaccine_type varchar, vaccination_centre_location varchar, first_dose_date varchar, second_dose_date varchar) 
AS $$
  DECLARE
    curr_vaccination_certificate_id INT;
  BEGIN
    INSERT INTO user_particulars (nric, first_name, last_name, date_of_birth, age, gender, race, contact_number) VALUES (
      nric,
      pgp_sym_encrypt(first_name, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(last_name, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(date_of_birth, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(age, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(gender, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(race, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(contact_number, 'Y61PAgMBAAE')
    );

    INSERT INTO user_address(nric, street_name, unit_number, zip_code, area) VALUES (
      nric, 
      pgp_sym_encrypt(street_name, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(unit_number, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(zip_code, 'Y61PAgMBAAE'), 
      pgp_sym_encrypt(area, 'Y61PAgMBAAE')
    );
  END;
$$ LANGUAGE plpgsql;


CREATE TABLE IF NOT EXISTS record_logs (
  record_id serial PRIMARY KEY,
  user_nric char(9),
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
