/*

    These UDF scripts retrieve details of the various language environments deployed in Exasol.
    Details include version, modules/packages and environment info.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE R SCALAR SCRIPT r_info(all_details BOOLEAN) EMITS (key VARCHAR(200), val VARCHAR(100000)) AS
run <- function(ctx) {

    getPkgDetails <- function(L, n) {
        pkg <-  sapply(L[[n]], function(x) x[["Package"]])
        vers <- sapply(L[[n]], function(x) x[["Version"]])
        paste(pkg, vers, sep = " ")
    }

    s <- sessionInfo()
    ctx$emit("exa.meta.script_language", exa$meta$script_language)
    if (ctx$all_details) {
        ctx$emit("R.version$language",       s$R.version$language)
        ctx$emit("R.version$version.string", s$R.version$version.string)
        ctx$emit("R.version$nickname",       s$R.version$nickname)
        ctx$emit("R.version$major",          s$R.version$major)
        ctx$emit("R.version$minor",          s$R.version$minor)
        ctx$emit("R.version$year",           s$R.version$year)
        ctx$emit("R.version$month",          s$R.version$month)
        ctx$emit("R.version$day",            s$R.version$day)
        ctx$emit("R.version$svn rev",        s$R.version$`svn rev`)
        ctx$emit("R.version$platform",       s$R.version$platform)
        ctx$emit("R.version$arch",           s$R.version$arch)
        ctx$emit("R.version$os",             s$R.version$os)
        ctx$emit("R.version$system",         s$R.version$system)
        ctx$emit("R.version$status",         s$R.version$status)
        ctx$emit("platform",                 s$platform);
        ctx$emit("running",                  s$running)
        if (!is.null(s$matprod)) {
            ctx$emit("matprod",              s$matprod)
        }
        if (!is.null(s$BLAS)) {
            ctx$emit("BLAS",                 s$BLAS)
        }
        if (!is.null(s$LAPACK)) {
            ctx$emit("LAPACK",               s$LAPACK)
        }
        ctx$emit("locale", s$locale)
        if (!is.null(s$basePkgs)) {
            ctx$emit("basePkgs",             s$basePkgs)
        }
        if (!is.null(s$otherPkgs)) {
            ctx$emit("otherPkgs",            getPkgDetails(s, "otherPkgs"))
        }
        if (!is.null(s$otherPkgs)) {
            ctx$emit("loadedOnly",           getPkgDetails(s, "loadedOnly"))
        }
    }
}
/

--/
CREATE OR REPLACE PYTHON SCALAR SCRIPT python_info(all_details BOOLEAN) EMITS (key VARCHAR(200), val VARCHAR(100000)) AS

import pkg_resources
import pkgutil

def run(ctx):
    ctx.emit("exa.meta.script_language", exa.meta.script_language)
    if ctx.all_details:
        ctx.emit("sys.version",                       sys.version)
        ctx.emit("sys.byteorder",                     sys.byteorder)
       #ctx.emit("sys.copyright",                     sys.copyright)
       #ctx.emit("sys.builtin_module_names",      str(sys.builtin_module_names))
       #ctx.emit("sys.modules.keys",              str(sys.modules.keys()))
        ctx.emit("sys.path",                      str(sys.path))
        ctx.emit("sys.platform",                      sys.platform)
        ctx.emit("sys.version_info.major",        str(sys.version_info.major))
        ctx.emit("sys.version_info.minor",        str(sys.version_info.minor))
        ctx.emit("sys.version_info.micro",        str(sys.version_info.micro))
        ctx.emit("sys.version_info.releaselevel",     sys.version_info.releaselevel)
        ctx.emit("sys.version_info.serial",       str(sys.version_info.serial))
        ws = sorted([p.project_name + ' ' + p.version for p in pkg_resources.working_set], key=str.lower)
        for p in ws:
            ctx.emit("package", p)
        ms = sorted([mo[1] for mo in pkgutil.iter_modules()], key=str.lower)
        for m in ms:
            ctx.emit("module", m)
/

--/
CREATE OR REPLACE LUA SCALAR SCRIPT lua_info(all_details BOOLEAN) EMITS (key VARCHAR(200), val VARCHAR(100000)) AS

function run(ctx)
    ctx.emit("exa.meta.script_language", exa.meta.script_language)
    if ctx.all_details then
        ctx.emit("_VERSION", _VERSION)

        local pkgs = {}
        for pkg in pairs(package.loaded) do
            pkgs[#pkgs + 1] = pkg
        end
        table.sort(pkgs)
        for k,v in ipairs(pkgs) do
            pkg = package.loaded[v]
            if type(pkg) == "table" then
                ctx.emit("package", v)
            end
        end
    end
end
/

--/
CREATE OR REPLACE JAVA SCALAR SCRIPT java_info(all_details BOOLEAN) EMITS (key VARCHAR(200), val VARCHAR(100000)) AS

import java.util.*;

class JAVA_INFO {

    static void run(ExaMetadata exa, ExaIterator ctx) throws Exception {
        ctx.emit("exa.meta.script_language", exa.getScriptLanguage());
        if(ctx.getBoolean("all_details")) {
            ctx.emit("exa.meta.MemoryLimit", String.valueOf(exa.getMemoryLimit()));

            // Environment
            TreeMap<String,String> envs = new TreeMap<String,String>(System.getenv());
            for(Map.Entry<String,String> entry: envs.entrySet()) {
                ctx.emit("env." + entry.getKey(), entry.getValue());
            }

            // Properties
            TreeMap<Object,Object> props = new TreeMap<Object,Object>(System.getProperties());
            for(Map.Entry<Object,Object> entry: props.entrySet()) {
                ctx.emit("prop." + entry.getKey().toString(), entry.getValue().toString());
            }

            // Packages
            Package[] pkgs = Package.getPackages();
            String[] pkgNames = new String[pkgs.length];
            for(int i=0; i<pkgs.length; i++) {
                pkgNames[i] = pkgs[i].getName();
            }
            Arrays.sort(pkgNames);
            for(int i=0; i<pkgs.length; i++) {
                ctx.emit("package", pkgNames[i]);
            }
        }
    }
}
/

-- Examples:
-- SELECT r_info(TRUE);
-- SELECT python_info(TRUE);
-- SELECT lua_info(TRUE);
-- SELECT java_info(TRUE);

-- EOF
