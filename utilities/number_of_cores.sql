/*

    Returns the number of cores of the database node that executes this UDF.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
create or replace python scalar script EXA_toolbox.number_of_cores() returns int as
import subprocess
def run(c):
  p=None
  try:
    p = subprocess.Popen("cat /proc/cpuinfo  | grep processor | wc -l",
                         stdout = subprocess.PIPE,
                         stderr = subprocess.PIPE,
                         close_fds = True,
                         shell = True)
    out, err = p.communicate()
    if err:
       return "ERROR: "+str(err)
    for line in out.strip().split('\n'):
        return int(line) # only return the first line
  finally:
     if p is not None:
        try: p.kill()
        except: pass
/

--/

-- Example:
-- SELECT number_of_cores();

-- EOF
