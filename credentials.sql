CREATE TABLE IF NOT EXISTS login_credentials (
  nric varchar PRIMARY KEY,
  hashed_password varchar NOT NULL,
  user_salt varchar,
  password_attempts int default '0',
  ble_serial_number varchar,
  account_status bit default '1',
  /** Boolean use 1, 0, or NULL**/
  account_role int
  /** 1 for admin, 2 for cp, 3 for user**/
);


/** add triggers for account status and password_attempts**/
