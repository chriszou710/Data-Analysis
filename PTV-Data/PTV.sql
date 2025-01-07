--Task 1.1 Write the SQL script to create the destination schema named “ptv”.
create schema ptv;
 
--Task 1.2 Write the SQL script to restore ALL tables in GTFS files.

drop table ptv.agency;
create table ptv.agency 
(
  agency_id numeric(3),
  agency_name VARCHAR(15),
  agency_url VARCHAR(50),
  agency_timezone VARCHAR(30),
  agency_lang CHAR(2)
);

copy ptv.agency from '/data/adata/gtfs/agency.txt'
delimiter ','
csv header;

drop table calendar;
create table ptv.calendar
(
	service_id varchar(20),
	monday numeric (1),
	tuesday numeric (1),
	wednesday numeric (1),
	thursday numeric (1),
	friday numeric (1),
	saturday numeric (1),
	sunday numeric (1),
	start_date varchar(10),
	end_date varchar(10)
)

copy ptv.calendar from '/data/adata/gtfs/calendar.txt'
delimiter ','
csv header;

drop table ptv.

create table ptv.calendar_dates 
(
	service_id varchar(20),
	date varchar(10),
	exception_type numeric(1)
);

copy ptv.calendar_dates from '/data/adata/gtfs/calendar_dates.txt'
delimiter ','
csv header;

drop table ptv.routes;
create table ptv.routes
(
	route_id varchar(15),
	agency_id numeric(3),
	route_short_name varchar(20),
	route_long_name varchar(100),
	route_type numeric(3),
	route_color char(10),
	route_text_color char(10)
);

copy ptv.routes from '/data/adata/gtfs/routes.txt'
delimiter ','
csv header;

create table ptv.shapes
(
	shape_id varchar(20),
	shape_pt_lat numeric(15,13),
	shape_pt_long numeric(16,13),
	shape_pt_sequence numeric(5),
	shape_dist_traveled numeric(10,2)
);

copy ptv.shapes from '/data/adata/gtfs/shapes.txt'
delimiter ','
csv header;

drop table ptv.stop_times;
create table ptv.stop_times
(	trip_id varchar(30),
arrival_time char(10),
departure_time char(10),
stop_id numeric(10),
stop_sequence numeric(10),
stop_headsign varchar(10),
pickup_type numeric(1),
drop_off_type numeric(1),
shape_dist_traveled varchar(12)
)

copy ptv.stop_times from '/data/adata/gtfs/stop_times.txt'
delimiter ','
csv header;

create table ptv.stops
(
	stop_id numeric(5),
	stop_name varchar(100),
	stop_lat numeric(15,13),
	stop_lon numeric(16,13)
);

copy ptv.stops from '/data/adata/gtfs/stops.txt'
delimiter ','
csv header;

create table ptv.trips
(
	route_id varchar(20),
	service_id varchar(20),
	trip_id varchar(25),
	shape_id varchar(20),
	trip_headsign varchar(50),
	direction_id numeric(1)
);

copy ptv.trips from '/data/adata/gtfs/trips.txt'
delimiter ','
csv header;

--Task 1.3 Scripts to restore the Mesh Blocks files by using correct dataset file. Restore the file using ogr2ogr into table “mb2021”

--Task 1.4 Write the SQL script to restore the LGA2021 Allocation file. Write the SQL script to restore the SAL 2021 Allocation file for suburb2021. 
drop table ptv.lga2021;
create table ptv.lga2021
(
	mb_code_2021 char(11),
	lga_code_2021 char(5),
	lga_name_2021 char(60),
	state_code_2021 char(1),
	state_name_2021 varchar(50),
	aus_code_2021 char(3),
	aus_name_2021 varchar(20),
	area_albers_sqkm numeric(10,4),
	asgs_loci_uri_2021 varchar(60)
);

copy ptv.lga2021 from '/data/adata/LGA_2021_AUST.csv'
delimiter ','
csv header;

create table ptv.sal2021
(
	mb_code_2021 char(11),
	sal_code_2021 char(5),
	sal_name_2021 char(60),
	state_code_2021 char(1),
	state_name_2021 varchar(50),
	aus_code_2021 char(3),
	aus_name_2021 varchar(20),
	area_albers_sqkm numeric(10,4),
	asgs_loci_uri_2021 varchar(60)
);

copy ptv.sal2021 from '/data/adata/SAL_2021_AUST.csv'
delimiter ','
csv header;

--Task 1.5
with tbl as
(
select
	table_schema,
	TABLE_NAME
from
	information_schema.tables
where
	table_schema in ('ptv'))
select
	table_schema,
	TABLE_NAME,
	(xpath('/row/c/text()',
	query_to_xml(format('select count(*) as c from %I.%I',
	table_schema,
	TABLE_NAME),
	false,
	true,
	'')))[1]::text::int as rows_n
from
	tbl
order by
	table_name; 

--Task 2.1 **

create table if not exists ptv.mb2021_mel as
select
	*
from
	ptv.mb2021
where
	gcc_name21 ilike '%greater melbourne%';

SELECT * FROM ptv.mb2021_mel;

--Task 2.2 **
CREATE TABLE IF NOT EXISTS ptv.melbourne AS
SELECT ST_Union(mm.wkb_geometry) AS geom
FROM ptv.mb2021_mel mm;

SELECT * FROM ptv.melbourne;

--Task 2.3 **
ALTER TABLE ptv.stops 
ADD COLUMN geom geometry;
UPDATE ptv.stops
SET geom = ST_SetSRID(ST_Point(stop_lon, stop_lat), 7844);

SELECT * FROM ptv.stops;

--Task 2.4

-- Creating a new table 'stops_routes_mel' under the 'ptv' schema
CREATE TABLE ptv.stops_routes_mel AS 

-- Selecting unique records based on the following criteria
SELECT DISTINCT 
    s.stop_id,                           -- Stop ID
    s.stop_name,                         -- Name of the Stop
    s.geom,                              -- Geometry for the Stop
    r.route_short_name AS route_number,  -- Short Route Name (probably numeric)
    r.route_long_name AS route_name,     -- Full Route Name
    CASE r.route_type                    -- Determine vehicle type based on route_type
        WHEN 0 THEN 'Tram'
        WHEN 2 THEN 'Train'
        WHEN 3 THEN 'Bus'
        ELSE 'Unknown'
    END AS vehicle                       -- Vehicle Type (Tram, Train, Bus, etc.)

-- From the 'stops' table in the 'ptv' schema
FROM ptv.stops s

    -- Join the 'stop_times' table using 'stop_id'
    JOIN ptv.stop_times st ON s.stop_id = st.stop_id
    
    -- Join the 'trips' table using 'trip_id'
    JOIN ptv.trips t ON st.trip_id = t.trip_id
    
    -- Join the 'routes' table using 'route_id'
    JOIN ptv.routes r ON t.route_id = r.route_id
    
    -- Ensure the stops are within the 'melbourne' boundary
    JOIN ptv.melbourne m ON ST_Within(s.geom, m.geom);


--Task 2.4.1
select count(*) from ptv.stops_routes_mel;

--Task 2.4.2
select count(distinct stop_id) 
from ptv.stops_routes_mel;

--Task 3.1
WITH subAccess AS (
    SELECT 
        stop_id, 
        mb_code21
    FROM 
        ptv.stops_routes_mel, 
        ptv.mb2021_mel
    WHERE 
        vehicle = 'Bus' AND 
        ST_Within(ptv.stops_routes_mel.geom, ptv.mb2021_mel.wkb_geometry)
)

SELECT 
    s.sal_name_2021 AS suburb_name,
    COUNT(sa.stop_id) AS no_stops
FROM 
    subAccess sa
JOIN 
    ptv.sal2021 s ON sa.mb_code21 = s.mb_code_2021
GROUP BY 
    s.sal_name_2021;


WITH subAccess AS 
(
   SELECT DISTINCT sr.stop_id, mb.mb_code21
   FROM ptv.stops_routes_mel sr
   JOIN ptv.mb2021_mel mb ON st_within(sr.geom, mb.wkb_geometry)
   WHERE sr.vehicle = 'Bus'
)
SELECT s.sal_name_2021 AS suburb_name,
       COUNT(sa.stop_id) AS no_stops
FROM subAccess sa
JOIN ptv.sal2021 s ON sa.mb_code21 = s.mb_code_2021
GROUP BY s.sal_name_2021;

-- Task 3.1.1

WITH subAccess AS 
(
   SELECT DISTINCT sr.stop_id, mb.mb_code21
   FROM ptv.stops_routes_mel sr
   JOIN ptv.mb2021_mel mb ON st_within(sr.geom, mb.wkb_geometry)
   WHERE sr.vehicle = 'Bus'
)
SELECT s.sal_name_2021 AS suburb_name,
       COUNT(sa.stop_id) AS no_stops
FROM subAccess sa
JOIN ptv.sal2021 s ON sa.mb_code21 = s.mb_code_2021
GROUP BY s.sal_name_2021
order by no_stops asc,suburb_name asc
Limit 5;

--Task 3.1.2
WITH subAccess AS 
(
   SELECT DISTINCT sr.stop_id, mb.mb_code21
   FROM ptv.stops_routes_mel sr
   JOIN ptv.mb2021_mel mb ON st_within(sr.geom, mb.wkb_geometry)
   WHERE sr.vehicle = 'Bus'
),
suburbStops AS 
(
   SELECT s.sal_name_2021 AS suburb_name,
          COUNT(sa.stop_id) AS no_stops
   FROM subAccess sa
   JOIN ptv.sal2021 s ON sa.mb_code21 = s.mb_code_2021
   GROUP BY s.sal_name_2021
)
SELECT AVG(no_stops) AS avg_stops
FROM suburbStops;


--task 3.2
WITH lga AS (
    SELECT
        lga_name_2021,
        ST_Union(wkb_geometry) geom
    FROM
        ptv.mb2021_mel mb
    JOIN
        ptv.lga2021 la ON mb.mb_code21 = la.mb_code_2021
    GROUP BY
        la.lga_name_2021
),
lga_stop AS (
    SELECT DISTINCT
        la.lga_name_2021,
        s.geom
    FROM
        ptv.stops_routes_mel s
    JOIN
        lga la ON ST_Within(s.geom, la.geom)
    WHERE
        vehicle = 'Bus'
),
lga_residential AS (
    SELECT
        la.lga_name_2021,
        mb.mb_code21,
        mb.wkb_geometry geom
    FROM
        ptv.mb2021_mel mb
    JOIN
        ptv.lga2021 la ON mb.mb_code21 = la.mb_code_2021
    WHERE
        initcap(mb.mb_cat21) LIKE '%Residential%'
),
ns AS (
    SELECT
        s.lga_name_2021,
        COUNT(DISTINCT r.mb_code21) non_blankspot
    FROM
        lga_stop s
    JOIN
        lga_residential r ON s.lga_name_2021 = r.lga_name_2021
            AND ST_Within(s.geom, r.geom)
    GROUP BY
        s.lga_name_2021
),
ra AS (
    SELECT
        la.lga_name_2021,
        COUNT(DISTINCT mb.mb_code21) count_residential
    FROM
        lga_residential mb
    GROUP BY
        la.lga_name_2021
)
SELECT
    ns.lga_name_2021 AS LGA_name,
    count_residential,
    count_residential - non_blankspot AS count_blankspot,
    ROUND((count_residential - non_blankspot)::NUMERIC / count_residential::NUMERIC * 100, 2) || '%' AS blankspot_percentage
FROM
    ns
JOIN
    ra ON ns.lga_name_2021 = ra.lga_name_2021
ORDER BY
    blankspot_percentage ASC;

--3.2.1

--4
DROP TABLE ptv.lga_blankspot;

CREATE TABLE ptv.lga_blankspot AS
WITH 
-- Aggregate the LGA boundaries
lga AS (
    SELECT 
        lga_name_2021, 
        st_union(wkb_geometry) geom
    FROM 
        ptv.mb2021_mel mb, 
        ptv.lga2021 l
    WHERE 
        mb.mb_code21 = l.mb_code_2021
    GROUP BY 
        l.lga_name_2021
),

-- Identify bus stops within the LGA boundaries
lga_stop AS (
    SELECT DISTINCT 
        lga_name_2021, 
        s.geom
    FROM 
        ptv.stops_routes_mel s, 
        lga
    WHERE 
        vehicle = 'Bus'
        AND 
        st_within(s.geom, lga.geom)
),

-- Identify residential areas within the LGA
lga_residential AS (
    SELECT 
        lga_name_2021, 
        mb.mb_code21, 
        mb.wkb_geometry AS geom
    FROM 
        ptv.mb2021_mel mb, 
        ptv.lga2021 l
    WHERE 
        mb.mb_code21 = l.mb_code_2021
        AND 
        INITCAP(mb.mb_cat21) LIKE '%Residential%'
),

-- Calculate the count of non-blank spots by comparing bus stops to residential areas
ns AS (
    SELECT 
        s.lga_name_2021, 
        COUNT(DISTINCT r.mb_code21) AS non_blankspot
    FROM 
        lga_stop s, 
        lga_residential r
    WHERE 
        s.lga_name_2021 = r.lga_name_2021
        AND 
        st_within(s.geom, r.geom) 
    GROUP BY 
        s.lga_name_2021
),

-- Count the total residential areas in each LGA
ra as (
select
	lga_name_2021,
	COUNT(distinct mb_code21) as count_residential
from
	lga_residential
group by
	lga_name_2021
)

-- Final output comparing the non-blank spots to the total residential areas
select
	ns.lga_name_2021 as LGA_name,
	ROUND((count_residential - non_blankspot)::numeric / count_residential::numeric * 100,
	2) as blankspot_percentage,
	lga.geom
from
	ns,
	ra,
	lga
where
	ns.lga_name_2021 = ra.lga_name_2021
	and 
    ns.lga_name_2021 = lga.lga_name_2021;

alter table ptv.lga_blankspot add
column percentage_range VARCHAR(10);

update
	ptv.lga_blankspot
set
	percentage_range = case
		when blankspot_percentage <= 20 then 'X<=20%'
		when blankspot_percentage > 20
		and blankspot_percentage <= 40 then '20%<X<=40%'
		when blankspot_percentage > 40
		and blankspot_percentage <= 60 then '40%<X<=60%'
		when blankspot_percentage > 60
		and blankspot_percentage <= 80 then '60%<X<=80%'
		else 'X>=80%'
	end;

select
	*
from
	ptv.lga_blankspot;

