
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
----------------  Grants required to load JSON files from  Object Storage ----------------------------------
----------------------------------------------------------------------------------------------------------------
 GRANT EXECUTE on DBMS_CLOUD to JSON_ORDERS;
 GRANT READ,WRITE on DIRECTORY data_pump_dir to  JSON_ORDERS; 


---------------------------------------------------------------------------------------------------------------
-- as user JSON_ORDERS on AJD. Populating JSON Tables
-- 1. Creating a JSON COLLECTION TABLE table from a MongoDB export file on Object storage
-- 2. Creatign an Oracle Table with JSON datatype columns (Hybrid Tables)
-- 3. Creating a SODA Collection and Inserting JSON Documents
---------------------------------------------------------------------------------------------------------------
--Create CREDENTIAL for DBMS_CLOUD access to Object Storage
EXEC DBMS_CLOUD.create_credential(credential_name => 'ajd_cred', username => 'JSON_ORDERS', password => 'DB23ee###1234');
DROP TABLE IF EXISTS PURCHASEORDERS CASCADE CONSTRAINTS; 
-- Creates and Populates PURCHASEORDERS table from Object Storage
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

-- 3. Creating a SODA Collection and Inserting JSON Documents.
DECLARE
  l_OWNER                 DBMS_QUOTED_ID := '"JSON_ORDERS"';
  l_SCHEMA                DBMS_QUOTED_ID := '"JSON_ORDERS"';
  l_CREDENTIAL_NAME       DBMS_QUOTED_ID := null;
  l_FORMAT                CLOB :=
    '{
       "characterset" : "AL32UTF8",
       "ignoreblanklines" : "true",
       "rejectlimit" : "10000",
       "unpackarrays" : "true",
       "maxdocsize" : 33554432
     }';
  l_FILE_URI_LIST         CLOB :=
    q'[https://fro8fl9kuqli.objectstorage.eu-frankfurt-1.oci.customer-oci.com/p/WfkW_bZlb8Epg7N4CSSuFafNAfdJtfukGKSc40kDgXI6eyUBp-aNoSo5XOs31bGG/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/PurchaseOrders.dmp]';
  l_COLNAME_LIST          CLOB := null;
  l_COLLECTION_NAME       DBMS_ID := 'PURCHASEORDERS_SODA';
  l_COLLECTION_NAME_EQN   DBMS_QUOTED_ID := '"PURCHASEORDERS_SODA"';
  l_VIEW_NAME             DBMS_ID := null;
  l_OPERATION_ID          NUMBER ;
  l_CUR_COLLECTION        SYS.SODA_COLLECTION_T := null;

  l_STATUS                NUMBER;
  l_SQL_STMT              CLOB;
  l_COLLECTION_CREATED    BOOLEAN := false;
  l_VIEW_CREATED          BOOLEAN := false;

BEGIN
  l_CUR_COLLECTION := SYS.DBMS_SODA.CREATE_COLLECTION(l_COLLECTION_NAME);
  l_COLLECTION_CREATED := true;

  C##CLOUD$SERVICE.DBMS_CLOUD.COPY_COLLECTION
  ( COLLECTION_NAME     =>   l_COLLECTION_NAME
   ,CREDENTIAL_NAME     =>   l_CREDENTIAL_NAME
   ,FILE_URI_LIST       =>   l_FILE_URI_LIST
   ,FORMAT              =>   l_FORMAT
   ,OPERATION_ID        =>   l_OPERATION_ID
  );

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    if l_COLLECTION_CREATED THEN
      l_STATUS := SYS.DBMS_SODA.DROP_COLLECTION(l_COLLECTION_NAME, TRUE, TRUE);
    END IF;

    ROLLBACK;
    RAISE;
END;
/
/* PURCHASE_ORDERS DDL */
CREATE TABLE "JSON_ORDERS"."PURCHASEORDERS" 
   (	"ID" VARCHAR2(255) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
	"CREATED_ON" TIMESTAMP (6) DEFAULT sys_extract_utc(SYSTIMESTAMP) NOT NULL ENABLE, 
	"LAST_MODIFIED" TIMESTAMP (6) DEFAULT sys_extract_utc(SYSTIMESTAMP) NOT NULL ENABLE, 
	"VERSION" VARCHAR2(255) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
	"JSON_DOCUMENT" BLOB, 
	 CHECK ("JSON_DOCUMENT" is json format oson (size limit 32m)) ENABLE, 
	 PRIMARY KEY ("ID")
  USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "DATA"  ENABLE
   )  DEFAULT COLLATION "USING_NLS_COMP" SEGMENT CREATION IMMEDIATE 
  PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
 NOCOMPRESS LOGGING
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "DATA" 
 LOB ("JSON_DOCUMENT") STORE AS SECUREFILE (
  TABLESPACE "DATA" ENABLE STORAGE IN ROW CHUNK 8192
  CACHE  NOCOMPRESS  KEEP_DUPLICATES 
  STORAGE(INITIAL 106496 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)) ;