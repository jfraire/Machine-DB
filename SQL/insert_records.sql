INSERT INTO machine_types (machine_type) 
VALUES ('X12');

INSERT INTO items (part_number) 
VALUES ('05-0396M');

INSERT INTO items (part_number) 
VALUES ('05-0397M');

INSERT INTO machines (machine_id, machine_type) 
VALUES ('x12-002', 'X12');

INSERT INTO machine_state
(machine_id, current_reference, next_reference) 
VALUES ('x12-002', '05-0396M', '05-0397M');

INSERT INTO parameters (part_number, machine_type, parameters)
VALUES ('05-0396M', 'X12', 'This is the params field');

INSERT INTO parameters (part_number, machine_type, parameters)
VALUES ('05-0397M', 'X12', 'Params for 05-0397M');

INSERT INTO alarm_codes VALUES ('X12', 0,  'Working conditions OK');
INSERT INTO alarm_codes VALUES ('X12', 1,  'ERROR: Watchdog timer activated');
INSERT INTO alarm_codes VALUES ('X12', 2,  'ERROR: The controller of the table motor is in error');
INSERT INTO alarm_codes VALUES ('X12', 3,  'ERROR: Failed obtaining a MODBUS address for the table motor');
INSERT INTO alarm_codes VALUES ('X12', 4,  'ERROR: Failed sending a MODBUS write request to the table motor');
INSERT INTO alarm_codes VALUES ('X12', 5,  'ERROR: Failed sending a MODBUS read request to the table motor');
INSERT INTO alarm_codes VALUES ('X12', 6,  'ERROR: The table motor is stuck in torque mode (home sensor is probably active)');
INSERT INTO alarm_codes VALUES ('X12', 7,  'ERROR: Charger motor error');
INSERT INTO alarm_codes VALUES ('X12', 8,  'ERROR: Failed obtaining a MODBUS address for the table motor');
INSERT INTO alarm_codes VALUES ('X12', 9,  'ERROR: Failed sending a MODBUS write request to the table motor');
INSERT INTO alarm_codes VALUES ('X12', 10, 'ERROR: Failed sending a MODBUS read request to the table motor');
INSERT INTO alarm_codes VALUES ('X12', 11, 'ERROR: The air pressure switch is open. Air pressure is either too high or too low');
INSERT INTO alarm_codes VALUES ('X12', 12, 'ERROR: The mix level for the front chamber is too low');
INSERT INTO alarm_codes VALUES ('X12', 13, 'ERROR: The mix level for the back chamber is too low');
INSERT INTO alarm_codes VALUES ('X12', 14, 'Warning: The mix level for the front chamber is low');
INSERT INTO alarm_codes VALUES ('X12', 15, 'Warning: The mix level for the back chamber is low');
INSERT INTO alarm_codes VALUES ('X12', 16, 'ERROR: A Wire switch did not activate. A cable is probably off the upper tools');
INSERT INTO alarm_codes VALUES ('X12', 17, 'ERROR: The MQTT broker is taking too long to answer requests');
INSERT INTO alarm_codes VALUES ('X12', 18, 'DANGER: The emergency stop was activated');
INSERT INTO alarm_codes VALUES ('X12', 19, 'DANGER: Tried to use the press while the door is not closed');
INSERT INTO alarm_codes VALUES ('X12', 20, 'ERROR: The press is too low to start a compression cycle');
INSERT INTO alarm_codes VALUES ('X12', 21, 'ERROR: At least one of the cradle extension sensors is active');
INSERT INTO alarm_codes VALUES ('X12', 22, 'ERROR: The wire cutting blade sensor is active');
INSERT INTO alarm_codes VALUES ('X12', 23, 'ERROR: The brush ejector return sensor is not active');

