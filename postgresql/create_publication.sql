-- convert WAL (write-ahead-log) to logical mode
-- to allow record detailed changes instead of
-- just physical blocks
ALTER SYSTEM SET wal_level = logical;

-- create a publication to allow Debezium to
-- capture changes from all tables in the database
-- FOR ALL TABLES means all current and future tables
-- in the database will be part of this publication
CREATE PUBLICATION dbz_publication FOR ALL TABLES;

-- grant ownership of the publication to user 'admin'
-- ensure that Debezium (which connects as 'admin')
-- has necessary permissions to access the publication
ALTER PUBLICATION dbz_publication OWNER TO admin;