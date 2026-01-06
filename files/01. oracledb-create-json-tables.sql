---------------------------------------------------------------------------
--  Oracle Database  (non-ADB)
--- Loading JSON Documents into Hybrid Tables using External Tables
---------------------------------------------------------------------------

-- Creating JSONORDERS database user (as system user on the PDB)
DROP USER JSON_ORDERS CASCADE;
CREATE USER JSON_ORDERS IDENTIFIED BY DB23ee###1234;

-- ADD ROLES
GRANT CONNECT, RESOURCE, SODA_APP TO JSON_ORDERS;
-- UNLIMITED QUOTA
ALTER USER JSON_ORDERS QUOTA UNLIMITED ON USERS;


--Create DIRECTORY(as system)
CREATE OR REPLACE DIRECTORY ORDER_ENTRY_DIR as '/home/oracle';
CREATE OR REPLACE DIRECTORY JSON_LOADER_OUTPUT as '/home/oracle';
GRANT READ ON DIRECTORY ORDER_ENTRY_DIR TO JSON_ORDERS;
GRANT WRITE ON DIRECTORY ORDER_ENTRY_DIR TO JSON_ORDERS;
GRANT READ  ON DIRECTORY JSON_LOADER_OUTPUT TO JSON_ORDERS;
GRANT WRITE ON DIRECTORY JSON_LOADER_OUTPUT TO JSON_ORDERS;


--------------------------------------------------------------------------- 
-- CREATE External tables (as JSON_ORDERS user)
-- ORACLE_LOADER and ORACLE_BIGDATA options
---------------------------------------------------------------------------
--  OPTION 1: CREATE External table with ORACLE_LOADER driver using dmp file containing JSON docs
DROP TABLE IF EXISTS json_dump_file_contents;
CREATE TABLE json_dump_file_contents (json_document  JSON)
  ORGANIZATION EXTERNAL
    (TYPE ORACLE_LOADER DEFAULT DIRECTORY order_entry_dir
                         ACCESS PARAMETERS
                           (RECORDS DELIMITED BY 0x'0A'
                            DISABLE_DIRECTORY_LINK_CHECK
                            BADFILE JSON_LOADER_OUTPUT: 'JSON_DUMPFILE_CONTENTS.bad'
                            LOGFILE JSON_LOADER_OUTPUT: 'JSON_DUMPFILE_CONTENTS.log'
                            FIELDS (json_document CHAR(5000)))
                         LOCATION (order_entry_dir:'purchaseorders.dmp'))
  PARALLEL
  REJECT LIMIT UNLIMITED;


-- OPTION 2.1 CREATE External table with ORACLE_BIGDATA driver using dmp containing JSON docs
DROP TABLE IF EXISTS json_file_contents CASCADE CONSTRAINTS; 
CREATE TABLE json_file_contents (DATA JSON)
    ORGANIZATION EXTERNAL
     (TYPE ORACLE_BIGDATA
      ACCESS PARAMETERS (com.oracle.bigdata.fileformat = jsondoc)
      LOCATION (order_entry_dir:'purchaseorders.dmp'))
    PARALLEL
   REJECT LIMIT UNLIMITED;


 
-- OPTION 2.2 CREATE External table with ORACLE_BIGDATA driver using dmp containing JSON docs ON Object Storage
-- Requires DBMS_CLOUD package - not available on regular DB
EXEC DBMS_CLOUD.create_credential(credential_name => 'ajd_cred_json_orders', username => 'JSON_ORDERS', password => '%1');
DROP TABLE IF EXISTS json_file_contents CASCADE CONSTRAINTS; 
CREATE TABLE json_file_contents (DATA JSON)
    ORGANIZATION EXTERNAL
     (TYPE ORACLE_BIGDATA
      ACCESS PARAMETERS (com.oracle.bigdata.fileformat = jsondoc
                         com.oracle.bigdata.credential.name = 'ajd_cred_json_orders'
       )
      LOCATION ('https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/je0hLEZ0hXdPWCgvoHdPs5UnVbbxG-jlIuEd0CU7sVqDBsgF8OPFbUFlMhkKewmb/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/PurchaseOrders.dmp'))
    PARALLEL
   REJECT LIMIT UNLIMITED;
 




---------------------------------------------------------------------------------------------------
-- Populating JSON TABLES  
---------------------------------------------------------------------------------------------------
-- Oracle Tables with JSON datatype columns - Hybrid Tables

-- Creating a Table With a JSON Column for JSON DATA
DROP TABLE IF EXISTS J_PURCHASEORDER CASCADE CONSTRAINTS;
CREATE TABLE J_PURCHASEORDER
  (id          VARCHAR2 (32) NOT NULL PRIMARY KEY,
   date_loaded TIMESTAMP (6) WITH TIME ZONE,
   po_document JSON);
   
-- populating  J_PURCHASEORDER
INSERT INTO J_PURCHASEORDER 
  SELECT SYS_GUID(), SYSTIMESTAMP, json_document
    FROM json_dump_file_contents;

COMMIT;

-- populating PurchaseOrders table
DROP TABLE IF EXISTS PURCHASEORDER   CASCADE CONSTRAINTS;
CREATE JSON COLLECTION TABLE PURCHASEORDERS;
INSERT INTO PURCHASEORDERS  
  SELECT json_document 
    FROM json_dump_file_contents;

COMMIT;
