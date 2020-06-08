# SEBMS-IPT-Convert-DDB
Convert SEBMS database to IPT format

´´´
CREATE DATABASE ipt_sebms;
´´´

sudo -u postgres psql ipt_sebms < ../../backup/SQL/2020-02-04.sebms.sql
sudo -u postgres psql ipt_sebms < script_views.sql


´´´
\c ipt_sebms
GRANT USAGE ON SCHEMA ipt_sebms TO ipt_sql_20;
GRANT SELECT ON ALL TABLES IN SCHEMA ipt_sebms TO ipt_sql_20 ;
´´´


sudo apt-get install postgis

´´´
\c sebms
CREATE EXTENSION postgis;
´´´
