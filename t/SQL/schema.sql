-- Database schema to test mqtt2db

CREATE TABLE IF NOT EXISTS items (
    part_number    TEXT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS machine_types (
    machine_type   TEXT PRIMARY KEY,
    parameters     BLOB, -- Parameters metadata
    measurements   BLOB, -- Machine measurements metadata
    cycle_timings  BLOB  -- Cycle time metadata
);

CREATE TABLE IF NOT EXISTS machine_types_log (
    machine_type   TEXT REFERENCES machine_types,
    registered_on  TEXT DEFAULT (datetime('now')),
    parameters     BLOB,
    measurements   BLOB,
    cycle_timings  BLOB
);

CREATE TABLE IF NOT EXISTS parameters (
    machine_type   TEXT NOT NULL REFERENCES machine_types,
    part_number    TEXT NOT NULL REFERENCES items,
    std_cycle_time REAL,
    parameters     BLOB,
    UNIQUE (machine_type, part_number)
);

CREATE TABLE IF NOT EXISTS parameters_log (
    machine_type   TEXT NOT NULL REFERENCES machine_types,
    part_number    TEXT NOT NULL REFERENCES items,
    registered_on  TEXT DEFAULT (datetime('now')),
    std_cycle_time REAL,
    parameters     BLOB
);

CREATE TABLE IF NOT EXISTS defect_codes (
    defect_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    machine_type   TEXT NOT NULL REFERENCES machine_types,
    defect_number  INTEGER NOT NULL,
    defect_name    TEXT NOT NULL,
    UNIQUE (machine_type, defect_number)
);

CREATE TABLE IF NOT EXISTS state_codes (
    machine_type   TEXT NOT NULL REFERENCES machine_types,
    state_code     INTEGER NOT NULL,
    state_name     TEXT NOT NULL,
    UNIQUE (machine_type, state_code)
);

CREATE TABLE IF NOT EXISTS alarm_codes (
    machine_type   TEXT NOT NULL REFERENCES machine_types,
    alarm_number   INTEGER NOT NULL,
    alarm_name     TEXT NOT NULL,
    UNIQUE (machine_type, alarm_number)
);

CREATE TABLE IF NOT EXISTS machines (
    machine_id     TEXT PRIMARY KEY,
    machine_type   TEXT NOT NULL REFERENCES machine_types
);

CREATE TABLE IF NOT EXISTS machine_state (
    machine_id     TEXT NOT NULL REFERENCES machines,
    part_number    TEXT REFERENCES items,
    state_number   INTEGER DEFAULT 0,
    alarm_number   INTEGER DEFAULT 0,
    screen_number  INTEGER DEFAULT 0,
    current_params BLOB
);

CREATE TABLE IF NOT EXISTS state_log (
    machine_id     TEXT NOT NULL REFERENCES machines,
    man_order      TEXT REFERENCES manufacturing_orders,
    registered_on  TEXT DEFAULT (datetime('now')),
    state_number   INTEGER,
    alarm_number   INTEGER,
    screen_number  INTEGER,
    std_cycle_time REAL,
    parameters     BLOB
);

CREATE TABLE IF NOT EXISTS cycle_log (
    machine_id     TEXT NOT NULL REFERENCES machines,
    registered_on  TEXT DEFAULT (datetime('now')),
    part_number    TEXT REFERENCES items,
    cycle_quality  BOOLEAN,
    defect_number  INTEGER,
    cycle_time     REAL,
    measurements   BLOB,
    timings        BLOB
);
