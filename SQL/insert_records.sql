INSERT INTO machine_types (type) 
VALUES ('X12');

INSERT INTO items (part_number) 
VALUES ('05-0396M');

INSERT INTO items (part_number) 
VALUES ('05-0397M');

INSERT INTO machines (machine_id, type) 
VALUES ('x12-002', 'X12');

INSERT INTO machine_state
(machine_id, current_reference, next_reference) 
VALUES ('x12-002', '05-0396M', '05-0397M');

INSERT INTO parameters (part_number, type, parameters)
VALUES ('05-0396M', 'X12', 'This is the params field');

INSERT INTO parameters (part_number, type, parameters)
VALUES ('05-0397M', 'X12', 'Params for 05-0397M');
