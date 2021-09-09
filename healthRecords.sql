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
  contact_number varchar, 
  user_role int
  /** 1 for admin, 2 for cp, 3 for public **/
);

CREATE TABLE IF NOT EXISTS 
user_address (
  nric char(9) PRIMARY KEY, 
  street_name varchar, 
  unit_number varchar, 
  zip_code varchar, 
  area varchar,
   /** north, south, east, west, central **/
  FOREIGN KEY nric references user_particulars (nric) 
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
  vaccination_certificate_id varchar
);

CREATE TABLE IF NOT EXISTS
covid19_test_results (
  nric char(9) PRIMARY KEY, 
  test_result bit,
  /** 1 for positive, 0 for negative **/
  test_date date, 
  test_id varchar, 
  covid19_test_type bit
  /** 0 for ART, 1 for PCR **/
);

CREATE TABLE IF NOT EXISTS 
health_declaration (
  nric char(9) PRIMARY KEY, 
  declaration_date date, 
  covid_symptoms bit, 
  /** 1 for symptoms visible, 0 for symptoms not visible **/
  temperature float, 
  health_declaration_id varchar
);
