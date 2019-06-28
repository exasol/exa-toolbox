CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE FUNCTION ST_HaversineDistance(geo1 GEOMETRY(4326), geo2 GEOMETRY(4326)) RETURN FLOAT IS
    R  FLOAT;

    φ1 FLOAT;
    λ1 FLOAT;
    φ2 FLOAT;
    λ2 FLOAT;

    Δφ FLOAT;
    Δλ FLOAT;

    a  FLOAT;
    c  FLOAT;
    d  FLOAT;

BEGIN
    IF ST_GeometryType(geo1) <> 'POINT' OR ST_GeometryType(geo2) <> 'POINT' THEN
        RETURN NULL;
    END IF;

    R  := 6378137; -- Earth equatorial radius in meters (WGS84)

    φ1 := RADIANS(ST_Y(geo1));
    λ1 := RADIANS(ST_X(geo1));

    φ2 := RADIANS(ST_Y(geo2));
    λ2 := RADIANS(ST_X(geo2));

    Δφ := φ2 - φ1;
    Δλ := λ2 - λ1;

    a  := SIN(Δφ / 2) * SIN(Δφ / 2) + COS(φ1) * COS(φ2) * SIN(Δλ / 2) * SIN(Δλ / 2);
    c  := 2 * ATAN2(SQRT(a), SQRT(1 - a));
    d  := R * c;

    RETURN d;
END ST_HaversineDistance;
/

-- EOF
