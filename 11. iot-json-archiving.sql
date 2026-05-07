


--------------------------------------------------------------------------------
-- 0)   credential for OCI Object Storage
--------------------------------------------------------------------------------
-- If you already created the credential, keep this section commented out.
-- BEGIN
--   DBMS_CLOUD.CREATE_CREDENTIAL(
--     credential_name => 'OCI_KEY_CRED_JSON_IOT',
--     username        => '<OCI_USERNAME>',
--     password        => '<OCI_AUTH_TOKEN>'
--   );
-- END;
-- /
 



--------------------------------------------------------------------------------
-- 1) Collection table (holds IoT daily data from external sources as JSON)
--------------------------------------------------------------------------------

DROP TABLE IF EXISTS iot_events CASCADE CONSTRAINTS PURGE;

CREATE JSON COLLECTION TABLE iot_events;

DECLARE 
base_URL VARCHAR2(200);
BEGIN
base_URL := 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/dICFYxDVG1BAne5AKbcBcLxaToe2Mb0mZ0M_BxmAUshwl9CwDk06bGV-5_6mD6Tf/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/iot-jdocs/sample_iot_events_10K.json';
   DBMS_CLOUD.COPY_COLLECTION(
       collection_name => 'iot_events',
       credential_name => 'OCI_KEY_CRED_JSON_IOT', 
       file_uri_list   => base_URL,
       format => json_object('recorddelimiter' value '''\n''')
 );
END;
 /

 -- iot events for 30 Jan 2025
SELECT c.data from iot_events c 
    WHERE json_value(c.data, '$.eventDate' RETURNING DATE) >= DATE '2025-01-30'
    AND json_value(c.data, '$.eventDate' RETURNING DATE) <  DATE '2025-01-31';

-----------------------------------------------------------------------------------------------------------------  
--  iot_events_hot_part:  Hot table for iot events
--  INTERVAL (NUMTODSINTERVAL(1, 'DAY')) means that after the initial partition, Oracle automatically 
--  creates new partitions in 1-day increments as new dates arrive.
-----------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS iot_events_hot_part CASCADE CONSTRAINTS PURGE;
 
CREATE TABLE iot_events_hot_part (
  document_id   VARCHAR2(20) NOT NULL,
  payload       VARCHAR2(4000) NOT NULL,
  CONSTRAINT ensure_is_json CHECK (payload is json),
  event_date_vc DATE
    GENERATED ALWAYS AS (
      json_value(payload, '$.eventDate' RETURNING DATE ERROR ON ERROR)
    ) VIRTUAL
)
PARTITION BY RANGE (event_date_vc)
INTERVAL (NUMTODSINTERVAL(1, 'DAY'))
(
  PARTITION p_before_2025 VALUES LESS THAN (DATE '2025-01-01')
);
-----------------------------------------------------------------------------------------------------------------  
--  populate the hot table with data from the collection table.
-- (In a real scenario, this would be done through an automated process as data arrives),
-----------------------------------------------------------------------------------------------------------------  
 INSERT  /*+ PARALLEL */ INTO  iot_events_hot_part
    (
    document_id,
    payload
    )    
  SELECT
   json_value(c.data, '$.documentId' RETURNING VARCHAR2(20)  ERROR ON ERROR),
   c.data
  FROM iot_events c;


-- Check that the data is correctly partitioned by event date. 
 
 
 SELECT * FROM iot_events_hot_part
 WHERE event_date_vc >= DATE '2025-01-30'
   AND event_date_vc <  DATE '2025-01-31';



-- PARTITION DETAILS (32 partitions expected, one per day for the month of January 2025 plus the default partition for any data before 2025):

select partition_name, high_value 
from user_tab_partitions where table_name = 'IOT_EVENTS_HOT_PART';
 
 "PARTITION_NAME"	"HIGH_VALUE"
"P_BEFORE_2025"	"TO_DATE(' 2025-01-01 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17699"	"TO_DATE(' 2025-01-17 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17700"	"TO_DATE(' 2025-01-08 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17701"	"TO_DATE(' 2025-02-01 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17702"	"TO_DATE(' 2025-01-06 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17703"	"TO_DATE(' 2025-01-30 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17704"	"TO_DATE(' 2025-01-21 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17705"	"TO_DATE(' 2025-01-19 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17706"	"TO_DATE(' 2025-01-11 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17707"	"TO_DATE(' 2025-01-28 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17708"	"TO_DATE(' 2025-01-23 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17709"	"TO_DATE(' 2025-01-02 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17710"	"TO_DATE(' 2025-01-07 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17711"	"TO_DATE(' 2025-01-12 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17712"	"TO_DATE(' 2025-01-29 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17713"	"TO_DATE(' 2025-01-14 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17714"	"TO_DATE(' 2025-01-22 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17715"	"TO_DATE(' 2025-01-27 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17716"	"TO_DATE(' 2025-01-09 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17717"	"TO_DATE(' 2025-01-18 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17718"	"TO_DATE(' 2025-01-24 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17719"	"TO_DATE(' 2025-01-16 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17720"	"TO_DATE(' 2025-01-25 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17721"	"TO_DATE(' 2025-01-26 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17722"	"TO_DATE(' 2025-01-05 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17723"	"TO_DATE(' 2025-01-10 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17724"	"TO_DATE(' 2025-01-31 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17725"	"TO_DATE(' 2025-01-15 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17726"	"TO_DATE(' 2025-01-04 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17727"	"TO_DATE(' 2025-01-03 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17728"	"TO_DATE(' 2025-01-13 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"
"SYS_P17729"	"TO_DATE(' 2025-01-20 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')"

 */
---------------------------------------------------------------------------------------------------------------------------
-- Archiving data for specific days (e.g. 01,02,03 Jan 2025) to Object Storage in JSON format using DBMS_CLOUD.EXPORT_DATA.
---------------------------------------------------------------------------------------------------------------------------
DECLARE 
part_URL VARCHAR2(4000);
BEGIN
  part_URL := 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/dICFYxDVG1BAne5AKbcBcLxaToe2Mb0mZ0M_BxmAUshwl9CwDk06bGV-5_6mD6Tf/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/iot-jdocs/archive/year=2025/month=01';
  DBMS_CLOUD.EXPORT_DATA(
    credential_name => 'OCI_KEY_CRED_JSON_IOT',
    file_uri_list    => part_URL || '/day=01/2025-01-01_events.json',
    query            => q'[
                            SELECT  
                                  payload
                                  FROM iot_events_hot_part c
                              WHERE event_date_vc >= DATE '2025-01-01'
                              AND event_date_vc <  DATE '2025-01-02'
                          ]',
   format          => JSON_OBJECT('type' VALUE 'json')
  );
END;
/

DECLARE 
part_URL VARCHAR2(4000);
BEGIN
  part_URL := 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/dICFYxDVG1BAne5AKbcBcLxaToe2Mb0mZ0M_BxmAUshwl9CwDk06bGV-5_6mD6Tf/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/iot-jdocs/archive/year=2025/month=01';
  DBMS_CLOUD.EXPORT_DATA(
    credential_name => 'OCI_KEY_CRED_JSON_IOT',
    file_uri_list    => part_URL || '/day=02/2025-01-02_events.json',
    query            => q'[
                            SELECT  
                                  payload
                                  FROM iot_events_hot_part c
                              WHERE event_date_vc >= DATE '2025-01-02'
                              AND event_date_vc <  DATE '2025-01-03'
                          ]',
   format          => JSON_OBJECT('type' VALUE 'json')
  );
END;
/

DECLARE 
part_URL VARCHAR2(4000);
BEGIN
  part_URL := 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/dICFYxDVG1BAne5AKbcBcLxaToe2Mb0mZ0M_BxmAUshwl9CwDk06bGV-5_6mD6Tf/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/iot-jdocs/archive/year=2025/month=01';
  DBMS_CLOUD.EXPORT_DATA(
    credential_name => 'OCI_KEY_CRED_JSON_IOT',
    file_uri_list    => part_URL || '/day=03/2025-01-03_events.json',
    query            => q'[
      SELECT  
            payload
            FROM iot_events_hot_part c
        WHERE event_date_vc >= DATE '2025-01-03'
        AND event_date_vc <  DATE '2025-01-04'
    ]',
   format          => JSON_OBJECT('type' VALUE 'json')
  );
END;
/

---------------------------------------------------------------------------------------------------------------------------------------------------------
-- Check Object Storage to confirm that the file has been created with the expected data.
-- USE: oci os object list -bn bucket-for-ajd-data --prefix "iot-jdocs/archive/year=2025/month=01/day=01/
/* 
{
  "data": [
    {
      "archival-state": null,
      "etag": "479fcc43-fbd4-43d9-87ec-1c1c4cb235a9",
      "md5": "G99vmP4cu9ivrVnRH4e/4w==",
      "name": "iot-jdocs/archive/year=2025/month=01/day=01/2025-01-01_events.json",
      "size": 239343,
      "storage-tier": "Standard",
      "time-created": "2026-05-06T10:26:56.240000+00:00",
      "time-modified": "2026-05-06T10:38:35.510000+00:00"
    },
...............................
*/
---------------------------------------------------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------------------------------------------------
--- external tables on top of the exported JSON files in Object Storage to enable querying the archived data without having to load it back into the database
-------------------------------------------------------------------------------------------------------------------------------------------------------------
drop table iot_events_archive_ext_2025_01_01 purge;
drop table iot_events_archive_ext_2025_01_02 purge;
drop table iot_events_archive_ext_2025_01_03 purge; 

 
DECLARE 
part_URL VARCHAR2(4000);
BEGIN
 part_URL := 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/dICFYxDVG1BAne5AKbcBcLxaToe2Mb0mZ0M_BxmAUshwl9CwDk06bGV-5_6mD6Tf/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/iot-jdocs/archive/year=2025/month=01';
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'iot_events_archive_ext_2025_01_01',
    credential_name => 'OCI_KEY_CRED_JSON_IOT',
    file_uri_list   => part_URL || '/day=01/2025-01-01_events.json',
    format          => JSON_OBJECT('type' VALUE 'jsondoc')
  );
END;
/
DECLARE 
part_URL VARCHAR2(4000);
BEGIN
 part_URL := 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/dICFYxDVG1BAne5AKbcBcLxaToe2Mb0mZ0M_BxmAUshwl9CwDk06bGV-5_6mD6Tf/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/iot-jdocs/archive/year=2025/month=01';
 DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'iot_events_archive_ext_2025_01_02',
    credential_name => 'OCI_KEY_CRED_JSON_IOT',
    file_uri_list   => part_URL || '/day=02/2025-01-02_events.json',
    format          => JSON_OBJECT('type' VALUE 'jsondoc')
  );
END;
/ 
DECLARE 
part_URL VARCHAR2(4000);
BEGIN
  part_URL := 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/dICFYxDVG1BAne5AKbcBcLxaToe2Mb0mZ0M_BxmAUshwl9CwDk06bGV-5_6mD6Tf/n/fro8fl9kuqli/b/bucket-for-ajd-data/o/iot-jdocs/archive/year=2025/month=01'; 
 
  DBMS_CLOUD.CREATE_EXTERNAL_TABLE(
    table_name      => 'iot_events_archive_ext_2025_01_03',
    credential_name => 'OCI_KEY_CRED_JSON_IOT',
    file_uri_list   => part_URL || '/day=03/2025-01-03_events.json',
    format          => JSON_OBJECT('type' VALUE 'jsondoc')
  );
END;
/

SELECT * FROM iot_events_archive_ext_2025_01_01;
SELECT * FROM iot_events_archive_ext_2025_01_02;
SELECT * FROM iot_events_archive_ext_2025_01_03;

---------------------------------------------------------------------------------------------------------------------------------------------------------
-- Drop partitions in the hot table to simulate data aging and force queries to access the archived data in Object Storage through the external tables.
---------------------------------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE iot_events_hot_part
DROP PARTITION FOR (DATE '2025-01-01')
UPDATE INDEXES;

ALTER TABLE iot_events_hot_part
DROP PARTITION FOR (DATE '2025-01-02')
UPDATE INDEXES;

ALTER TABLE iot_events_hot_part
DROP PARTITION FOR (DATE '2025-01-03')
UPDATE INDEXES;

 -- 29 Partitions (32 - 3 dropped) should remain in the hot table after dropping the 3 partitions for 01,02,03 Jan 2025:
SELECT  COUNT(partition_name) 
from user_tab_partitions 
where table_name = 'IOT_EVENTS_HOT_PART';

---------------------------------------------------------------------------------------------------------------------------------------------------------
-- cold view to query archived data across multiple files/partitions in Object Storage
---------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW iot_events_cold_v AS
SELECT data FROM iot_events_archive_ext_2025_01_01
UNION ALL
SELECT data FROM iot_events_archive_ext_2025_01_02
UNION ALL
SELECT data FROM iot_events_archive_ext_2025_01_03;

SELECT * FROM iot_events_cold_v;

---------------------------------------------------------------------------------------------------------------------------------------------------------
-- hot + cold view to query all data together (with an additional column to indicate the data tier)
---------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW iot_events_all_v AS
SELECT
    h.document_id,
    h.event_date_vc AS event_date,
    h.payload,
    'HOT' AS data_tier
FROM iot_events_hot_part h

UNION ALL

SELECT
    json_value(c.data, '$.documentId' RETURNING VARCHAR2(20) ERROR ON ERROR) AS document_id,
    json_value(c.data, '$.eventDate'  RETURNING DATE ERROR ON ERROR)          AS event_date,
    JSON_SERIALIZE(c.data) AS payload,
    'COLD' AS data_tier
FROM iot_events_cold_v c;

SELECT * FROM iot_events_all_v;
 
