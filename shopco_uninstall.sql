rem
rem shopco_uninstall.sql - Removes the SHOPCO practice schema.
rem Run as a privileged user (SYS AS SYSDBA, SYSTEM, ADMIN, etc.)
rem --------------------------------------------------------------------------

SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT Dropping user SHOPCO and all of its objects ...

DROP USER shopco CASCADE;

PROMPT SHOPCO schema has been removed.

exit
