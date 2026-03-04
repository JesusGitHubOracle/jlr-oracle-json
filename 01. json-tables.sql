
------------------------------------------------------------------------------------------------
-- CREATING and user on Autonomous JSON Database (AJD): 
-- Oracle Database API for MongoDB relies on Oracle Database users, privileges, and roles. 
-- The minimum Oracle Database roles required to use the API are CONNECT, RESOURCE, and SODA_APP. 
-- As user ADMIN on AJD
-------------------------------------------------------------------------------------------------
DROP USER IF EXISTS JSON_ORDERS CASCADE;
CREATE USER JSON_ORDERS IDENTIFIED BY DB23ee###1234;
-- ADD ROLES
GRANT CONNECT, RESOURCE, SODA_APP TO JSON_ORDERS;
-- QUOTA
ALTER USER JSON_ORDERS QUOTA UNLIMITED ON DATA;
-- Enabling ORDS
BEGIN
 ords_admin.enable_schema(
  p_enabled => TRUE,
  p_schema => 'JSON_ORDERS',
  p_url_mapping_pattern => 'JSON_ORDERS'
 );
 commit;
END;
/ 

----------------------------------------------------------------------------------------------------------------
----------------  Grants required to load JSON files from  Object Storage --------------------------------------
----------------------------------------------------------------------------------------------------------------
 GRANT EXECUTE on DBMS_CLOUD to JSON_ORDERS;
 GRANT READ,WRITE on DIRECTORY data_pump_dir to  JSON_ORDERS; 
---------------------------------------------------------------------------------------------------------------
-- as user JSON_ORDERS on AJD. Populating JSON Tables
-- 1. Creating a JSON COLLECTION TABLE table from a MongoDB export file on Object storage
-- 2. Creatign an Oracle Table with JSON datatype columns (Hybrid Tables)
---------------------------------------------------------------------------------------------------------------

--Create CREDENTIAL for DBMS_CLOUD access to Object Storage
EXEC DBMS_CLOUD.create_credential(credential_name => 'ajd_cred', username => 'JSON_ORDERS', password => 'DB23ee###1234');
DROP TABLE IF EXISTS PURCHASEORDERS CASCADE CONSTRAINTS; 
-- Create and Populate PURCHASEORDERS table from Object Storage
BEGIN
DBMS_CLOUD.copy_collection(collection_name => 'PURCHASEORDERS'
, credential_name => 'AJD_CRED'
, file_uri_list => 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/je0hLEZ0hXdPWCgvoHdPs5UnVbbxG-jlIuEd0CU7sVqDBsgF8OPFbUFlMhkKewmb/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/PurchaseOrders.dmp'
, format => json_object('recorddelimiter' value '''\n'''));
END;
/
 
-- 2: Oracle Tables with JSON datatype columns (Hybrid Tables)
-- Creating a Table With a JSON Column for JSON DATA
DROP TABLE IF EXISTS J_PURCHASEORDER CASCADE CONSTRAINTS;
CREATE TABLE J_PURCHASEORDER
  (id          VARCHAR2 (32) NOT NULL PRIMARY KEY,
   date_loaded TIMESTAMP (6) WITH TIME ZONE,
   po_document JSON);

-- Inserting a JSON document into the Hybrid table
INSERT INTO J_PURCHASEORDER
 SELECT SYS_GUID(),SYSTIMESTAMP,DATA FROM PURCHASEORDERS; 

-- Querying Hybrid Tables with dot.notation: Shipping instructions for PONumber=100
select id, date_loaded , po.po_document.ShippingInstructions from J_PURCHASEORDER po 
  where po.po_document.PONumber =100;

 
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
 