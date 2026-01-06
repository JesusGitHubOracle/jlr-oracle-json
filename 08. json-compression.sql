--- 3. Compression:

alter table PURCHASEORDERS compress for OLTP;

-- JSON collection tables (created with CREATE JSON COLLECTION TABLE) do not support changing compression afterward.
-- The compression must be specified at creation time.

-- STEP 1: Check current size of PURCHASEORDERS
SELECT segment_name, bytes/1024/1024 AS size_MB
FROM user_segments
WHERE segment_name = 'PURCHASEORDERS';

-- STEP 2: Create a compressed copy using COMPRESS MEDIUM
DROP TABLE if exists purchaseorders_compressed_medium PURGE;
DROP TABLE if exists purchaseorders_compressed_high PURGE;

CREATE JSON COLLECTION TABLE purchaseorders_compressed_medium JSON (data) STORE AS (COMPRESS MEDIUM);
CREATE JSON COLLECTION TABLE purchaseorders_compressed_high JSON (data) STORE AS (COMPRESS HIGH);

-- STEP 3: Copy data from original to compressed table
INSERT INTO purchaseorders_compressed_medium SELECT * FROM purchaseorders;
INSERT INTO purchaseorders_compressed_high SELECT * FROM purchaseorders;
COMMIT;

-- STEP 4: Gather statistics to ensure metadata is updated
BEGIN
  DBMS_STATS.gather_table_stats(USER, 'PURCHASEORDERS');
  DBMS_STATS.gather_table_stats(USER, 'PURCHASEORDERS_COMPRESSED_MEDIUM');
  DBMS_STATS.gather_table_stats(USER, 'PURCHASEORDERS_COMPRESSED_HIGH');
END;
/

-- STEP 5: Compare segment sizes
SELECT segment_name, bytes/1024/1024 AS size_MB
FROM user_segments
WHERE segment_name IN ('PURCHASEORDERS', 'PURCHASEORDERS_COMPRESSED_MEDIUM','PURCHASEORDERS_COMPRESSED_HIGH');

-- STEP 6: Optional - LOB compression info (more detailed)
SELECT table_name, compression, compress_for
FROM user_tables
WHERE table_name IN ('PURCHASEORDERS', 'PURCHASEORDERS_COMPRESSED_MEDIUM','PURCHASEORDERS_COMPRESSED_HIGH');
