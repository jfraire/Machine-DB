-- Database schema to test mqtt2db

CREATE TABLE machine_types (
    machine_type   TEXT PRIMARY KEY
);

CREATE TABLE items (
    part_number    TEXT PRIMARY KEY
);

CREATE TABLE machines (
    machine_id     TEXT PRIMARY KEY,
    machine_type   TEXT NOT NULL REFERENCES machine_types
);

CREATE TABLE manufacturing_orders (
    man_order      TEXT PRIMARY KEY,
    machine_id     TEXT NOT NULL REFERENCES machines,
    part_number    TEXT NOT NULL REFERENCES items,
    status         TEXT NOT NULL DEFAULT 'New'
);

CREATE TABLE production_plan (
    prod_plan      INTEGER PRIMARY KEY AUTOINCREMENT,
    man_order      TEXT NOT NULL,
    prod_date      TEXT NOT NULL,
    shift          INTEGER DEFAULT 1,
    planned_qty    INTEGER DEFAULT 0,
);

CREATE TABLE machine_state (
    machine_id     TEXT NOT NULL REFERENCES machines,
    man_order      TEXT NOT NULL REFERENCES manufacturing_orders,
    state_code     INTEGER DEFAULT 0,
    alarm_code     INTEGER DEFAULT 0,
    current_params BLOB
);

CREATE TABLE state_log (
    machine_id     TEXT NOT NULL REFERENCES machines,
    man_order      TEXT REFERENCES manufacturing_orders,
    registered_on  TEXT NOT NULL,
    state_code     INTEGER,
    alarm_code     INTEGER,
    parameters     BLOB
);

CREATE TABLE parameters (
    machine_type   TEXT NOT NULL REFERENCES machine_types,
    part_number    TEXT NOT NULL REFERENCES items,
    parameters     BLOB
);

CREATE TABLE cycle_log (
    machine_id     TEXT NOT NULL REFERENCES machines,
    registered_on  TEXT NOT NULL,
    cycle_quality  BOOLEAN,
    defect_name    TEXT,
    cycle_time     REAL,
    measurements   BLOB
);
