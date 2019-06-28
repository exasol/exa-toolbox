CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON SCALAR SCRIPT ST_GeomFromGeoJSON(g VARCHAR(2000000)) RETURNS VARCHAR(2000000) AS
## https://tools.ietf.org/html/rfc7946
import json
def point(coordinates):
 return str(coordinates[0])+" "+str(coordinates[1])   # 1 2

def linestring(coordinates):
 return "("+ (",".join(map(point,coordinates)))  +")" # (1 2, 3 4, 5 6)

def polygon(coordinates):
 return "("+ ",".join(map(linestring,coordinates))+")"

def geometry(geo):
 if geo["type"] == "Point":
  return "POINT ("+point(geo["coordinates"])+")"
 if geo["type"] == "MultiPoint":
  return "MULTIPOINT(" + ",".join(map(point,geo["coordinates"]))+")"
 if geo["type"] == "LineString":
  return "LINESTRING" + linestring(geo["coordinates"])
 if geo["type"] == "MultiLineString":
  return "MULTILINESTRING("+ ",".join(map(linestring,geo["coordinates"]))+")"
 if geo["type"] == "Polygon":
  return "POLYGON" + polygon(geo["coordinates"])
 if geo["type"] == "MultiPolygon":
  return "MULTIPOLYGON("+ ",".join(map(polygon,geo["coordinates"]))+")"
 if geo["type"] == "GeometryCollection":
  return "GEOMETRYCOLLECTION(" + ",".join(map(geometry, geo["geometries"])) + ")"


def run(ctx):
 geo = json.loads(ctx.g)
 return geometry(geo)
/

