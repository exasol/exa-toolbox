CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

-- Functions without spatial reference

-- ST_AsText
--/
CREATE OR REPLACE FUNCTION ST_AsText(geo GEOMETRY) RETURN VARCHAR(2000000) IS
BEGIN
    RETURN CAST(geo AS VARCHAR(2000000));
END ST_AsText;
/

-- ST_MinX, ST_MinY, ST_MaxX, ST_MaxY
--/
CREATE OR REPLACE FUNCTION ST_MinX(geo GEOMETRY) RETURN FLOAT IS
    env GEOMETRY;
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_X(env);
    END IF;
    RETURN ST_X(ST_PointN(ST_ExteriorRing(env),1));
END ST_MinX;
/

--/
CREATE OR REPLACE FUNCTION ST_MinY(geo GEOMETRY) RETURN FLOAT IS
    env GEOMETRY;
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_Y(env);
    END IF;
    RETURN ST_Y(ST_PointN(ST_ExteriorRing(env),1));
END ST_MinY;
/

--/
CREATE OR REPLACE FUNCTION ST_MaxX(geo GEOMETRY) RETURN FLOAT IS
    env GEOMETRY;
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_X(env);
    END IF;
    RETURN ST_X(ST_PointN(ST_ExteriorRing(env),2));
END ST_MaxX;
/

--/
CREATE OR REPLACE FUNCTION ST_MaxY(geo GEOMETRY) RETURN FLOAT IS
    env GEOMETRY;
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_Y(env);
    END IF;
    RETURN ST_Y(ST_PointN(ST_ExteriorRing(env),3));
END ST_MaxY;
/

--/
CREATE OR REPLACE FUNCTION ST_XMin(geo GEOMETRY) RETURN FLOAT IS
BEGIN
    RETURN ST_MinX(geo);
END ST_XMin;
/

--/
CREATE OR REPLACE FUNCTION ST_YMin(geo GEOMETRY) RETURN FLOAT IS
BEGIN
    RETURN ST_MinY(geo);
END ST_YMin;
/

--/
CREATE OR REPLACE FUNCTION ST_XMax(geo GEOMETRY) RETURN FLOAT IS
BEGIN
    RETURN ST_MaxX(geo);
END ST_XMax;
/

--/
CREATE OR REPLACE FUNCTION ST_YMax(geo GEOMETRY) RETURN FLOAT IS
BEGIN
    RETURN ST_MaxY(geo);
END ST_YMax;
/

-- ST_Point
--/
CREATE OR REPLACE FUNCTION ST_Point(x_lon FLOAT, y_lat FLOAT) RETURN GEOMETRY IS
BEGIN
    RETURN CAST('POINT(' || TO_CHAR(x_lon) || ' ' || TO_CHAR(y_lat) || ')' AS GEOMETRY);
END;
/

-- ST_WKTToSQL
--/
CREATE OR REPLACE FUNCTION ST_WKTToSQL(wkt VARCHAR(2000000)) RETURN GEOMETRY IS
BEGIN
    RETURN CAST(wkt AS GEOMETRY);
END ST_WKTToSQL;
/

-- ST_GeomFromText
--/
CREATE OR REPLACE FUNCTION ST_GeomFromText(txt VARCHAR(2000000)) RETURN GEOMETRY IS
BEGIN
    RETURN ST_WKTToSQL(txt);
END ST_GeomFromText;
/

-- Functions with WGS 1984 / EPSG:4326
-- Function overloading is not supported, thus SRID specific implementations are required.

-- ST_AsText
--/
CREATE OR REPLACE FUNCTION ST_AsTextWGS(geo GEOMETRY(4326)) RETURN VARCHAR(2000000) IS
BEGIN
    RETURN CAST(geo AS VARCHAR(2000000));
END ST_AsTextWGS;
/

-- ST_MinX, ST_MinY, ST_MaxX, ST_MaxY
--/
CREATE OR REPLACE FUNCTION ST_MinXWGS(geo GEOMETRY(4326)) RETURN FLOAT IS
    env GEOMETRY(4326);
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_X(env);
    END IF;
    RETURN ST_X(ST_PointN(ST_ExteriorRing(env),1));
END ST_MinXWGS;
/

--/
CREATE OR REPLACE FUNCTION ST_MinYWGS(geo GEOMETRY(4326)) RETURN FLOAT IS
    env GEOMETRY(4326);
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_Y(env);
    END IF;
    RETURN ST_Y(ST_PointN(ST_ExteriorRing(env),1));
END ST_MinYWGS;
/

--/
CREATE OR REPLACE FUNCTION ST_MaxXWGS(geo GEOMETRY(4326)) RETURN FLOAT IS
    env GEOMETRY(4326);
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_X(env);
    END IF;
    RETURN ST_X(ST_PointN(ST_ExteriorRing(env),2));
END ST_MaxXWGS;
/

--/
CREATE OR REPLACE FUNCTION ST_MaxYWGS(geo GEOMETRY(4326)) RETURN FLOAT IS
    env GEOMETRY(4326);
BEGIN
    env := ST_Envelope(geo);
    IF ST_GeometryType(env) = 'POINT' THEN
        RETURN ST_Y(env);
    END IF;
    RETURN ST_Y(ST_PointN(ST_ExteriorRing(env),3));
END ST_MaxYWGS;
/

-- ST_Point
--/
CREATE OR REPLACE FUNCTION ST_PointWGS(x_lon FLOAT, y_lat FLOAT) RETURN GEOMETRY(4326) IS
BEGIN
    RETURN CAST('POINT(' || TO_CHAR(x_lon) || ' ' || TO_CHAR(y_lat) || ')' AS GEOMETRY(4326));
END;
/

-- ST_WKTToSQL
--/
CREATE OR REPLACE FUNCTION ST_WKTToSQLWGS(wkt VARCHAR(2000000)) RETURN GEOMETRY(4326) IS
BEGIN
    RETURN CAST(wkt AS GEOMETRY(4326));
END ST_WKTToSQLWGS;
/

--/
CREATE OR REPLACE FUNCTION ST_GeomFromTextWGS(txt VARCHAR(2000000)) RETURN GEOMETRY(4326) IS
BEGIN
    RETURN ST_WKTToSQLWGS(txt);
END ST_GeomFromTextWGS;
/

-- EOF
