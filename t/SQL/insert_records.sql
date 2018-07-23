INSERT INTO machine_types (machine_type) 
VALUES ('NGG');

INSERT INTO machine_types (machine_type) 
VALUES ('X12');

INSERT INTO items (part_number) 
VALUES ('05-0396M');

INSERT INTO items (part_number) 
VALUES ('05-0486M');

INSERT INTO machines (machine_id, machine_type) 
VALUES ('NGG-001', 'NGG');

INSERT INTO machines (machine_id, machine_type) 
VALUES ('X12-001', 'X12');

INSERT INTO machine_state (machine_id)
VALUES ('NGG-001');

INSERT INTO machine_state (machine_id, part_number, next_item) 
VALUES ('X12-001', '05-0396M', '05-0486M');
