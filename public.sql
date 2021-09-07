CREATE TABLE IF NOT EXISTS query_table (
  record_id varchar PRIMARY KEY,
  vaccination_status int,
  /** 0 for Vac,1 for UnVac, 2 for inprog**/
  covid19_status bit,
  /** 0 for negative, 1 for positive**/
  age_range varchar,
  /**1-10,11-20,21-30,31-40,41-50,51-60,61-70,71-80,81-90,91-**/
  area varchar,
  /**N,S,E,W,C**/
  gender bit,
  /**0 for M, 1 for F**/
  race varchar
  /**C,M,I,O**/
);