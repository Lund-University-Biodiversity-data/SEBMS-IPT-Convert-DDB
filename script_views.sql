/* HIDDEN SPECIES */

CREATE VIEW IPT_SEBMS_HIDDENSPECIES AS
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

CREATE VIEW IPT_SEBMS_SAMPLING AS
SELECT DISTINCT VIS.vis_uid,
CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'https://www.dagfjarilar.lu.se/hur-gor-man/viktiga-filer#handledning' AS samplingProtocol,
CAST(VIS.vis_begintime as date) AS eventDate,  
CASE 
	WHEN VIS.vis_begintime=VIS.vis_endtime THEN right(CAST(VIS.vis_begintime as TEXT), length(CAST(VIS.vis_begintime as TEXT)) - 11) 
	ELSE CONCAT(right(CAST(VIS.vis_begintime as TEXT), length(CAST(VIS.vis_begintime as TEXT)) - 11) ,'/',right(CAST(VIS.vis_endtime as TEXT), length(CAST(VIS.vis_endtime as TEXT)) - 11) ) 
END AS eventTime,
SIT.sit_uid AS locationID,
sit_reg_provinceid AS stateProvince,
sit_reg_countyid AS county,
sit_reg_municipalityid AS municipality,
'WGS84' AS geodeticDatum,
ST_Y(ST_Transform(ST_SetSRID(ST_Point(RT90_lon_R1000, RT90_lat_R1000), 3021), 4326)) AS decimalLatitude,
ST_X(ST_Transform(ST_SetSRID(ST_Point(RT90_lon_R1000, RT90_lat_R1000), 3021), 4326)) AS decimalLongitude,
'SE' AS countryCode
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS,
(
	SELECT sit_uid, ROUND(sit_geort90lat/1000)*1000 AS RT90_lat_R1000,
	ROUND(sit_geort90lon/1000)*1000 AS RT90_lon_R1000
	FROM sit_site	
) as ROUNDED_sites 
WHERE ROUNDED_sites.sit_uid=SIT.sit_uid
AND OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT NULL
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS_HIDDENSPECIES H)
ORDER BY eventID





/* SPECIES */
CREATE TABLE IPT_SEBMS_SPECIES_TAXONRANK AS
SELECT spe_uid, spe_familyname, spe_genusname, 
CASE 
	WHEN spe_uid=143 THEN 'order' 
	WHEN spe_uid IN (142, 144) THEN 'speciesAggregate' 
	WHEN (spe_genusname='' or spe_genusname is NULL) THEN 'family' 
	ELSE 'species' 
END AS taxonRank 
FROM spe_species;
/* see detailed list from Annelie pour les 11 qui sont des speciesAggregate ||| si pas de genusname c'est donc "family" (11 cas).  |||| "order" for the #143 Unidentified butterfly */


/*
VISIT PARTICPANTS AGGREGATES IN ONE FILED
*/
CREATE VIEW IPT_SEBMS_VISITPARTICIPANTS AS
select vip_vis_visitid, string_agg(DISTINCT cast(vip_per_participantid as text), ',') AS participantsList
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
 - informationWithheld : mention the protected species ? @Annelie

AS recordedBy,  liste potentielle !! => LEFT JOIN avec visitParticipant pas suffisant ??. Séparer les IDs de participants avec des | 
*/

CREATE VIEW IPT_SEBMS_OCCURENCE AS
SELECT 
CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'HumanObservation' AS basisOfRecord,
CASE 
	WHEN spe_uid=143 THEN 'order' 
	WHEN spe_uid IN (142, 144) THEN 'speciesAggregate' 
	WHEN (spe_genusname='' or spe_genusname is NULL) THEN 'family' 
	ELSE 'species' 
END AS taxonRank, 
'Animalia' AS kingdom,
SUM(OBS.obs_count) AS individualCount, /* SUM per site !!!  ***/
SPE.spe_dyntaxa AS taxonID,
CONCAT(SPE.spe_genusname, ' ', SPE.spe_speciesname) AS scientificName,
SPE.spe_familyname AS family,
CASE 
	WHEN SIT.sit_type='T' then 'SUM of the different segments' 
	else ''
END AS informationWithheld,
VP.participantsList as recordedBy
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
LEFT JOIN IPT_SEBMS_VISITPARTICIPANTS VP on VIS.vis_uid=VP.vip_vis_visitid
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS_HIDDENSPECIES H)
GROUP BY eventID, spe_uid, sit_type, recordedBy

/*
// hide the species to protect
TO BE added
AND spe_isconfidential = false
*/

/*
CREATE VIEW IPT_SEBMS_TAXON AS
SELECT spe_dyntaxa AS taxonID, spe_familyname AS scientificName, 'species' AS taxonRank, '' AS kingdom, '' AS parentNameUsageID, "" AS acceptedNameUsageID
FROM spe_species
WHERE 1; 
*/


/* EMOF */
/*
To be fixed:
 - convert angular degrees to cardinal points

*/

CREATE VIEW IPT_SEBMS_EMOF AS
SELECT
DISTINCT CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'Site category' AS measurementType,
CASE WHEN SIT.sit_type='P' THEN 'Point/Punkt' WHEN SIT.sit_type='T' THEN 'Transect/Sling' END AS measurementValue,
'' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS_HIDDENSPECIES H)
AND SIT.sit_type IS NOT NULL
UNION
SELECT
DISTINCT CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'Sunshine' AS measurementType,
CAST(VIS.vis_sunshine AS text) AS measurementValue,
'%' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_sunshine IS NOT NULL
UNION
SELECT
DISTINCT CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'Temperature' AS measurementType,
CAST(VIS.vis_temperature AS text) AS measurementValue,
'°C' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_temperature IS NOT NULL
UNION
SELECT
DISTINCT CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'Wind direction' AS measurementType,
CAST(VIS.vis_winddirection AS text) AS measurementValue,
'angular degrees' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_winddirection IS NOT NULL
UNION
SELECT
DISTINCT CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'Wind Speed' AS measurementType,
CAST(VIS.vis_windspeed AS text) AS measurementValue,
'm/s' AS measurementUnit
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT null
AND SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS_HIDDENSPECIES H)
AND VIS.vis_windspeed IS NOT NULL;


SELECT DISTINCT VIS.vis_uid,
CONCAT('SEBMS',':',VIS.vis_uid) AS eventID, 
'Site category', 'Sunshine', 'Temperature', 'Wind direction', 'Wind Speed' AS measurementType,
CASE WHEN SIT.sit_type='P' THEN 'Point/Punkt' WHEN SIT.sit_type='T' THEN 'Transect/Sling' END, vis_sunshine, vis_temperature, vis_winddirection, vis_windspeed AS measurementValue,
'', '%', '°C', 'angular degrees', 'm/s' AS measurementUnit 


/*
select vip_vis_visitid, COUNT(*) AS tot from vip_visitparticipant 
group by vip_vis_visitid
order by tot desc
*/