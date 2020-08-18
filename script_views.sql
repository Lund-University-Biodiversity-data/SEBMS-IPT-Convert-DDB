\c ipt_sebms

DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_EMOF;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_OCCURENCE;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_SAMPLING;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES;

DROP SCHEMA IF EXISTS IPT_SEBMS;
CREATE SCHEMA IPT_SEBMS;

/* HIDDEN SPECIES */
CREATE VIEW IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES AS
SELECT * FROM spe_species
WHERE spe_dyntaxa in (101510); /* mnemosyne */


/*
The dates are stored in the database with the timezones. Example : 2009-05-17 10:15:00+02
The IPT tool converts them to UTC: 2009-05-17 08:15:00+00


SAMPLING EVENTS
To be fixed:
 - locationID : LATER ON maybe stationsregistret ??
 - informationWithheld : mention the protected species ? @Annelie

Constants:
 - list of datasources VIS.vis_typ_datasourceid 
 - geoCodes 3021/4326 => create a function with parameter ?
 - diffusion 1000     => create a function with parameter ?
*/

CREATE VIEW IPT_SEBMS.IPT_SEBMS_SAMPLING AS
SELECT DISTINCT VIS.vis_uid,
CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
'https://www.dagfjarilar.lu.se/hur-gor-man/viktiga-filer#handledning' AS samplingProtocol,
CAST(VIS.vis_begintime as date) AS eventDate,  
EXTRACT (doy from  VIS.vis_begintime) AS startDayOfYear,
EXTRACT (doy from  VIS.vis_endtime) AS endDayOfYear,
CASE 
	WHEN VIS.vis_begintime=VIS.vis_endtime THEN right(CAST(VIS.vis_begintime as TEXT), length(CAST(VIS.vis_begintime as TEXT)) - 11) 
	ELSE CONCAT(right(CAST(VIS.vis_begintime as TEXT), length(CAST(VIS.vis_begintime as TEXT)) - 11) ,'/',right(CAST(VIS.vis_endtime as TEXT), length(CAST(VIS.vis_endtime as TEXT)) - 11) ) 
END AS eventTime,
CONCAT('SEBMS',':siteId:',SIT.sit_uid) AS locationID, 
REG_COU.reg_name AS county,
REG_PRO.reg_name AS province,
REG_MUN.reg_name AS municipality,
'WGS84' AS geodeticDatum,
ST_Y(ST_Transform(ST_SetSRID(ST_Point(RT90_lon_diffusion, RT90_lat_diffusion), 3021), 4326)) AS decimalLatitude,
ST_X(ST_Transform(ST_SetSRID(ST_Point(RT90_lon_diffusion, RT90_lat_diffusion), 3021), 4326)) AS decimalLongitude,
'SE' AS countryCode,
'EUROPE' AS continent,
CASE 
	WHEN SIT.sit_type='T' then 1000 
	WHEN SIT.sit_type='P' then 25 
END AS coordinateUncertaintyInMeters,
NOW() AS modified,
SIT.sit_name AS locality
FROM spe_species SPE, obs_observation OBS, seg_segment SEG, vis_visit VIS,
(
	SELECT sit_uid, sit_geort90lat AS RT90_lat_diffusion,
	sit_geort90lon AS RT90_lon_diffusion
	FROM sit_site	
) as ROUNDED_sites,
sit_site SIT left join reg_region REG_MUN on REG_MUN.reg_uid = sit_reg_municipalityid
left join reg_region REG_COU on REG_COU.reg_uid = sit_reg_countyid
left join reg_region REG_PRO on REG_PRO.reg_uid = sit_reg_provinceid
WHERE ROUNDED_sites.sit_uid=SIT.sit_uid
AND OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54)
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT NULL
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H)
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= 2018
ORDER BY eventID;

/* to create a diffusion of 1km:
	SELECT sit_uid, ROUND(sit_geort90lat/1000)*1000 AS RT90_lat_diffusion,
	ROUND(sit_geort90lon/1000)*1000 AS RT90_lon_diffusion
	FROM sit_site

*/


/*
VISIT PARTICPANTS AGGREGATES IN ONE FILED
*/
CREATE VIEW IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS AS
select vip_vis_visitid, string_agg(DISTINCT cast(vip_per_participantid as text), '|') AS participantsList
FROM vip_visitparticipant 
GROUP by vip_vis_visitid;




/* WARNING : VIsits without any participant => 69 rows
select distinct(vis_uid)
FROM vis_visit
where vis_uid not in (select distinct vip_vis_visitid from vip_visitparticipant)
*/

/* 
OCCURENCES

To be fixed:
 - locationID : LATER ON maybe stationsregistret ??
 - informationWithheld : mention the protected species ? 

AS recordedBy,  liste potentielle !! => LEFT JOIN avec visitParticipant pas suffisant ??. Séparer les IDs de participants avec des | 

speciesAggregate => spe_semainname that contains / (except 180 => family because no genusname)
*/

CREATE VIEW IPT_SEBMS.IPT_SEBMS_OCCURENCE AS
SELECT 
CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
CONCAT('SEBMS',':',VIS.vis_uid,':',SPE.spe_dyntaxa) AS occurenceID, 
'HumanObservation' AS basisOfRecord,
CASE 
	WHEN spe_uid=143 THEN 'order' 
	WHEN spe_uid IN (131, 132, 133, 134, 137, 139, 172, 175, 181, 183, 184) THEN 'speciesAggregate' 
	WHEN (spe_genusname='' or spe_genusname is NULL) THEN 'family' 
	ELSE 'species' 
END AS taxonRank, 
'Animalia' AS kingdom,
SUM(OBS.obs_count) AS individualCount, /* SUM per site !!!  ***/
CONCAT('urn:lsid:dyntaxa.se:Taxon:',SPE.spe_dyntaxa) AS taxonID,
CONCAT('urn:lsid:dyntaxa.se:Taxon:',SPE.spe_dyntaxa) AS taxonConceptID,
CONCAT(SPE.spe_genusname, ' ', SPE.spe_speciesname) AS scientificName,
SPE.spe_originalnameusage AS originalNameUsage,
SPE.spe_higherclassification AS higherClassification,
SPE.spe_familyname AS family,
CASE 
	WHEN SIT.sit_type='T' then 'The number of individuals observed is the sum total from all the segments of the transect site. More information can be obtained from the Data Provider.' 
	else 'More information can be obtained from the Data Provider.'
END AS informationWithheld,
CONCAT('SEBMS:recorderId:',VP.participantsList) as recordedBy,
'Validated' as identificationVerificationStatus,
'Occurence' as type,
'English' as language,
'Free usage' as accessRights,
'Presence' as occurrenceStatus,
SPE.spe_semainname as vernacularName,
'Lund University' AS institutionCode,
'SEBMS' AS collectionCode,
CONCAT('SEBMS:datasetID:LU') AS datasetID
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
LEFT JOIN IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS VP on VIS.vis_uid=VP.vip_vis_visitid
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H)
AND OBS.obs_count>0
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= 2018
GROUP BY eventID, occurenceID, spe_uid, sit_type, recordedBy;

/*
// hide the species to protect
TO BE added
AND spe_isconfidential = false
*/

/*
CREATE VIEW IPT_SEBMS.IPT_SEBMS_TAXON AS
SELECT spe_dyntaxa AS taxonID, spe_familyname AS scientificName, 'species' AS taxonRank, '' AS kingdom, '' AS parentNameUsageID, "" AS acceptedNameUsageID
FROM spe_species
WHERE 1; 
*/


/* EMOF */
/*
To be fixed:
 - convert angular degrees to cardinal points

*/

CREATE VIEW IPT_SEBMS.IPT_SEBMS_EMOF AS
SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
'Site type' AS measurementType,
CASE WHEN SIT.sit_type='P' THEN 'Point site' WHEN SIT.sit_type='T' THEN 'Transect site' END AS measurementValue,
'' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H)
AND SIT.sit_type IS NOT NULL
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= 2018
UNION
SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
'Sunshine' AS measurementType,
CAST(VIS.vis_sunshine AS text) AS measurementValue,
'%' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_sunshine IS NOT NULL
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= 2018
UNION
SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
'Temperature' AS measurementType,
CAST(VIS.vis_temperature AS text) AS measurementValue,
'°C' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_temperature IS NOT NULL
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= 2018
UNION
SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
'Wind direction' AS measurementType,
CAST(VIS.vis_winddirection AS text) AS measurementValue,
'angular degrees' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_winddirection IS NOT NULL
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= 2018
UNION
SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
'Wind Speed' AS measurementType,
CAST(VIS.vis_windspeed AS text) AS measurementValue,
'm/s' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_windspeed IS NOT NULL
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= 2018
UNION
SELECT
eventID, 
'ZeroObservation' AS measurementType,
'true' AS measurementValue,
'' AS measurementUnit
FROM IPT_SEBMS.IPT_SEBMS_SAMPLING SA
WHERE  eventID NOT IN (SELECT DISTINCT eventID FROM IPT_SEBMS.IPT_SEBMS_OCCURENCE)
UNION
SELECT
eventID, 
'ZeroObservation' AS measurementType,
'false' AS measurementValue,
'' AS measurementUnit
FROM IPT_SEBMS.IPT_SEBMS_SAMPLING SA
WHERE  eventID IN (SELECT DISTINCT eventID FROM IPT_SEBMS.IPT_SEBMS_OCCURENCE)
;


/*
select vip_vis_visitid, COUNT(*) AS tot from vip_visitparticipant 
group by vip_vis_visitid
order by tot desc
*/
