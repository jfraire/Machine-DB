/* Machine schema V2, 2017-05-23 */

CREATE TABLE IF NOT EXISTS items (
    part_number    TEXT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS machine_types (
    machine_type   TEXT PRIMARY KEY
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

CREATE TABLE IF NOT EXISTS machines (
    machine_id     TEXT PRIMARY KEY,
    machine_type   TEXT NOT NULL REFERENCES machine_types
);

CREATE TABLE IF NOT EXISTS config_clients (
    client_id      TEXT PRIMARY KEY,
    machine        TEXT REFERENCES machines
);

CREATE TABLE IF NOT EXISTS machine_state (
    machine_id     TEXT NOT NULL REFERENCES machines,
    part_number    TEXT REFERENCES items,
    next_item      TEXT REFERENCES items,
    state_number   INTEGER DEFAULT 0,
    alarm_number   INTEGER DEFAULT 0,
    alarm_text     TEXT,
    screen_number  INTEGER DEFAULT 0,
    current_params BLOB
);

CREATE TABLE IF NOT EXISTS state_log (
    machine_id     TEXT NOT NULL REFERENCES machines,
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
