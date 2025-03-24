# SEBMS-IPT-Convert-DDB
Convert SEBMS database to IPT format

´´´
DROP DATABASE ipt_sebms;
CREATE DATABASE ipt_sebms;
´´´

sudo -u postgres psql ipt_sebms < /home/mathieu/Downloads/2025-03-24.sebms/backup/SQL/2025-03-24.sebms.sql 
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



*** EXPORT

´´´
sudo -u postgres pg_dump ipt_sebms  > ipt_sebms_20250313.sql
tar cvzf ipt_sebms_20250313.sql.tar.gz ipt_sebms_20250313.sql
scp ipt_sebms_20250313.sql.tar.gz  canmoveapp@canmove-app.ekol.lu.se:/home/canmoveapp/script_IPT_database/saves/
´´´
then on canmoveapp
´´´
cd script_IPT_database/saves/
tar xvf ipt_sebms_20250313.sql.tar.gz
sudo -u postgres psql
DROP DATABASE ipt_sebms;
CREATE DATABASE ipt_sebms;
\q
sudo -u postgres psql ipt_sebms < ipt_sebms_20250313.sql
sudo -u postgres psql ipt_sebms
GRANT USAGE ON SCHEMA ipt_sebms TO ipt_sql_20;
GRANT SELECT ON ALL TABLES IN SCHEMA ipt_sebms TO ipt_sql_20 ;
\q


´´´


select COUNT(*) from ipt_sebms.ipt_sebms_sampling iss ;
select measurementType, count(*) from ipt_sebms.ipt_sebms_emof ise group by measurementType;
select COUNT(*) from ipt_sebms.ipt_sebms_occurrence iss ;


