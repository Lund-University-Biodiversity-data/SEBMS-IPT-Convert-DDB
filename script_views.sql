
CREATE VIEW IPT_SEBMS_SAMPLING AS
SELECT DISTINCT VIS.vis_uid,
CONCAT(EXTRACT(year from VIS.vis_begintime), '-', EXTRACT(MONTH from VIS.vis_begintime), '-', EXTRACT(DAY from VIS.vis_begintime),':',VIS.vis_uid) AS eventID, 
CASE WHEN SIT.sit_type='P' THEN 'Point/Punkt' WHEN SIT.sit_type='T' THEN 'Transect/Sling' END AS samplingProtocol,
VIS.vis_begintime AS eventDate,
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
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	/* WHYYYYY ??? */
AND SPE.spe_isvisible=true /* TO BE CHECKED */
/*AND VIS.vis_uid<>86367 DOUBLON ??? */
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT NULL
ORDER BY eventID

CREATE VIEW IPT_SEBMS_OCCURENCE AS
SELECT CONCAT(EXTRACT(year from VIS.vis_begintime), '-', EXTRACT(MONTH from VIS.vis_begintime), '-', EXTRACT(DAY from VIS.vis_begintime),':',VIS.vis_uid) AS eventID, 
VIS.vis_begintime AS eventDate,
'HumanObservation' AS basisOfRecord,
'species' AS taxonRank,
'Animalia' AS kingdom,
OBS.obs_count AS individualCount,
CONCAT(SPE.spe_genusname, ' ', SPE.spe_speciesname) AS scientificName
FROM spe_species SPE, sit_site SIT, obs_observation OBS, seg_segment SEG, vis_visit VIS
WHERE  OBS.obs_vis_visitid = VIS.vis_uid
AND OBS.obs_spe_speciesid = SPE.spe_uid
AND OBS.obs_seg_segmentid = SEG.seg_uid  
AND SEG.seg_sit_siteid = SIT.sit_uid 
AND VIS.vis_typ_datasourceid IN (54,55,56,63,64,66,67)	
AND SPE.spe_isvisible=true
AND VIS.vis_uid<>86367
AND SIT.sit_geort90lon IS NOT NULL
AND SIT.sit_geort90lat IS NOT NULL
ORDER BY eventID


CREATE VIEW IPT_SEBMS_TAXON AS
SELECT spe_dyntaxa AS taxonID, spe_familyname AS scientificName, 'species' AS taxonRank, '' AS kingdom, '' AS parentNameUsageID, "" AS acceptedNameUsageID
FROM spe_species
WHERE spe_isvisible=true; 