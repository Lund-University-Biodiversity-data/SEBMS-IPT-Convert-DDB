# SEBMS-IPT-Convert-DDB
Convert SEBMS database to IPT format

´´´
DROP DATABASE ipt_sebms;
CREATE DATABASE ipt_sebms;
´´´

sudo -u postgres psql ipt_sebms < /home/mathieu/Downloads/2024-07-09.sebms/backup/SQL/2024-07-09.sebms.sql 
sudo -u postgres psql ipt_sebms < sebms_annex_create_nat_stn_reg.sql
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



select COUNT(*) from ipt_sebms.ipt_sebms_sampling iss ;
select measurementType, count(*) from ipt_sebms.ipt_sebms_emof ise group by measurementType;
select COUNT(*) from ipt_sebms.ipt_sebms_occurrence iss ;


