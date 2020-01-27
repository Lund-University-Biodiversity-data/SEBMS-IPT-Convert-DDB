# SEBMS-IPT-Convert-DDB
Convert SEBMS database to IPT format




sudo apt-get install postgis

´´´
\c sebms
CREATE EXTENSION postgis;
´´´

sudo -u postgres psql sebms < script_views.sql 

´´´
\c ipt_sftstd
GRANT USAGE ON SCHEMA ipt_sftstd TO ipt_sql_20;
GRANT SELECT ON ALL TABLES IN SCHEMA ipt_sftstd TO ipt_sql_20 ;
´´´