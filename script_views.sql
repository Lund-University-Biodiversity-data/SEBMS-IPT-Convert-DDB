/* TO WATCH OUT BEFORE RELAUNCHING :
 - the hiddenspecies list
 - the datasource list 
 - the date filter
*/
\i lib/config.sql

\c :database_name

\set year_max 2023 

DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_EMOF;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_OCCURENCE;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_SAMPLING;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_EVENTSNOOBS;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS;
DROP VIEW IF EXISTS IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES;

DROP SCHEMA IF EXISTS IPT_SEBMS;
CREATE SCHEMA IPT_SEBMS;

/* HIDDEN SPECIES */
CREATE VIEW IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES AS
SELECT * FROM spe_species
WHERE spe_dyntaxa in (101510); /* mnemosyne */


/*
VISIT PARTICPANTS AGGREGATES IN ONE FILED
*/
CREATE VIEW IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS AS
select vip_vis_visitid, string_agg(DISTINCT CONCAT('SEBMS:recorderId:',cast(vip_per_participantid as text)), '|') AS participantsList
FROM vip_visitparticipant 
GROUP by vip_vis_visitid;



CREATE VIEW IPT_SEBMS.IPT_SEBMS_EVENTSNOOBS AS
/*
SELECT 
VIS.vis_uid,
CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID
FROM spe_species SPE, obs_observation OBS, seg_segment SEG, vis_visit VIS,
(
	SELECT sit_uid, sit_geowgs84lat AS RT90_lat_diffusion,
	sit_geowgs84lon AS RT90_lon_diffusion
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
AND VIS.vis_typ_datasourceid IN (:datasources)
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT NULL
AND (SPE.spe_dyntaxa is null OR SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H))
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
AND VIS.vis_uid NOT IN (
	select DISTINCT VIS.vis_uid
    FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
	LEFT JOIN IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS VP on VIS.vis_uid=VP.vip_vis_visitid
	WHERE  OBS.obs_vis_visitid = VIS.vis_uid
	AND OBS.obs_spe_speciesid = SPE.spe_uid
	AND OBS.obs_seg_segmentid = SEG.seg_uid  
	AND SEG.seg_sit_siteid = SIT.sit_uid 
	AND VIS.vis_typ_datasourceid IN (:datasources)	
	AND SIT.sit_geowgs84lon IS NOT NULL
	AND SIT.sit_geowgs84lat IS NOT null
	AND (SPE.spe_dyntaxa is null OR SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H))
	AND OBS.obs_count>0
	AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
);
*/
SELECT 
VIS.vis_uid,
CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID
from sit_site SIT, vis_visit VIS
left join obs_observation OBS on OBS.obs_vis_visitid = VIS.vis_uid 
WHERE VIS.vis_typ_datasourceid IN (:datasources)
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
and VIS.vis_sit_siteid = SIT.sit_uid 
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT NULL
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND VIS.vis_uid NOT IN (
	select DISTINCT VIS.vis_uid
    FROM obs_observation OBS, vis_visit VIS
	LEFT JOIN IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS VP on VIS.vis_uid=VP.vip_vis_visitid
	WHERE  OBS.obs_vis_visitid = VIS.vis_uid
	AND VIS.vis_typ_datasourceid IN (:datasources)	
	AND OBS.obs_count>0
	AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
);

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
CONCAT('SEBMS:datasetID:54') AS datasetID,
'Swedish Butterfly Monitoring Scheme' AS datasetname,
/*
CASE 
    WHEN (vis.vis_isfullvisit = true) THEN
        CASE
            WHEN (sit.sit_type = 'T') THEN null::real
            WHEN (sit.sit_type = 'P') THEN 1963.5
            ELSE NULL::real
        END
    ELSE null::real
END AS sampleSizeValue,
CASE 
    WHEN (vis.vis_isfullvisit = true) THEN
        CASE
            WHEN (sit.sit_type = 'T') THEN null::text 
            WHEN (sit.sit_type = 'P') THEN 'square metre'
            ELSE NULL::text
        END
    ELSE null
END AS sampleSizeUnit,
CASE 
    WHEN (vis.vis_isfullvisit = true) THEN
        CASE
		    WHEN (sit.sit_type = 'T') THEN null::text 
		    WHEN (sit.sit_type = 'P') THEN '15 minutes' 
		    ELSE NULL::text
	    END
	ELSE null 
END AS samplingEffort,
*/
CASE
    WHEN (sit.sit_type = 'T') THEN 'Fixed route Pollard walk transect'::text
    WHEN (sit.sit_type = 'P') THEN 'Point site count'::text
    ELSE NULL::text
END AS samplingprotocol,
CONCAT(TO_CHAR(VIS.vis_begintime :: DATE, 'yyyy-mm-dd'), '/', TO_CHAR(VIS.vis_endtime :: DATE, 'yyyy-mm-dd')) AS eventDate,  
CAST(EXTRACT (doy from  VIS.vis_begintime) AS INTEGER) AS startDayOfYear,
CAST(EXTRACT (doy from  VIS.vis_endtime) AS INTEGER)  AS endDayOfYear,
CASE
	WHEN vis.vis_isfullvisit=false THEN 'The site was not completely surveyed during this visit.'
	ELSE ''
END AS eventRemarks,
CASE 
	WHEN VIS.vis_begintime=VIS.vis_endtime THEN 
		CASE
			WHEN right(CAST(VIS.vis_begintime AT TIME ZONE 'Europe/Paris' as TEXT), length(CAST(VIS.vis_begintime AT TIME ZONE 'Europe/Paris' as TEXT)) - 11) = '00:00:00'
			THEN NULL
			ELSE TO_CHAR(VIS.vis_begintime, 'HH24:MI:SS TZH') 
		END
	ELSE CONCAT(TO_CHAR(VIS.vis_begintime, 'HH24:MI:SS TZH') ,'/',TO_CHAR(VIS.vis_endtime, 'HH24:MI:SS TZH') ) 
END AS eventTime,
SIT.sit_nat_stn_reg AS locationId,
SIT.sit_name AS verbatimLocality,
CONCAT('SEBMS',':siteId:',SIT.sit_uid) AS locality, 
REG_COU.reg_name AS county,
REG_PRO.reg_name AS stateProvince,
REG_MUN.reg_name AS municipality,
'EPSG:4326' AS geodeticDatum,
ROUND(sit_geowgs84lat, 5) AS decimalLatitude,
ROUND(sit_geowgs84lon, 5) AS decimalLongitude,
'EPSG:3857' AS verbatimSRS,
'Sweden' AS country,
'SE' AS countryCode,
'EUROPE' AS continent,
CASE 
	WHEN SIT.sit_type='T' then 1000 
	WHEN SIT.sit_type='P' then 25 
END AS coordinateUncertaintyInMeters,
CASE
    WHEN (sit.sit_type = 'T') THEN 'Site coordinates represent the centroid midpoint for the transect site.' 
    WHEN (sit.sit_type = 'P') THEN 'Site coordinates represent the midpoint for the point site.' 
    ELSE NULL::text
END AS locationRemarks,
to_char (now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS modified,
CASE 
	WHEN SIT.sit_type='T' then 'The number of individuals observed is the sum total from all the segments of the transect site. Species with a security class 3 or higher (according to the Swedish species information centre (Artdatabanken)) are not shown in this dataset at present. Currently this concerns one species only, the Clouded Apollo, (Mnemosynefjäril; Parnassius mnemosyne).' 
	WHEN SIT.sit_type='P' then 'Species with a security class 3 or higher (according to the Swedish species information centre (Artdatabanken)) are not shown in this dataset at present. Currently this concerns one species only, the Clouded Apollo, (Mnemosynefjäril; Parnassius mnemosyne).'
	ELSE ''
END AS informationWithheld,
'English' as language,
'Limited' as accessRights,
'Lund University' AS institutionCode,
'Swedish Environmental Protection Agency' AS ownerInstitutionCode
FROM spe_species SPE, obs_observation OBS, seg_segment SEG, vis_visit VIS,
sit_site SIT left join reg_region REG_MUN on REG_MUN.reg_uid = sit_reg_municipalityid
left join reg_region REG_COU on REG_COU.reg_uid = sit_reg_countyid
left join reg_region REG_PRO on REG_PRO.reg_uid = sit_reg_provinceid
WHERE OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT NULL
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND (SPE.spe_dyntaxa is null OR SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H))
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max


UNION

SELECT DISTINCT VIS.vis_uid,
CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
CONCAT('SEBMS:datasetID:54') AS datasetID,
'Swedish Butterfly Monitoring Scheme' AS datasetname,
/*
CASE 
    WHEN (vis.vis_isfullvisit = true) THEN
        CASE
            WHEN (sit.sit_type = 'T') THEN null::real 
            WHEN (sit.sit_type = 'P') THEN 1963.5 
            ELSE NULL::real
        END
    ELSE null::real
END AS sampleSizeValue,
CASE 
    WHEN (vis.vis_isfullvisit = true) THEN
        CASE
            WHEN (sit.sit_type = 'T') THEN null::text 
            WHEN (sit.sit_type = 'P') THEN 'square metre' 
            ELSE NULL::text
        END
    ELSE null
END AS sampleSizeUnit,
CASE 
    WHEN (vis.vis_isfullvisit = true) THEN
        CASE
		    WHEN (sit.sit_type = 'T') THEN null::text 
		    WHEN (sit.sit_type = 'P') THEN '15 minutes' 
		    ELSE NULL::text
	    END
	ELSE null 
END AS samplingEffort,
*/
CASE
    WHEN (sit.sit_type = 'T') THEN 'Fixed route Pollard walk transect'::text
    WHEN (sit.sit_type = 'P') THEN 'Point site count'::text
    ELSE NULL::text
END AS samplingprotocol,
CONCAT(TO_CHAR(VIS.vis_begintime :: DATE, 'yyyy-mm-dd'), '/', TO_CHAR(VIS.vis_endtime :: DATE, 'yyyy-mm-dd')) AS eventDate,  
CAST(EXTRACT (doy from  VIS.vis_begintime) AS INTEGER) AS startDayOfYear,
CAST(EXTRACT (doy from  VIS.vis_endtime) AS INTEGER)  AS endDayOfYear,
CASE
	WHEN vis.vis_isfullvisit=false THEN 'The site was not completely surveyed during this visit.'
	ELSE ''
END AS eventRemarks,
CASE 
	WHEN VIS.vis_begintime=VIS.vis_endtime THEN 
		CASE
			WHEN right(CAST(VIS.vis_begintime AT TIME ZONE 'Europe/Paris' as TEXT), length(CAST(VIS.vis_begintime AT TIME ZONE 'Europe/Paris' as TEXT)) - 11) = '00:00:00'
			THEN NULL
			ELSE TO_CHAR(VIS.vis_begintime, 'HH24:MI:SS TZH') 
		END
	ELSE CONCAT(TO_CHAR(VIS.vis_begintime, 'HH24:MI:SS TZH') ,'/',TO_CHAR(VIS.vis_endtime, 'HH24:MI:SS TZH') ) 
END AS eventTime,
SIT.sit_nat_stn_reg AS locationId,
SIT.sit_name AS verbatimLocality,
CONCAT('SEBMS',':siteId:',SIT.sit_uid) AS locality, 
REG_COU.reg_name AS county,
REG_PRO.reg_name AS stateProvince,
REG_MUN.reg_name AS municipality,
'EPSG:4326' AS geodeticDatum,
ROUND(sit_geowgs84lat, 5) AS decimalLatitude,
ROUND(sit_geowgs84lon, 5) AS decimalLongitude,
'EPSG:3857' AS verbatimSRS,
'Sweden' AS country,
'SE' AS countryCode,
'EUROPE' AS continent,
CASE 
	WHEN SIT.sit_type='T' then 1000 
	WHEN SIT.sit_type='P' then 25 
END AS coordinateUncertaintyInMeters,
CASE
    WHEN (sit.sit_type = 'T') THEN 'Site coordinates represent the centroid midpoint for the transect site.' 
    WHEN (sit.sit_type = 'P') THEN 'Site coordinates represent the midpoint for the point site.' 
    ELSE NULL::text
END AS locationRemarks,
to_char (now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS modified,
CASE 
	WHEN SIT.sit_type='T' then 'The number of individuals observed is the sum total from all the segments of the transect site. Species with a security class 3 or higher (according to the Swedish species information centre (Artdatabanken)) are not shown in this dataset at present. Currently this concerns one species only, the Clouded Apollo, (Mnemosynefjäril; Parnassius mnemosyne).' 
	WHEN SIT.sit_type='P' then 'Species with a security class 3 or higher (according to the Swedish species information centre (Artdatabanken)) are not shown in this dataset at present. Currently this concerns one species only, the Clouded Apollo, (Mnemosynefjäril; Parnassius mnemosyne).'
	ELSE ''
END AS informationWithheld,
'English' as language,
'Limited' as accessRights,
'Lund University' AS institutionCode,
'Swedish Environmental Protection Agency' AS ownerInstitutionCode
FROM seg_segment SEG, vis_visit VIS, sit_site SIT left join reg_region REG_MUN on REG_MUN.reg_uid = sit_reg_municipalityid
left join reg_region REG_COU on REG_COU.reg_uid = sit_reg_countyid
left join reg_region REG_PRO on REG_PRO.reg_uid = sit_reg_provinceid
WHERE VIS.vis_sit_siteid = SIT.sit_uid 
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT NULL
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
and VIS.vis_uid in (select vis_uid from IPT_SEBMS.IPT_SEBMS_EVENTSNOOBS)


ORDER BY eventID;

/* to create a diffusion of 1km:
	SELECT sit_uid, ROUND(sit_geowgs84lat/1000)*1000 AS RT90_lat_diffusion,
	ROUND(sit_geowgs84lon/1000)*1000 AS RT90_lon_diffusion
	FROM sit_site

*/






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
CASE 
	WHEN (SPE.spe_dyntaxa IS NULL) THEN CONCAT('SEBMS',':',VIS.vis_uid,':',SPE.spe_uid)
	else CONCAT('SEBMS',':',VIS.vis_uid,':',SPE.spe_dyntaxa) 
END AS occurrenceID, 
'HumanObservation' AS basisOfRecord,
spe_taxonrank AS taxonRank, 
'Animalia' AS kingdom,
SUM(OBS.obs_count) AS organismQuantity, /* SUM per site !!!  ***/
'individuals' AS organismQuantityType,
SUM(OBS.obs_count) AS individualCount, /* SUM per site !!!  ***/
CASE 
	WHEN (SPE.spe_dyntaxa IS NULL) THEN ''
	else CONCAT('urn:lsid:dyntaxa.se:Taxon:',SPE.spe_dyntaxa)
END AS taxonID,
SPE.spe_scientificname AS scientificName,
REPLACE(REPLACE(SPE.spe_auctor, ')', ''), '(', '') AS scientificNameAuthorship,
SPE.spe_eurotaxa AS euTaxonID, /* in emof */
/*SPE.spe_originalnameusage AS originalNameUsage,
SPE.spe_higherclassification AS higherClassification,*/
SPE.spe_familyname AS family,
split_part(spe_scientificname, ' ', 1) AS genus,
split_part(spe_scientificname, ' ', 2) AS specificEpithet,
VP.participantsList as recordedBy,
'Validated' as identificationVerificationStatus,
'Present' as occurrenceStatus,
SPE.spe_semainname as vernacularName,
CASE 
	WHEN SIT.sit_type='T' then 'The number of individuals observed is the sum total from the surveyed segments of the transect site.' 
	WHEN SIT.sit_type='P' then 'The number of individuals observed is the sum total from the whole point site.'
	ELSE ''
END AS occurrenceRemarks,
'SEBMS' AS collectionCode
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
LEFT JOIN IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS VP on VIS.vis_uid=VP.vip_vis_visitid
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)	
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT null
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND (SPE.spe_dyntaxa is null OR SPE.spe_dyntaxa not in (select distinct spe_dyntaxa from IPT_SEBMS.IPT_SEBMS_HIDDENSPECIES H))
AND OBS.obs_count>0
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max

GROUP BY eventID, occurrenceID, spe_uid, sit_type, recordedBy

UNION

SELECT 
CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
CONCAT('SEBMS',':',VIS.vis_uid,':3000188') AS occurrenceID, 
'HumanObservation' AS basisOfRecord,
'order' AS taxonRank, 
'Animalia' AS kingdom,
0 AS organismQuantity, 
'individuals' AS organismQuantityType,
0 AS individualCount, 
'urn:lsid:dyntaxa.se:Taxon:3000188' AS taxonID,
'Lepidoptera' AS scientificName,
'' AS scientificNameAuthorship,
null AS euTaxonID, /* in emof */
/*'' AS originalNameUsage,
'Biota;Animalia;Arthropoda;Hexapoda;Insecta' AS higherClassification,*/
'' AS family,
'' AS genus,
'' AS specificEpithet,
VP.participantsList as recordedBy,
'' as identificationVerificationStatus,
'Absent' as occurrenceStatus,
'SpeciesIncludedInSurvey' as vernacularName,
CASE 
	WHEN SIT.sit_type='T' then 'The number of individuals observed is the sum total from the surveyed segments of the transect site.' 
	WHEN SIT.sit_type='P' then 'The number of individuals observed is the sum total from the whole point site.'
	ELSE ''
END AS occurrenceRemarks,
'SEBMS' AS collectionCode
FROM IPT_SEBMS.IPT_SEBMS_EVENTSNOOBS NO, sit_site SIT, vis_visit VIS
LEFT JOIN IPT_SEBMS.IPT_SEBMS_VISITPARTICIPANTS VP on VIS.vis_uid=VP.vip_vis_visitid
WHERE NO.vis_uid=VIS.vis_uid
AND VIS.vis_sit_siteid=SIT.sit_uid
AND VIS.vis_typ_datasourceid IN (:datasources)	
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT null
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max;






/*
ver 1.9 // Add events without observations (these are listed in eMoF with "True")
, set scientificName to Lepidoptera, 
taxonId to 3000188, 
vernacularName to ButterfliesAndMothsIncludedInSurvey,
 occurrenceStatus to absent, 
 organismQuantity to 0, organismQuantityType to individuals, 
 basisOfRecord to HumanObservation, 
 occurrenceID to SEBMS:"eventId":null (Coll.code:vis_uid:null).

*/


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
null as occurrenceID,
'locationType' AS measurementType,
CASE WHEN SIT.sit_type='P' THEN 'Point site' WHEN SIT.sit_type='T' THEN 'Transect site' END AS measurementValue,
'' AS measurementUnit
FROM sit_site SIT, vis_visit VIS
WHERE  VIS.vis_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)	
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT null
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND SIT.sit_type IS NOT NULL
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max

UNION

SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
null as occurrenceID,
'sunshine' AS measurementType,
CAST(VIS.vis_sunshine AS text) AS measurementValue,
'%' AS measurementUnit
FROM sit_site SIT, vis_visit VIS
WHERE  VIS.vis_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)	
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT null
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
AND VIS.vis_sunshine IS NOT NULL

UNION

SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
null as occurrenceID,
'airTemperature' AS measurementType,
CAST(VIS.vis_temperature AS text) AS measurementValue,
'°C' AS measurementUnit
FROM sit_site SIT, vis_visit VIS
WHERE  VIS.vis_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)	
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT null
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
AND VIS.vis_temperature IS NOT NULL

UNION

SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
null as occurrenceID,
'windDirection' AS measurementType,
CAST(VIS.vis_winddirection AS text) AS measurementValue,
'degrees' AS measurementUnit
FROM sit_site SIT, vis_visit VIS
WHERE  VIS.vis_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)	
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT null
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
AND VIS.vis_winddirection IS NOT NULL

UNION

SELECT
DISTINCT CONCAT('SEBMS',':eventId:',VIS.vis_uid) AS eventID, 
null as occurrenceID,
'windStrength' AS measurementType,
CONCAT (CAST(VIS.vis_windspeed AS text), ' Beaufort') AS measurementValue,
'' AS measurementUnit
FROM sit_site SIT, vis_visit VIS
WHERE  VIS.vis_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (:datasources)	
AND SIT.sit_geowgs84lon IS NOT NULL
AND SIT.sit_geowgs84lat IS NOT null
AND SIT.sit_isdeleted =false
AND SIT.sit_ispublic =true
AND VIS.vis_isdeleted =false
AND EXTRACT(YEAR FROM VIS.vis_begintime) <= :year_max
AND VIS.vis_windspeed IS NOT NULL

UNION

SELECT
eventID, 
null as occurrenceID,
'noObservations' AS measurementType,
'true' AS measurementValue,
'' AS measurementUnit
FROM IPT_SEBMS.IPT_SEBMS_SAMPLING SA
WHERE  eventID IN (SELECT DISTINCT eventID FROM IPT_SEBMS.IPT_SEBMS_EVENTSNOOBS)

UNION

SELECT
eventID, 
null as occurrenceID,
'noObservations' AS measurementType,
'false' AS measurementValue,
'' AS measurementUnit
FROM IPT_SEBMS.IPT_SEBMS_SAMPLING SA
WHERE  eventID NOT IN (SELECT DISTINCT eventID FROM IPT_SEBMS.IPT_SEBMS_EVENTSNOOBS)

UNION

SELECT
eventID,
occurrenceID,
'euTaxonID' AS measurementType,
(euTaxonID::text) AS measurementValue,
'' AS measurementUnit
FROM IPT_SEBMS.IPT_SEBMS_OCCURENCE SA
WHERE euTaxonID IS NOT NULL

UNION 

SELECT
eventID, 
null as occurrenceID,
'locationProtected' AS measurementType,
'no' AS measurementValue,
'' AS measurementUnit
FROM IPT_SEBMS.IPT_SEBMS_SAMPLING SA
;


/*
select vip_vis_visitid, COUNT(*) AS tot from vip_visitparticipant 
group by vip_vis_visitid
order by tot desc
*/
