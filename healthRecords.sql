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
  first_dose_date date , 
  second_dose_date date, 
  vaccination_certificate_id SERIAL, 
  FOREIGN KEY (nric) references user_particulars (nric) 
);

CREATE TABLE IF NOT EXISTS
covid19_test_results (
  nric char(9) PRIMARY KEY,
  covid19_test_type bit,  
  /** 0 for ART, 1 for PCR **/
  test_result bit,
  /** 1 for positive, 0 for negative **/
  test_date date default CURRENT_DATE, 
  test_id SERIAL,
  FOREIGN KEY (nric) references user_particulars (nric) 
);

CREATE TABLE IF NOT EXISTS 
health_declaration (
  nric char(9) PRIMARY KEY, 
  covid_symptoms bit, 
  /** 1 for symptoms visible, 0 for symptoms not visible **/
  temperature varchar, 
  declaration_date date default CURRENT_DATE,
  health_declaration_id SERIAL,
  FOREIGN KEY (nric) references user_particulars (nric) 
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
CREATE OR REPLACE PROCEDURE add_covid19_results(nric char(9), covid19_test_type bit,  test_result bit) 
AS $$ 
  DECLARE
    curr_test_id INT;
  BEGIN 
    INSERT INTO covid19_test_results(nric, covid19_test_type, test_result) VALUES (nric,covid19_test_type, test_result) 
    RETURNING test_id INTO curr_test_id;
  END;
$$ LANGUAGE plpgsql;

/** 7. add_health_declaration **/
CREATE OR REPLACE PROCEDURE add_health_declaration(nric char(9), covid_symptoms bit, temperature varchar)
AS $$ 
  DECLARE 
    curr_health_declaration_id INT;
  BEGIN
    INSERT INTO health_declaration (nric, covid_symptoms, temperature) VALUES (nric, covid_symptoms, temperature)
    RETURNING health_declaration_id INTO curr_health_declaration_id;
  END;
$$ LANGUAGE plpgsql;
