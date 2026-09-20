rem
rem shopco_install.sql - Main installation script for the SHOPCO practice
rem schema (a customer_orders-style sample schema, expanded with
rem categories, suppliers, employees and payments for classroom use).
rem
rem This script deliberately avoids anonymous PL/SQL validation blocks in
rem the interactive prompts (unlike the official Oracle sample-schema
rem installers), because those can fail with PLS-00201 on some PDBs where
rem the STANDARD package cannot be resolved cleanly in the SYS session.
rem Instead, validation relies on native Oracle errors (e.g. CREATE USER
rem failing on an empty password), which are just as safe and easier to
rem diagnose.
rem
rem INSTALL INSTRUCTIONS
rem   1. Run as a privileged user with rights to create/drop another user
rem      (SYS AS SYSDBA, SYSTEM, ADMIN, etc.)
rem   2. Run this script: @shopco_install.sql
rem   3. You are prompted for:
rem      a. password - enter an Oracle Database compliant password
rem      b. tablespace - press Enter to accept the database default
rem      c. connect identifier - the SAME one you used to connect as the
rem         privileged user just now (e.g. pdb_lima, or //host:1521/service).
rem         This is needed so the script can reconnect you as SHOPCO at
rem         the end.
rem   4. At the end, the script automatically reconnects your session as
rem      SHOPCO (instead of just disconnecting), so you land directly at
rem      a SQL prompt in the right schema and can start querying right
rem      away - no need to remember to switch schema/user yourself.
rem
rem UNINSTALL INSTRUCTIONS
rem   Run shopco_uninstall.sql as a privileged user.
rem --------------------------------------------------------------------------

SET ECHO OFF
SET VERIFY OFF
SET HEADING OFF
SET FEEDBACK OFF

WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT
PROMPT Thank you for installing the SHOPCO practice schema.
PROMPT If any error is encountered, this script will exit your database
PROMPT session immediately. Otherwise, at the end it will reconnect you
PROMPT as the SHOPCO user so you can start querying right away.
PROMPT The entire installation will be logged into the 'shopco_install.log' file.
PROMPT

SPOOL shopco_install.log

rem =======================================================
rem Accept schema password (validated natively by CREATE USER below,
rem no PL/SQL block involved)
rem =======================================================

rem Tip: avoid '@', '/' and spaces in the password - it gets reused
rem unquoted in the CONNECT command at the end of this script.
ACCEPT pass PROMPT 'Enter a password for the user SHOPCO (avoid @ / and spaces): ' HIDE

rem =======================================================
rem Accept tablespace name (defaults to the database default)
rem =======================================================

COLUMN property_value NEW_VALUE var_default_tablespace NOPRINT
SELECT property_value FROM database_properties WHERE property_name = 'DEFAULT_PERMANENT_TABLESPACE';

ACCEPT tbs PROMPT 'Enter a tablespace for SHOPCO [&var_default_tablespace]: ' DEFAULT '&var_default_tablespace'

rem =======================================================
rem Accept the connect identifier, so the script can reconnect you as
rem SHOPCO at the end. Use the SAME one you used to connect just now
rem (whatever came after the @ when you started sqlplus).
rem =======================================================

ACCEPT conn_id PROMPT 'Enter the connect identifier to reach this database (e.g. pdb_lima or //host:1521/service): '

rem =======================================================
rem Drop the SHOPCO user if it already exists, then recreate it.
rem This makes the install idempotent without needing a PL/SQL check.
rem ORA-01918 (user does not exist) is expected and safely ignored here.
rem =======================================================

WHENEVER SQLERROR CONTINUE
DROP USER shopco CASCADE;
WHENEVER SQLERROR EXIT SQL.SQLCODE

rem =======================================================
rem create the SHOPCO schema user
rem =======================================================

CREATE USER shopco IDENTIFIED BY "&pass"
                    DEFAULT TABLESPACE &tbs
                    QUOTA UNLIMITED ON &tbs;

GRANT CREATE MATERIALIZED VIEW,
      CREATE PROCEDURE,
      CREATE SEQUENCE,
      CREATE SESSION,
      CREATE SYNONYM,
      CREATE TABLE,
      CREATE TRIGGER,
      CREATE TYPE,
      CREATE VIEW
  TO shopco;

ALTER SESSION SET CURRENT_SCHEMA=SHOPCO;
ALTER SESSION SET NLS_LANGUAGE=American;
ALTER SESSION SET NLS_TERRITORY=America;

rem =======================================================
rem create SHOPCO schema objects
rem =======================================================

@@shopco_create.sql

rem =======================================================
rem populate tables with data
rem =======================================================

@@shopco_populate.sql

rem shopco_populate.sql turns substitution OFF (needed while inserting
rem text that may contain literal '&' characters). Turn it back ON here,
rem otherwise &pass and &conn_id below won't be substituted.
SET DEFINE ON

rem =======================================================
rem installation validation
rem =======================================================

SET HEADING ON
SET FEEDBACK OFF

SELECT 'Verification:' AS "Installation verification" FROM dual;

SELECT 'categories' AS "Table", count(1) AS "actual" FROM shopco.categories
UNION ALL
SELECT 'suppliers', count(1) FROM shopco.suppliers
UNION ALL
SELECT 'customers', count(1) FROM shopco.customers
UNION ALL
SELECT 'stores', count(1) FROM shopco.stores
UNION ALL
SELECT 'employees', count(1) FROM shopco.employees
UNION ALL
SELECT 'products', count(1) FROM shopco.products
UNION ALL
SELECT 'reviews', count(1) FROM shopco.reviews
UNION ALL
SELECT 'product_suppliers', count(1) FROM shopco.product_suppliers
UNION ALL
SELECT 'orders', count(1) FROM shopco.orders
UNION ALL
SELECT 'order_items', count(1) FROM shopco.order_items
UNION ALL
SELECT 'shipments', count(1) FROM shopco.shipments
UNION ALL
SELECT 'inventory', count(1) FROM shopco.inventory
UNION ALL
SELECT 'payments', count(1) FROM shopco.payments;

SELECT 'The installation of the SHOPCO practice schema is now finished.' AS "Thank you!" FROM dual
UNION ALL
SELECT 'Please check the installation verification output above.' FROM dual
UNION ALL
SELECT '' FROM dual
UNION ALL
SELECT 'Reconnecting your session as SHOPCO so you can start querying...' FROM dual;

spool off

rem =======================================================
rem Reconnect as SHOPCO instead of disconnecting. This is the fix for
rem the "table or view does not exist" confusion you get when you stay
rem connected as SYS/SYSTEM (current_schema doesn't match) and then run
rem an unqualified SELECT. From here on you're simply SHOPCO, so
rem SELECT * FROM suppliers; (and any other table) resolves normally.
rem =======================================================

CONNECT shopco/&pass@&conn_id

SET HEADING OFF
PROMPT
PROMPT You are now connected as SHOPCO. Try, for example:
PROMPT   SELECT * FROM suppliers;
PROMPT   SELECT table_name FROM user_tables ORDER BY table_name;
PROMPT
