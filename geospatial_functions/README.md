# Table of Contents

<!-- toc -->

- [Geospatial functions](#geospatial-functions)
  * [Generic geospatial functions](#generic_geospatial_functions)
  * [ST_HaversineDistance](#st_haversinedistance)
  * [ST_GeomFromGeoJSON](#st_geomfromgeojson)

<!-- tocstop -->

# Geospatial functions

Exasol implements a subset of the geometry [types](https://docs.exasol.com/sql_references/geospatialdata.htm#GeospatialObjects), [methods and functions](https://docs.exasol.com/sql_references/geospatialdata.htm#GeospatialFunctions) of the [ISO/IEC 13249-3:2016 Information technology -- Database languages -- SQL multimedia and application packages -- Part 3: Spatial](https://www.iso.org/standard/60343.html) standard.

Various additonal geospatial functions have been produced as SQL function or as UDF to extend the coverage.

## Generic geospatial functions 

[geospatial_functions.sql](geospatial_functions.sql)

NOTE: Function overloading in Exasol SQL is not supported. Since a `GEOMETRY` datatype without spatial reference is a different from a `GEOMETRY` datatype with geospatial reference (e.g. `GEOMETRY(4326)`), separate functions are required to serve the different data types (used as input parameters). This file contains implementations for `GEOMETRY` datatype without spatial reference and with [World Geodetic System (WGS 1984 / EPSG:432)](https://en.wikipedia.org/wiki/World_Geodetic_System) spatial reference. You will need to adjust the function definitions if you need to use a different spatial reference. The list of supported spatial references can be found in the [EXA_SPATIAL_REF_SYS](https://docs.exasol.com/sql_references/metadata/metadata_system_tables.htm#EXA_SPATIAL_REF_SYS) table.

NOTE: Exasol stores geomatry objects internally as Well-Known Text (WKT), practically as `VARCHAR(2000000)` with the spatial reference metadata.

* Geometry constructors
  * `ST_Point` : Returns an `ST_Point` with the given coordinate values.
  * `ST_WKTToSQL` / `ST_GeomFromText` : Returns a specified `ST_Geometr`y value from WKT.
* Geometry accessors
  * `ST_XMax` / `ST_MaxX` : Returns X maxima of the bounding box of a geometry (as `FLOAT`).
  * `ST_XMin` / `ST_MinX` : Returns X minima of the bounding box of a geometry (as `FLOAT`).
  * `ST_YMax` / `ST_MaxY` : Returns Y maxima of the bounding box of a geometry (as `FLOAT`).
  * `ST_YMin` / `ST_MinY` : Returns Y minima of the bounding box of a geometry (as `FLOAT`).
* Geometry outputs
  * `ST_AsText` : Returns the WKT representation of the geometry/geography without SRID metadata.

The above functions with `GEOMETRY(4326)` are implemented as *WGS (e.g. `ST_MinXWGS`).

## ST_HaversineDistance

[ST_HaversineDistance.sql](ST_HaversineDistance.sql)

Implementation of the [Haversine formula](https://en.wikipedia.org/wiki/Haversine_formula) to the great-circle distance between two points on a sphere given their longitudes and latitudes. It uses [World Geodetic System (WGS 1984 / EPSG:432)](https://en.wikipedia.org/wiki/World_Geodetic_System) spatial reference.

## ST_GeomFromGeoJSON
[ST_GeomFromGeoJSON.sql](ST_GeomFromGeoJSON.sql)

Generates a WKT output from a [GeoJSON](https://geojson.org/) input.

