begin;
CREATE TABLE IF NOT EXISTS Customers (
  cust_id SERIAL PRIMARY KEY,
  cust_name TEXT NOT NULL,
  address TEXT,
  email TEXT,
  phone TEXT
);

/** Credit Cards
    combined with Owns table (Key + Total Participation Constraint)
    Every customer must own at least one credit card
**/
CREATE TABLE IF NOT EXISTS Credit_cards ( 
    credit_card_number TEXT PRIMARY KEY,
    CVV CHAR(3) NOT NULL,
    owned_by INT NOT NULL REFERENCES Customers(cust_id),
    expiry_date DATE NOT NULL,
    from_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP::timestamp,
    UNIQUE (credit_card_number, owned_by),
    check (
        from_date < expiry_date
    )
);

CREATE TABLE IF NOT EXISTS Rooms (
  rid INT PRIMARY KEY,
  location TEXT UNIQUE NOT NULL,
  seating_capacity INT NOT NULL
);

CREATE TABLE IF NOT EXISTS Employees (
  eid SERIAL PRIMARY KEY,
  ename TEXT,
  phone TEXT,
  address TEXT,
  email TEXT,
  join_date DATE,
  depart_date DATE DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS Full_Time_Emp (
  eid INT PRIMARY KEY REFERENCES Employees
    ON DELETE CASCADE,
  monthly_salary FLOAT NOT NULL
);

CREATE TABLE IF NOT EXISTS Part_Time_Emp (
  eid INT PRIMARY KEY REFERENCES Employees
    ON DELETE CASCADE,
  hourly_rate FLOAT NOT NULL
);

CREATE TABLE IF NOT EXISTS Administrators (
  eid INT PRIMARY KEY REFERENCES Full_Time_Emp(eid) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Managers (
  eid INT PRIMARY KEY REFERENCES Full_Time_Emp(eid) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Instructors (
  eid INT PRIMARY KEY REFERENCES Employees ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Full_Time_Instructor (
  eid INT PRIMARY KEY REFERENCES Full_Time_Emp REFERENCES Instructors ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Part_Time_Instructor (
  eid INT PRIMARY KEY REFERENCES Part_Time_Emp REFERENCES Instructors ON DELETE CASCADE
);

/*WEAK ENTITY OF EMPLOYEES, combined with For*/
CREATE TABLE IF NOT EXISTS Pay_slips_for (
  eid INT NOT NULL REFERENCES Employees ON DELETE CASCADE,
  payment_date DATE,
  num_work_hours INT,
  num_work_days INT,
  amount FLOAT,
  PRIMARY KEY (eid, payment_date)
);
/** Combined with Manages table (Key + Total participation constraint) **/
CREATE TABLE IF NOT EXISTS Course_areas ( 
  area_name TEXT PRIMARY KEY,
  manager_id INT NOT NULL REFERENCES Managers
);

CREATE TABLE IF NOT EXISTS Specializes (
  area_name TEXT NOT NULL REFERENCES Course_areas,
  eid INT NOT NULL REFERENCES Instructors
);

CREATE TABLE IF NOT EXISTS Courses (
  course_id INT PRIMARY KEY,
  title TEXT,
  duration INT,
  description TEXT,
  area_name TEXT NOT NULL REFERENCES Course_areas,
  UNIQUE (title)
);

/** Offerings 
    combined with Has table (weak entity of Courses)
    Combined with Handles table (Key + Total Participation Constraint)
 **/
CREATE TABLE IF NOT EXISTS Offerings (
    course_id INT REFERENCES Courses,
    fees NUMERIC NOT NULL,
    target_number_registrations INT NOT NULL,
    launch_date DATE NOT NULL,
    /* The registration deadline for a course offering must be at least 10 days before its start date. */
    registration_deadline DATE NOT NULL,
    /* Each course offering is handled by an administrator */
    eid INT NOT NULL REFERENCES Administrators,
    start_date DATE,
    end_date DATE,
    seating_capacity INT,
    
    /** No two offerings for the same course can have the same launch date. **/
    PRIMARY KEY(course_id, launch_date),
    check (
      AGE(start_date, registration_deadline) >= interval '10 days'
      and
      start_date <= end_date
      and
      launch_date <= registration_deadline
    )
);

/** Sessions combined with Consists table as a Weak Entity of Offerings
    Combined with Conducts table (Key + Total Participation Constraint)
**/
CREATE TABLE IF NOT EXISTS Sessions (
  sid SERIAL,
  s_date DATE,
  /** start_time and end_time using 24h clock **/
  start_time TIME,
  end_time TIME,
  course_id INT NOT NULL,
  launch_date DATE NOT NULL,
  conducted_in INT NOT NULL REFERENCES Rooms(rid),
  conducting_instructor INT NOT NULL REFERENCES Instructors(eid),

  PRIMARY KEY(sid, course_id, launch_date),
  FOREIGN KEY (course_id, launch_date) REFERENCES Offerings
  ON UPDATE CASCADE,

  check (
    (start_time >= TIME '09:00:00' and end_time <= TIME '12:00:00')
    or
    (start_time >= TIME '14:00:00' and end_time <= TIME '18:00:00')
    and start_time < end_time
    /** each session is conducted by an instructor on a specific weekday (Monday to Friday) **/
    and date_part('dow', s_date) < 6
  )
);

CREATE TABLE IF NOT EXISTS Course_packages (
    package_id SERIAL PRIMARY KEY,
    sale_start_date DATE NOT NULL,
    sale_end_date DATE NOT NULL,
    num_free_registrations INT NOT NULL CHECK (num_free_registrations > 0),
    package_name TEXT NOT NULL,
    price NUMERIC NOT NULL CHECK (price > 0),
    CONSTRAINT valid_sale_dates check(
        sale_start_date <= sale_end_date
    )
);

/** Tracks the packages bought by a given customer **/
CREATE TABLE IF NOT EXISTS Buys (
    buy_date DATE,
    credit_card_number TEXT,
    owned_by INT,
    num_remaining_redemptions INT NOT NULL,
    package_id INT NOT NULL REFERENCES Course_packages,
    PRIMARY KEY (package_id, buy_date, credit_card_number, owned_by),
    FOREIGN KEY (credit_card_number, owned_by) REFERENCES Credit_cards (credit_card_number, owned_by), /* should not on update cascade */
    check (
        num_remaining_redemptions >= 0
    )
);

/** Tracks customer redeeming a session from his/her active course package **/
CREATE TABLE IF NOT EXISTS Redeems (
    redeem_date DATE NOT NULL,
    package_id INT,
    buy_date DATE,
    credit_card_number TEXT,
    owned_by INT,
    course_id INT,
    launch_date DATE,
    sid INT,
    FOREIGN KEY (sid, course_id, launch_date) REFERENCES Sessions (sid, course_id, launch_date)
        ON UPDATE CASCADE,
    FOREIGN KEY (package_id, buy_date, credit_card_number, owned_by) REFERENCES Buys (package_id, buy_date, credit_card_number, owned_by)
      ON UPDATE CASCADE,
    PRIMARY KEY (package_id, buy_date, credit_card_number, owned_by, redeem_date, course_id, launch_date, sid),
    check (
        redeem_date >= buy_date
    )
);

/** Tracks the payment made when a customer registers for a course **/
CREATE TABLE IF NOT EXISTS Registers (
    sid INT,
    course_id INT,
    launch_date DATE,
    registration_date DATE,
    credit_card_number TEXT,
    owned_by INT,
    FOREIGN KEY (sid, course_id, launch_date) REFERENCES Sessions (sid, course_id, launch_date)
        ON UPDATE CASCADE,
    FOREIGN KEY (credit_card_number, owned_by) REFERENCES Credit_cards (credit_card_number, owned_by)
      ON UPDATE CASCADE,
    PRIMARY KEY(registration_date, credit_card_number, owned_by, sid, course_id, launch_date)
);

CREATE TABLE IF NOT EXISTS Cancels (
    cancel_date DATE,
    cust_id INT REFERENCES Customers,
    sid INT,
    course_id INT,
    launch_date DATE,
    refund_amt FLOAT, /* 90% or 0 or null */
    package_credit INT, /* 1 or 0 or null */
    PRIMARY KEY (cancel_date, cust_id, sid, course_id, launch_date),
    FOREIGN KEY (sid, course_id, launch_date) REFERENCES Sessions
        ON UPDATE CASCADE,
    check (
        (refund_amt IS NOT NULL AND package_credit IS NULL)
        OR
        (refund_amt IS NULL AND package_credit IS NOT NULL)
    )
);


/** A course offering is said to be available if the number of registrations received is no more than its seating capacity; 
    otherwise, we say that a course offering is fully booked.
**/
CREATE OR REPLACE VIEW Available_course_offerings AS
WITH registered_sessions AS (
    SELECT Offerings.course_id, Offerings.launch_date, COUNT(*) as registration_count
    FROM Offerings
    NATURAL JOIN Sessions
    NATURAL JOIN Registers
    GROUP BY Offerings.course_id, Offerings.launch_date
), redeemed_sessions AS (
    SELECT Offerings.course_id, Offerings.launch_date, COUNT(*) as redeem_count
    FROM Offerings
    NATURAL JOIN Sessions
    NATURAL JOIN Redeems
    GROUP BY Offerings.course_id, Offerings.launch_date
), current_capacity AS (
    SELECT Reg.course_id, Reg.launch_date, COALESCE(Reg.registration_count,0) + COALESCE(Red.redeem_count,0) as current_count
    FROM registered_sessions Reg
    FULL OUTER JOIN redeemed_sessions Red ON Reg.course_id = Red.course_id AND Reg.launch_date = Red.launch_date
)
SELECT DISTINCT Courses.area_name, Offerings.course_id, Offerings.launch_date, Offerings.registration_deadline, Offerings.start_date, Offerings.end_date, Offerings.fees,
Offerings.seating_capacity, (Offerings.seating_capacity - COALESCE(current_capacity.current_count,0)) as remaining_capacity
FROM Offerings
JOIN Courses USING (course_id)
LEFT OUTER JOIN current_capacity USING (course_id, launch_date)
WHERE Offerings.seating_capacity > COALESCE(current_capacity.current_count,0);

/** Each customer can have at most one active or partially active package.
    1. Active: >= 1 unused session in package
    2. Partially active: all sessions redeemed but >= 1 can be refunded if cancelled: 
        (can be cancelled if )current_date is >= 7 days before registered session)
    3. Else, inactive
**/
CREATE OR REPLACE VIEW Current_Active_Packages AS 
WITH Active_packages AS (
    SELECT *
    FROM Buys
    WHERE num_remaining_redemptions > 0
), Partially_active_packages AS (
    SELECT Buys.buy_date, Buys.credit_card_number, Buys.owned_by, Buys.num_remaining_redemptions, Buys.package_id 
    FROM Buys 
    JOIN Redeems USING (buy_date, credit_card_number, owned_by)
    JOIN Sessions USING (sid, course_id, launch_date)
    WHERE (Sessions.s_date - interval '7 days' >= (SELECT CURRENT_DATE))
)
SELECT DISTINCT *
FROM Active_packages
UNION
SELECT DISTINCT *
FROM Partially_active_packages;

/** Every customer must own at least one credit card **/
CREATE OR REPLACE FUNCTION check_credit_card() RETURNS TRIGGER
AS $$
    BEGIN
      IF ((SELECT COUNT(credit_card_number) FROM Credit_cards WHERE owned_by = NEW.cust_id) = 0) THEN
        RAISE EXCEPTION 'Each customer must own at least one credit card';
        RETURN NULL;
      END IF;
      RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER owns_credit_card
AFTER UPDATE OR INSERT ON Customers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_credit_card();

CREATE OR REPLACE FUNCTION check_credit_card_date() RETURNS TRIGGER
AS $$
    BEGIN
      IF (NEW.expiry_date < CURRENT_DATE) THEN
        RAISE EXCEPTION 'Credit card % is invalid as it has expired (%).', NEW.credit_card_number, NEW.expiry_date;
        RETURN NULL;
      END IF;
      RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER credit_card_not_expired
AFTER UPDATE OR INSERT ON Credit_cards
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_credit_card_date();
/** Employees-1: Each employee in the company is exclusively either a manager, an administrator, or an instructor **/

CREATE OR REPLACE FUNCTION check_employee_role_func() RETURNS TRIGGER 
AS $$
  DECLARE
      manager INT;
      administrator INT;
      instructor INT;
  BEGIN
      manager := (SELECT 1 FROM Managers WHERE Managers.eid = NEW.eid);
      administrator := (SELECT 1 FROM Administrators WHERE Administrators.eid = NEW.eid);
      instructor := (SELECT 1 FROM Instructors WHERE Instructors.eid = NEW.eid);
      IF (manager + administrator + instructor) THEN
          RAISE EXCEPTION 'Employee is assigned to multiple roles: manager (%), administrator (%), instructor (%).', manager, administrator, instructor;
          RETURN NULL;
      END IF;
      RETURN NEW;
  END;  
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_employee_role
AFTER INSERT OR UPDATE ON Employees
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE PROCEDURE check_employee_role_func();

/** Employees-3: If the employee has already left the company, it cannot have an existing role in the company. 
  Design decision: Depart-date is not null if the employee has already left the company. 
  Design decision: Manages lists the course areas
  Raise Exception (don't need to assign to new). if:
    1. Outgoing Administrator assigned to a course offering that has not ended
    2. Outgoing Instructor assigned to a course session that has not ended
  Trigger checks: Update depart_date on employee
**/
CREATE OR REPLACE FUNCTION check_employee_assignment() RETURNS TRIGGER 
AS $$
  BEGIN
    IF NEW.depart_date IS NULL THEN
        RETURN NEW;
    ELSIF EXISTS (SELECT 1 FROM Offerings WHERE Offerings.eid = NEW.eid AND Offerings.registration_deadline > NEW.depart_date) THEN
        RAISE EXCEPTION 'Employee still assigned to ongoing offerings';
        RETURN NULL;
    ELSIF EXISTS (SELECT 1 FROM Sessions WHERE Sessions.conducting_instructor = NEW.eid AND  NEW.depart_date < Sessions.s_date) THEN
      RAISE EXCEPTION 'Employee still assigned to ongoing sessions';
      RETURN NULL;
    ELSIF EXISTS (SELECT 1 FROM Course_areas WHERE NEW.eid = Course_areas.manager_id) THEN
        RAISE EXCEPTION 'Employee still assigned to course area';
        RETURN NULL;
    END IF;
    RETURN NEW;
  END
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER employee_not_assigned_when_departed
AFTER INSERT OR UPDATE ON Employees
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_employee_assignment();

-- Employees-4: All managers and administrators are full-time employees 
CREATE OR REPLACE FUNCTION is_full_time() RETURNS TRIGGER AS $$
    BEGIN
        IF NOT EXISTS(SELECT Full_Time_Emp.eid FROM Full_Time_Emp WHERE Full_Time_Emp.eid = NEW.eid) THEN
            RAISE EXCEPTION 'Employee must be full time';
            RETURN NULL;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER manager_is_full_time
AFTER INSERT ON Managers
FOR EACH ROW EXECUTE FUNCTION is_full_time();

CREATE CONSTRAINT TRIGGER administrator_is_full_time
AFTER INSERT ON Administrators
FOR EACH ROW EXECUTE FUNCTION is_full_time();

--Employees-5,9 Every Employee is either a Part_Time_Emp or Full_Time_Emp but not both
CREATE OR REPLACE FUNCTION either_part_or_full_time() RETURNS TRIGGER AS $$
    DECLARE
        part_timer INT;
        full_timer INT;
    BEGIN
        part_timer := (SELECT 1 FROM Part_Time_Emp WHERE Part_Time_Emp.eid = NEW.eid);
        full_timer := (SELECT 1 FROM Full_Time_Emp WHERE Full_Time_Emp.eid = NEW.eid);
        IF (part_timer + full_timer > 1) THEN
            RAISE EXCEPTION 'Employee cannot be both full time and part time';
            RETURN NULL;
        ELSIF (part_timer + full_timer < 1) THEN
            RAISE EXCEPTION 'Employee cannot be neither full time nor part time';
            RETURN NULL;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER employment_status_checker
AFTER INSERT ON Employees
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION either_part_or_full_time();

-- Employees-6: Every Instructor must specialize in at least 1 area.
CREATE OR REPLACE FUNCTION instructors_specialize_func()
RETURNS TRIGGER AS $$
    BEGIN
        IF NOT EXISTS (SELECT eid FROM Instructors WHERE eid = NEW.eid) THEN
            RAISE EXCEPTION 'Instructor does not have a specialization';
            RETURN NULL;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER instructors_specialize_trigger
AFTER INSERT ON Instructors
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION instructors_specialize_func();

--Employees-7 Either hours or days worked is filled in but not both. The field filled should correspond to the employee type.
CREATE OR REPLACE FUNCTION reject_contradicting_payslip()
RETURNS TRIGGER AS $$
    BEGIN
        IF (NEW.num_work_days IS NOT NULL AND NEW.num_work_hours IS NOT NULL) THEN
          RAISE EXCEPTION 'Either work days or work hours should be recorded but not both.';
          RETURN NULL;
        ELSIF (NEW.num_work_days IS NULL AND NEW.num_work_hours IS NULL) THEN
          RAISE EXCEPTION 'Either work days or work hours should be filled.';
          RETURN NULL;
        ELSIF (NEW.num_work_days IS NOT NULL) THEN
          IF (NOT EXISTS(SELECT 1 FROM Full_Time_Emp WHERE eid = NEW.eid)) THEN
            RAISE EXCEPTION 'Full time employee does not exist or is a part time employee.';
            RETURN NULL;
          END IF;
        ELSIF (NEW.num_work_hours IS NOT NULL) THEN
          IF (NOT EXISTS(SELECT 1 FROM Part_Time_Emp WHERE eid = NEW.eid)) THEN
            RAISE EXCEPTION 'Part time employee does not exist or is a full time employee.';
            RETURN NULL;
          END IF;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reject_contradicting_payslip_trigger
BEFORE INSERT OR UPDATE ON Pay_slips_for
FOR EACH ROW EXECUTE FUNCTION reject_contradicting_payslip();

--Employees-8 Payment amount is correct
CREATE OR REPLACE FUNCTION check_salary_paid()
RETURNS TRIGGER AS $$
    DECLARE
        first_work_day INT;
        last_work_day INT;
        curr_date DATE := (SELECT CURRENT_DATE);
        days_in_curr_month INT := (SELECT DATE_PART('days', DATE_TRUNC('month', curr_date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL)::INTEGER);
        hours_worked INT;
        join_date DATE;
        depart_date DATE;
    BEGIN
        /* check if employee has joined or departed within month of payment */
        SELECT Employees.join_date, Employees.depart_date 
            INTO join_date, depart_date
            FROM Employees WHERE Employees.eid = NEW.eid;
        IF (date_trunc('month', join_date) = date_trunc('month', curr_date)) THEN
            first_work_day := (SELECT EXTRACT(DAY FROM join_date)::INTEGER);
        ELSE
            first_work_day := 1;
        END IF;

        /* if depart_date is not null, means that the employee has departed within the month. Extract the day of departure */
        IF (depart_date IS NOT NULL AND DATE_TRUNC('month', depart_date) = DATE_TRUNC('month', curr_date)) THEN
            last_work_day := (SELECT EXTRACT(DAY from depart_date)::INTEGER);
        ELSE
            last_work_day := days_in_curr_month;
        END IF;

        IF (NEW.num_work_days IS NOT NULL) THEN
            IF (NEW.num_work_days <> (last_work_day - first_work_day + 1)) THEN
                RAISE EXCEPTION 'Number of work days for (employee %, %) is calculated incorrectly. Expected (%) but got (%)', 
                    NEW.eid, (SELECT DATE_TRUNC('month', curr_date) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL)::DATE, (last_work_day - first_work_day + 1), NEW.num_work_days;
                RETURN NULL;
            ELSIF ((SELECT ROUND(monthly_salary::NUMERIC / days_in_curr_month * NEW.num_work_days, 2) FROM Full_Time_Emp WHERE eid = NEW.eid) <> NEW.amount) THEN
                RAISE EXCEPTION 'Pay slip amount for full time employee (%) is calculated incorrectly. Expected (% for % / % days) but got (%)', 
                    NEW.eid, (SELECT ROUND(monthly_salary::NUMERIC / days_in_curr_month * NEW.num_work_days, 2) FROM Full_Time_Emp WHERE eid = NEW.eid),
                    NEW.num_work_days, days_in_curr_month, NEW.amount;
                RETURN NULL;
            END IF;
        ELSIF (NEW.num_work_hours IS NOT NULL) THEN
            hours_worked := (SELECT SUM(Sessions.start_time - Sessions.end_time)
                          FROM Sessions
                          WHERE Sessions.conducting_instructor = NEW.eid
                          AND date_trunc('month', Sessions.s_date) = date_trunc('month', curr_date));
            IF (NEW.num_work_hours <> hours_worked) THEN
                RAISE EXCEPTION 'Number of work hours is calculated incorrectly!';
                RETURN NULL;
            ELSIF ((SELECT ROUND(hourly_rate::NUMERIC * NEW.num_work_hours, 2) FROM Part_Time_Emp WHERE eid = NEW.eid)  <> NEW.amount) THEN
                RAISE EXCEPTION 'Pay slip amount for part time employee (%) is calculated incorrectly. Expected (% for % hours) but got (%)',
                    NEW.eid, (SELECT ROUND(hourly_rate::NUMERIC * NEW.num_work_hours, 2) FROM Part_Time_Emp WHERE eid = NEW.eid), NEW.num_work_hours, NEW.amount;
                RETURN NULL;
            END IF;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_salary_paid_trigger
AFTER INSERT OR UPDATE ON Pay_slips_for
FOR EACH ROW EXECUTE FUNCTION check_salary_paid();
/** Administrator cannot have left the company before registration_deadline of the offering. **/
CREATE OR REPLACE FUNCTION check_administrator_not_departed()
RETURNS TRIGGER AS $$
    DECLARE
        depart_date DATE;
    BEGIN
        depart_date := (SELECT Employees.depart_date FROM Employees WHERE Employees.eid = NEW.eid);
        IF EXISTS(SELECT 1 FROM Administrators WHERE Administrators.eid = NEW.eid) 
            AND 
                (depart_date IS NOT NULL) 
            AND
                (NEW.registration_deadline > depart_date)
        THEN
            RAISE EXCEPTION 'Administrator (%) assigned to Offering (%, %) has already departed.', new.eid, new.course_id, new.launch_date;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER administrator_not_departed
AFTER INSERT OR UPDATE ON Offerings
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION check_administrator_not_departed();

/** Ensure that every update to the Sessions table also reflects corresponding changes to Offerings **/
CREATE OR REPLACE FUNCTION sessions_consistent_with_offerings()
RETURNS TRIGGER AS $$
    DECLARE
        start_date DATE;
        end_date DATE;
        capacity INT;
        n INT;
        o RECORD;
    BEGIN
        IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
            SELECT min(s_date), max(s_date), sum(seating_capacity)
                INTO start_date, end_date, capacity
                FROM Sessions
                JOIN ROOMS ON Sessions.conducted_in = Rooms.rid
                WHERE (Sessions.course_id = NEW.course_id) AND (Sessions.launch_date = NEW.launch_date);
            SELECT * into o
                FROM Offerings
                WHERE (Offerings.course_id = NEW.course_id) AND (Offerings.launch_date = NEW.launch_date);
            /** Each course offering has a start date and an end date that is determined by the dates of its earliest and latest sessions, respectively **/
            IF (o.start_date <> start_date OR o.end_date <> end_date) THEN
                RAISE EXCEPTION 'Offering (%, %) assigned incorrect start and end date. Expected (%, %) but got (%, %).', NEW.course_id, NEW.launch_date, start_date, end_date, o.start_date, o.end_date;
            /** seating capacity of a course offering is equal to the sum of the seating capacities of its sessions **/
            ELSIF (o.seating_capacity <> capacity) THEN
                RAISE EXCEPTION 'Seating capacity of a course offering has to be equal to the sum of the seating capacities of its sessions. Expected %, got %.', capacity, o.seating_capacity;
            END IF;
        END IF;
        IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
            SELECT max(s_date), min(s_date), count(*), sum(seating_capacity)
                INTO start_date, end_date, n, capacity
                FROM Sessions
                JOIN Rooms ON Sessions.conducted_in = Rooms.rid
                WHERE (Sessions.course_id = OLD.course_id) AND (Sessions.launch_date = OLD.launch_date);
            SELECT * 
                INTO o 
                FROM Offerings 
                WHERE (Offerings.course_id = OLD.course_id) AND (Offerings.launch_date = OLD.launch_date);
            /** Every offering has at least one session **/
            IF ((SELECT count(*) FROM t) < 1) THEN
                RAISE EXCEPTION 'Offering (%, %) does not have any sessions assigned.', OLD.course_id, OLD.launch_date;
            /** Each course offering has a start date and an end date that is determined by the dates of its earliest and latest sessions, respectively **/
            ELSIF (o.start_date <> start_date OR o.end_date <> end_date) THEN
                RAISE EXCEPTION 'Offering (%, %) assigned incorrect start and end date. Expected (%, %) but got (%, %).', OLD.course_id, OLD.launch_date, start_date, end_date, OLD.start_date, OLD.end_date;
            /** seating capacity of a course offering is equal to the sum of the seating capacities of its sessions **/
            ELSIF (o.seating_capacity <> capacity) THEN
                RAISE EXCEPTION 'Seating capacity of a course offering has to be equal to the sum of the seating capacities of its sessions';
            END IF;
        END IF;
        RETURN NULL;
    END;   
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER reject_inconsistent_update_to_sessions
AFTER INSERT OR UPDATE OR DELETE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION sessions_consistent_with_offerings();

/** Ensure that every update to the Offerings table also reflects corresponding changes to Sessions **/
CREATE OR REPLACE FUNCTION offerings_consistent_with_sessions()
RETURNS TRIGGER AS $$
    DECLARE
        capacity INT;
        n INT;
        start_date DATE;
        end_date DATE;
    BEGIN
        SELECT min(s_date), max(s_date), count(*), sum(seating_capacity)
            INTO  start_date, end_date
            FROM Sessions NATURAL JOIN Rooms 
            WHERE (Sessions.course_id = NEW.course_id) AND (Sessions.launch_date = NEW.launch_date);

        /** Every offering has at least one session **/
        IF (n < 1) THEN
            RAISE EXCEPTION 'Offering (%, %) does not have any sessions assigned.', NEW.course_id, NEW.launch_date;
        END IF;
        /** Each course offering has a start date and an end date that is determined by the dates of its earliest and latest sessions, respectively **/
        IF (NEW.start_date <> start_date OR NEW.end_date <> end_date) THEN
            RAISE EXCEPTION 'Offering (%, %) assigned incorrect start and end date. Expected (%, %) but got (%, %).', NEW.course_id, NEW.launch_date, start_date, end_date, NEW.start_date, NEW.end_date;
        END IF;
        /** seating capacity of a course offering is equal to the sum of the seating capacities of its sessions **/
        IF (NEW.seating_capacity <> capacity) THEN
            RAISE EXCEPTION 'Seating capacity of a course offering has to be equal to the sum of the seating capacities of its sessions';
        END IF;
        RETURN NULL;
    END;   
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER reject_inconsistent_update_to_offerings
AFTER INSERT OR UPDATE ON Offerings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION offerings_consistent_with_sessions();

/** Prevent deleting of an offering if it has sessions assigned to it **/
CREATE OR REPLACE FUNCTION check_has_sessions_assigned()
RETURNS TRIGGER AS $$
    DECLARE
        ss RECORD;
    BEGIN
        IF ((SELECT COUNT(*) FROM Sessions WHERE (Sessions.course_id = OLD.course_id) AND (Sessions.launch_date = OLD.launch_date)) > 0) THEN
            RAISE EXCEPTION 'Offering (%, %) cannot be deleted as it still has sessions assigned.', NEW.course_id, NEW.launch_date;
        END IF;
        RETURN NULL;
    END;   
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER reject_delete_offering_with_sessions
AFTER DELETE ON Offerings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_has_sessions_assigned();

CREATE OR REPLACE FUNCTION check_session_timetable_constraints()
RETURNS TRIGGER AS $$
    DECLARE
        r RECORD;
        registration_count INT;
    BEGIN
        CREATE TEMPORARY TABLE t AS (
            SELECT * 
            FROM Sessions 
            WHERE 
                Sessions.s_date = NEW.s_date
                AND (
                    (Sessions.start_time <= NEW.start_time AND Sessions.end_time > NEW.start_time) 
                    OR (Sessions.start_time > NEW.start_time AND Sessions.start_time < NEW.end_time)
                )
        );
        /** No two sessions for the same course offering can be conducted on the same day and at the same time **/
        /** Assumed intepretation: that the timeslots cant overlap **/ 
        IF EXISTS(SELECT * FROM t WHERE NEW.course_id = t.course_id AND NEW.launch_date = t.launch_date AND NEW.sid <> t.sid) THEN
            r := (SELECT * FROM t WHERE NEW.course_id = t.course_id AND NEW.launch_date = t.launch_date AND NEW.sid <> t.sid LIMIT 1);
            RAISE EXCEPTION 'Session (%, %, %) clashes with existing session (%, %, %) in this time slot.', NEW.course_id, NEW.launch_date, NEW.sid, r.course_id, r.launch_date, r.sid;
        /** Each room can be used to conduct at most one course session at any time **/
        ELSIF EXISTS(SELECT * FROM t WHERE NEW.conducted_in = t.conducted_in AND NEW.sid <> t.sid) THEN
            RAISE EXCEPTION 'Session (%, %, %) clashes with existing session in the same room.', NEW.course_id, NEW.launch_date, NEW.sid;
        ELSIF TG_OP = 'UPDATE' THEN
            registration_count := (SELECT count(*) FROM Registers 
                WHERE Registers.sid = NEW.sid AND Registers.course_id = NEW.course_id AND Registers.launch_date = NEW.launch_date)
                +
                (SELECT count(*) FROM Redeems 
                WHERE Redeems.sid = NEW.sid AND Redeems.course_id = NEW.course_id AND Redeems.launch_date = NEW.launch_date);
            IF registration_count > (SELECT seating_capacity FROM Rooms WHERE rid = NEW.conducted_in) THEN
                RAISE EXCEPTION 'Session (%, %, %) exceeds room capacity after room change.', NEW.course_id, NEW.launch_date, NEW.sid;
            END IF;
        END IF;
        DROP TABLE IF EXISTS t;
        RETURN NULL;
    END;   
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER reject_clashing_sessions
AFTER INSERT OR UPDATE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_session_timetable_constraints();

CREATE OR REPLACE FUNCTION check_session_instructor()
RETURNS TRIGGER AS $$
    DECLARE
        course_area TEXT;
        depart_date DATE;
    BEGIN
        /** instructor who is assigned to teach a course session must be specialized in that course area **/
        /** Also covers: Employee must be an instructor **/
        course_area := (SELECT area_name FROM Courses WHERE Courses.course_id = NEW.course_id);
        IF NOT EXISTS (SELECT 1 FROM Specializes WHERE Specializes.area_name = course_area AND Specializes.eid = NEW.conducting_instructor) THEN
            RAISE EXCEPTION 'Instructor is not specialized to teach % Session (%, %, %).', course_area, NEW.course_id, NEW.launch_date, NEW.sid;
        /** Instructor conducting session cannot have left the company before conducting date. **/
        depart_date := (SELECT depart_date FROM Employees WHERE Employees.eid = NEW.conducting_instructor);
        ELSIF (depart_date IS NOT NULL AND depart_date < NEW.s_date) THEN
            RAISE EXCEPTION 'Instructor for Session (%, %, %) has already departed.', NEW.course_id, NEW.launch_date, NEW.sid;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER reject_instructor
AFTER INSERT OR UPDATE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_session_instructor();

/** Working hours related constraints on Instructors conducting sessions **/
CREATE OR REPLACE FUNCTION check_session_instructor_hours()
RETURNS TRIGGER AS $$
    DECLARE
        hours_worked INT;
    BEGIN
        hours_worked := date_part('hour', (
            SELECT sum(Sessions.start_time - Sessions.end_time) 
            FROM Sessions 
            WHERE date_trunc('month', Sessions.s_date) = date_trunc('month', NEW.s_date)
                AND Sessions.conducting_instructor = NEW.conducting_instructor
        ));
        /** Each part-time instructor must not teach more than 30 hours for each month. **/
        IF (EXISTS (SELECT 1 FROM Part_Time_Instructor WHERE Part_Time_Instructor.eid = NEW.conducting_instructor) 
            AND hours_worked > 30) THEN
            RAISE EXCEPTION 'Part time Instructor has exceeded 30 working hours after teaching Session (%, %, %).', NEW.course_id, NEW.launch_date, NEW.sid;
        END IF;
        /** Each instructor can teach at most one course session at any hour.
            Each instructor must not be assigned to teach two consecutive course sessions 
            i.e., there must be at least one hour of break between any two course sessions that the instructor is teaching
        **/
        IF EXISTS(SELECT 1 
            FROM Sessions 
            WHERE 
                ((Sessions.start_time <= NEW.start_time AND Sessions.end_time > NEW.start_time - interval '1 hour') 
                    OR (Sessions.start_time > NEW.start_time AND Sessions.start_time < NEW.end_time + interval '1 hour'))
                AND
                Sessions.conducting_instructor = NEW.conducting_instructor
                AND
                Sessions.sid <> NEW.sid
                AND
                Sessions.s_date = NEW.s_date
            )
        THEN
            RAISE EXCEPTION 'Session (%, %, %) overlaps with existing session or rest time for instructor.', NEW.course_id, NEW.launch_date, NEW.sid;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER reject_instructor_working_hours
AFTER INSERT OR UPDATE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_session_instructor_hours();
/*
    1. For each course offered by the company, a customer can register for at most one of its sessions
    2. Session should only be in either register or redeems but not both
    3. If a course offering is fully booked (number of registrations has reached seating capacity), do not allow new registrations for that offering 
**/
CREATE OR REPLACE FUNCTION register_one_session_func()
RETURNS TRIGGER AS $$
    DECLARE
        reg_count INT;
        redeem_count INT;
        c_redeem_count INT;
        c_reg_count INT;
    BEGIN
        c_reg_count := (SELECT count(*) FROM Registers WHERE course_id = NEW.course_id AND Registers.owned_by = NEW.owned_by);
        c_redeem_count := (SELECT count(*) FROM Redeems WHERE course_id = NEW.course_id AND Redeems.owned_by = NEW.owned_by);
        reg_count := (SELECT COUNT(*) FROM Registers WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date);
        redeem_count := (SELECT COUNT(*) FROM Redeems WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date);
        IF ((c_reg_count + c_redeem_count) > 1) THEN
            RAISE EXCEPTION 'Customer has already registered for this course offering: register (%), redeem (%).', c_reg_count, c_redeem_count;
            RETURN NULL;
        ELSIF (
            (SELECT seating_capacity FROM Offerings WHERE course_id = NEW.course_id AND launch_date = NEW.launch_date) <= (reg_count + redeem_count)
        ) THEN
            RAISE EXCEPTION 'Course offering is fully booked.';
            RETURN NULL;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER register_course_trigger
AFTER INSERT OR UPDATE ON Registers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION register_one_session_func();

CREATE CONSTRAINT TRIGGER redeem_course_trigger
AFTER INSERT OR UPDATE ON Redeems
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION register_one_session_func(); /* it's the same trigger */

/* Refund rules:
1. If the cancellation is made less than 7 days before the day of the registered session, there is no refund
2. If the cancellation is made at least 7 days from day of registered session, customer is refunded:
    Credit either an extra course session to the course package 
    or refund 90% of the paid fees 
    but not both 
*/
CREATE OR REPLACE FUNCTION refund_amount_func()
RETURNS TRIGGER AS $$
    DECLARE
        session_date DATE;
        fee FLOAT;
    BEGIN
        IF (NEW.refund_amt IS NOT NULL AND NEW.package_credit IS NOT NULL) THEN
            RAISE EXCEPTION 'Only one of refund amount or package credit should be filled.';
        ELSIF (NEW.refund_amt IS NULL AND NEW.package_credit IS NULL) THEN
            RAISE EXCEPTION 'Either refund amount or package credit should be filled.';
        END IF;
        
        SELECT S.s_date, O.fees INTO session_date, fee
            FROM Sessions S
            JOIN Offerings O ON O.course_id = S.course_id AND O.launch_date = S.launch_date
            WHERE NEW.sid = S.sid AND NEW.course_id = S.course_id AND NEW.launch_date = S.launch_date;
        IF (session_date >= NEW.cancel_date + '7 days'::interval) THEN
            /** Refund is due **/
            IF (NEW.refund_amt IS NOT NULL AND NEW.refund_amt <> (fee * 0.9)) THEN
                RAISE EXCEPTION 'Refund amount is not .90 of the paid fees. Expected (%) got (%)', NEW.refund_amt, fee * 0.9;
            ELSIF (NEW.package_credit IS NOT NULL AND NEW.package_credit <> 1) THEN
                RAISE EXCEPTION 'Package credit is an invalid number: (%)', NEW.package_credit;
            END IF;
        ELSE
            /** No refund given **/
            IF (NEW.refund_amt IS NOT NULL AND NEW.refund_amt <> 0) THEN
                RAISE EXCEPTION 'Cancellation (%, %, %) is made less then 7 days before registered session (%). No refund should be given. Currently %.', 
                    NEW.cancel_date, NEW.cust_id, NEW.sid, session_date, NEW.refund_amt;
            ELSEIF (NEW.package_credit IS NOT NULL AND NEW.package_credit <> 0) THEN
                RAISE EXCEPTION 'Cancellation (%, %, %) is made less then 7 days before redeemed session (%). No refund should be given. Currently %.', 
                    NEW.cancel_date, NEW.cust_id, NEW.sid, session_date, NEW.package_credit;
            END IF;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_refund_amount
AFTER UPDATE OR INSERT ON Cancels
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION refund_amount_func();

/** Check that the updated credit card is used when the Customer made a purchase **/
CREATE OR REPLACE FUNCTION updated_card_check()
RETURNS TRIGGER AS $$
    DECLARE
        updated_card TEXT;
    BEGIN
        updated_card := (
            SELECT credit_card_number
            FROM Credit_cards
            WHERE NEW.owned_by = Credit_cards.owned_by
            ORDER BY from_date DESC
            LIMIT 1
        );
        IF (NEW.credit_card_number <> updated_card) THEN
            RAISE EXCEPTION 'Transactions should be conducted on the latest credit card. Expected: (%), saw (%)', updated_card, NEW.credit_card_number;
            RETURN NULL;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER updated_card_on_register
AFTER INSERT ON Registers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION updated_card_check();

CREATE CONSTRAINT TRIGGER updated_card_on_buy
AFTER INSERT ON Buys
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION updated_card_check();

CREATE OR REPLACE FUNCTION count_active_course_packages()
RETURNS TRIGGER AS $$
    BEGIN
        IF (SELECT count(*) FROM Current_Active_Packages CAP WHERE CAP.owned_by = NEW.owned_by) > 1 THEN
            RAISE EXCEPTION 'Customer % cannot have more than one active or partially active course package.', NEW.owned_by;
            RETURN NULL;
        END IF;
        RETURN NEW; 
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER one_active_course_package
AFTER INSERT ON Buys
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION count_active_course_packages();

CREATE OR REPLACE FUNCTION expired_card_check()
RETURNS TRIGGER AS $$
    DECLARE
        expiry DATE;
    BEGIN
        expiry := (
            SELECT expiry_date
            FROM Credit_cards
            WHERE NEW.owned_by = Credit_cards.owned_by AND NEW.credit_card_number = credit_card_number
            ORDER BY from_date DESC
            LIMIT 1
        );
        IF (expiry - interval '0 days' < (SELECT CURRENT_DATE)) THEN
            RAISE EXCEPTION 'Credit card number: (%) has expired. Unable to buy or register for course', NEW.credit_card_number;
            RETURN NULL;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER expired_card_on_buy
AFTER INSERT ON Buys
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION expired_card_check();

CREATE CONSTRAINT TRIGGER expired_card_on_register
AFTER INSERT ON Registers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION expired_card_check();commit;
