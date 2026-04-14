# Oracle JSON:  From relational to document store 


## Overview

This repository is a PL/SQL-focused Oracle JSON reference project. It walks through a progression of JSON features in Oracle Database, from basic JSON table design and querying to indexing, duality views, materialized views, partitioning, compression, and monitoring.

## This repository contains the following files
 

### `01. json-tables.sql`

Examples for creating JSON tables, including:

* JSON collection tables
* Tables with a JSON data type
* Autonomous AI JSON and Oracle Database 26ai examples

### `02. json-queries.sql`

SQL examples for querying JSON data, including:

* `JSON_VALUE`
* `JSON_EXISTS`
* `JSON_QUERY`
* `JSON_TABLE`
* Common table expression patterns for JSON queries

### `03. json-indexing.sql`

Examples showing how to improve JSON query performance with indexes, including:

* Unique indexes
* Composite indexes
* Search indexes
* Multivalue indexes
* Partial indexes
* Explain plans for indexed JSON queries

### `04. json-duality-views.sql`

Demonstrates Oracle JSON relational duality views with a customer / products / sales relational data model.

### `05. json-collection-views.sql`

Shows how to build relational views over JSON tables and how to work with JSON collection views using aggregations such as `SUM`, `AVG`, `GROUP BY`, and window functions.

### `06. json-materialized-views.sql`

Covers performance patterns with materialized views over JSON data, including:

* Materialized view usage
* Automatic query rewrite
* Aggregation support

### `07. json-dataguide.sql`

Demonstrates `JSON_DATAGUIDE` use cases, including:

* Creating relational views from JSON dataguides
* Projecting scalar fields using path expressions

### `08. json-partitioning.sql`

Examples for partitioning JSON collection tables.

### `09. json-compression.sql`

Demonstrates JSON collection table compression options, including:

* `COMPRESSION MEDIUM`
* `COMPRESSION HIGH`

### `10. json-monitoring.sql`

Shows how to monitor JSON queries using SQL Monitor reports and `DBMS_SQLDIAG`.

### `README.md`

High-level project documentation. It explains the repository theme, the feature areas covered, and links the examples together as a learning path.

### `LICENSE.txt`

Contains the Universal Permissive License (UPL), Version 1.0.

## Main Topics Covered with links to Oracle docs

* [Oracle JSON tables](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-in-oracle-database.html)
* [JSON querying](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/query-json-data.html)
* [JSON indexing](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/indexes-for-json-data.html)
* [Relational duality views](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-relational-duality-views.html)
* [JSON collection views](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-collection-views.html)
* [Materialized views on JSON data](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/materialized-views-json-data.html)
* [JSON dataguide](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-dataguide.html)
* [Partitioning JSON data](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/partitioning-json-data.html)
* [JSON compression](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/compression-json-data.html)
* [Query monitoring](https://docs.oracle.com/en/database/oracle/oracle-database/23/tgsql/monitoring-and-tuning-sql.html)

## Summary

This repository reads like a practical Oracle JSON workshop: each SQL file focuses on one feature area and builds a clear story around how JSON can be stored, queried, optimized, and monitored in Oracle Database.
