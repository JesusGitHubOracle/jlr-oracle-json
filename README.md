# Oracle JSON Workshop

Practical SQL examples for working with JSON in Oracle Database and Autonomous AI JSON Database. The examples use a `PURCHASEORDERS` JSON collection table and progress from loading documents through querying, indexing, relational duality views, materialized views, partitioning, compression, monitoring, and IoT archival.

## Prerequisites

- Oracle Database release that supports the `JSON` data type and JSON collection tables. Several examples use current Oracle AI Database JSON features.
- A schema with the required privileges. Use one—and only one—of the setup scripts below.
- The `PurchaseOrders.dmp` source document file for self-managed database loading, or access to the PAR URL used by the Autonomous setup script.

## Getting started

1. Choose the setup script for your environment:
   - Autonomous AI JSON Database: [`01.json-ADB-user.sql`](01.json-ADB-user.sql)
   - Self-managed Oracle Database/PDB: [`01.json-DB-user.sql`](01.json-DB-user.sql)
2. Run the chosen script as its documented administrative user, then run its loading section as `JSON_ORDERS`. It creates and loads the `PURCHASEORDERS` JSON collection table.
3. Run the workshop scripts in numeric order as `JSON_ORDERS`, selecting only the features supported and licensed in your database environment.

## Files

| File | Description |
| --- | --- |
| [`01.json-ADB-user.sql`](01.json-ADB-user.sql) | Creates the `JSON_ORDERS` user on Autonomous AI JSON Database, grants JSON-related privileges, optionally enables ORDS, and loads `PURCHASEORDERS` from Oracle Cloud Object Storage. |
| [`01.json-DB-user.sql`](01.json-DB-user.sql) | Creates `JSON_ORDERS` for a self-managed Oracle Database PDB, configures a database directory, and loads `PURCHASEORDERS` from a local external JSON document file. |
| [`02. json-queries.sql`](02.%20json-queries.sql) | Introduces SQL/JSON query functions and conditions: `JSON_VALUE`, `JSON_EXISTS`, `JSON_QUERY`, and `JSON_TABLE`. |
| [`03. json-indexing.sql`](03.%20json-indexing.sql) | Creates and tests function-based, composite, JSON search, multivalue, and partial indexes; includes explain-plan examples. |
| [`04. json-duality-views.sql`](04.%20json-duality-views.sql) | Creates a JSON-relational duality view over the Sales History sample schema. |
| [`05. json-collection-views.sql`](05.%20json-collection-views.sql) | Builds relational and JSON collection views over purchase-order data, including aggregate and analytic examples. |
| [`06. json-materialized-views.sql`](06.%20json-materialized-views.sql) | Demonstrates JSON projections into materialized views, fast refresh, query rewrite, indexes, and line-item search patterns. |
| [`07. json-dataguide.sql`](07.%20json-dataguide.sql) | Generates and uses JSON data guides to derive relational views. |
| [`08. json-partitioning.sql`](08.%20json-partitioning.sql) | Partitions a JSON collection table by a generated purchase-order-number column and demonstrates partition pruning. |
| [`09. json-compression.sql`](09.%20json-compression.sql) | Compares `COMPRESS MEDIUM` and `COMPRESS HIGH` collection-table storage. |
| [`10. json-montoring.sql`](10.%20json-montoring.sql) | Shows SQL monitoring and `DBMS_SQLDIAG` examples, including monitoring SQL issued through the Oracle Database API for MongoDB. |
| [`11. iot-json-archiving.sql`](11.%20iot-json-archiving.sql) | Loads IoT JSON events and demonstrates hot/archive table patterns and time-based JSON processing. |
| [`11. sample_iot_events.json`](11.%20sample_iot_events.json) | Sample IoT event documents used by the archiving example. |
| [`json_orders.purchaseorders.json`](json_orders.purchaseorders.json) | Sample purchase-order JSON document data. |
| [`LICENSE.txt`](LICENSE.txt) | Universal Permissive License (UPL), Version 1.0. |

## Key concepts

- Native JSON storage with `JSON` columns and JSON collection tables
- SQL/JSON projection, filtering, and array expansion
- JSON function-based, search, multivalue, and partial indexes
- JSON-relational duality views and JSON collection views
- Materialized views and query rewrite over JSON data
- Data guides, partitioning, compression, SQL monitoring, and archival workflows

## Documentation

- [Oracle JSON in the database](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/json-in-oracle-database.html)
- [Query JSON data](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/query-json-data.html)
- [Index JSON data](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/overview-indexing-json-data.html)
- [JSON-relational duality views](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/json-relational-duality-views.html)
- [JSON data guides](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/json-dataguide.html)