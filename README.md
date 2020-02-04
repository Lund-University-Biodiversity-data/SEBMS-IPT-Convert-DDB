# SEBMS-IPT-Convert-DDB
Convert SEBMS database to IPT format




sudo apt-get install postgis

´´´
\c sebms
CREATE EXTENSION postgis;
´´´

sudo -u postgres psql sebms < script_views.sql 

´´´
\c sebms
GRANT USAGE ON SCHEMA ipt_sebms TO ipt_sql_20;
GRANT SELECT ON ALL TABLES IN SCHEMA ipt_sebms TO ipt_sql_20 ;
´´´