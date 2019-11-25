/*

    This UDF returns a scalar value from a JSON document (as string).
    It uses a JSONPath expression to locate the value in the document. See https://goessner.net/articles/JsonPath/ for details of JSONPath.

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT EXA_toolbox.json_value(json VARCHAR(2000000), json_path VARCHAR(2000000)) RETURNS VARCHAR(2000000) AS
#   Based on jsonpath by Philip Budne
#
#   http://www.ultimate.com/phil/python/#jsonpath
#
#	Copyright (c) 2007 Stefan Goessner (goessner.net)
#   Copyright (c) 2008 Kate Rhodes (masukomi.org)
#   Copyright (c) 2008-2018 Philip Budne (ultimate.com)
#	Licensed under the MIT licence:
#
#	Permission is hereby granted, free of charge, to any person
#	obtaining a copy of this software and associated documentation
#	files (the "Software"), to deal in the Software without
#	restriction, including without limitation the rights to use,
#	copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the
#	Software is furnished to do so, subject to the following
#	conditions:
#
#	The above copyright notice and this permission notice shall be
#	included in all copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#	OTHER DEALINGS IN THE SOFTWARE.

import json
import re
import sys


def normalize(x):
    """normalize the path expression; outside jsonpath to allow testing"""
    subx = []

    # replace index/filter expressions with placeholders
    # Python anonymous functions (lambdas) are cryptic, hard to debug
    def f1(m):
        n = len(subx)
        g1 = m.group(1)
        subx.append(g1)
        ret = "[#%d]" % n
        return ret

    x = re.sub(r"[\['](\??\(.*?\))[\]']", f1, x)
    x = re.sub(r"'?(?<!@)\.'?|\['?", ";", x)
    x = re.sub(r";;;|;;", ";..;", x)
    x = re.sub(r";$|'?\]|'$", "", x)

    def f2(m):
        g1 = m.group(1)
        return subx[int(g1)]

    x = re.sub(r"#([0-9]+)", f2, x)

    return x


def jsonpath(obj, expr, result_type='VALUE', use_eval=True):
    def s(x, y):
        return str(x) + ';' + str(y)

    def isint(x):
        return x.isdigit()

    def as_path(path):
        p = '$'
        for piece in path.split(';')[1:]:
            if isint(piece):
                p += "[%s]" % piece
            else:
                p += "['%s']" % piece
        return p

    def store(path, object):
        if result_type == 'VALUE':
            result.append(object)
        elif result_type == 'IPATH':
            result.append(path.split(';')[1:])
        else:  # PATH
            result.append(as_path(path))
        return path

    def trace(expr, obj, path):
        if expr:
            x = expr.split(';')
            loc = x[0]
            x = ';'.join(x[1:])
            if loc == "*":
                def f03(key, loc, expr, obj, path):
                    trace(s(key, expr), obj, path)

                walk(loc, x, obj, path, f03)
            elif loc == "..":
                trace(x, obj, path)

                def f04(key, loc, expr, obj, path):
                    if isinstance(obj, dict):
                        if key in obj:
                            trace(s('..', expr), obj[key], s(path, key))
                    else:
                        if key < len(obj):
                            trace(s('..', expr), obj[key], s(path, key))

                walk(loc, x, obj, path, f04)
            elif loc == "!":
                def f06(key, loc, expr, obj, path):
                    if isinstance(obj, dict):
                        trace(expr, key, path)

                walk(loc, x, obj, path, f06)
            elif isinstance(obj, dict) and loc in obj:
                trace(x, obj[loc], s(path, loc))
            elif isinstance(obj, list) and isint(loc):
                iloc = int(loc)
                if len(obj) > iloc:
                    trace(x, obj[iloc], s(path, loc))
            else:
                if loc.startswith("(") and loc.endswith(")"):
                    e = evalx(loc, obj)
                    trace(s(e, x), obj, path)
                    return

                if loc.startswith("?(") and loc.endswith(")"):
                    def f05(key, loc, expr, obj, path):
                        if isinstance(obj, dict):
                            eval_result = evalx(loc, obj[key])
                        else:
                            eval_result = evalx(loc, obj[int(key)])
                        if eval_result:
                            trace(s(key, expr), obj, path)

                    loc = loc[2:-1]
                    walk(loc, x, obj, path, f05)
                    return

                m = re.match(r'(-?[0-9]*):(-?[0-9]*):?(-?[0-9]*)$', loc)
                if m:
                    if isinstance(obj, (dict, list)):
                        def max(x, y):
                            if x > y:
                                return x
                            return y

                        def min(x, y):
                            if x < y:
                                return x
                            return y

                        objlen = len(obj)
                        s0 = m.group(1)
                        s1 = m.group(2)
                        s2 = m.group(3)

                        start = int(s0) if s0 else 0
                        end = int(s1) if s1 else objlen
                        step = int(s2) if s2 else 1

                        if start < 0:
                            start = max(0, start + objlen)
                        else:
                            start = min(objlen, start)
                        if end < 0:
                            end = max(0, end + objlen)
                        else:
                            end = min(objlen, end)

                        for i in range(start, end, step):
                            trace(s(i, x), obj, path)
                    return

                if loc.find(",") >= 0:
                    for piece in re.split(r"'?,'?", loc):
                        trace(s(piece, x), obj, path)
        else:
            store(path, obj)

    def walk(loc, expr, obj, path, funct):
        if isinstance(obj, list):
            for i in range(0, len(obj)):
                funct(i, loc, expr, obj, path)
        elif isinstance(obj, dict):
            for key in obj:
                funct(key, loc, expr, obj, path)

    def evalx(loc, obj):
        loc = loc.replace("@.length", "len(__obj)")

        loc = loc.replace("&&", " and ").replace("||", " or ")

        def notvar(m):
            return "'%s' not in __obj" % m.group(1)

        loc = re.sub("!@\.([a-zA-Z@_]+)", notvar, loc)

        def varmatch(m):
            def brackets(elts):
                ret = "__obj"
                for e in elts:
                    if isint(e):
                        ret += "[%s]" % e
                    else:
                        ret += "['%s']" % e
                return ret

            g1 = m.group(1)
            elts = g1.split('.')
            if elts[-1] == "length":
                return "len(%s)" % brackets(elts[1:-1])
            return brackets(elts[1:])

        loc = re.sub(r'(?<!\\)(@\.[a-zA-Z@_.]+)', varmatch, loc)

        loc = re.sub(r'(?<!\\)@', "__obj", loc).replace(r'\@', '@')
        if not use_eval:
            raise Exception("eval disabled")
        try:
            v = eval(loc, caller_globals, {'__obj': obj})
        except Exception as e:
            return False

        return v

    # Body of jsonpath()
    caller_globals = sys._getframe(1).f_globals
    result = []
    if expr and obj:
        cleaned_expr = normalize(expr)
        if cleaned_expr.startswith("$;"):
            cleaned_expr = cleaned_expr[2:]

        trace(cleaned_expr, obj, '$')

        if len(result) > 0:
            return result

    return False


def run(ctx):
    try:
        j = json.loads(ctx[0])
    except:
        raise Exception('Invalid JSON: ' + ctx[0])
    p = ctx[1]

    value = jsonpath(j, p)

    if not value:
        return (None)

    if len(value) == 1:
        val = value[0]
        
        if not val:
                return (None)
        
        if type(val) is list or type(val) is dict:
            val = json.dumps(val, ensure_ascii=False)
        else:
            val = str(val)
        return (val)

    return (json.dumps(value))
/
-- Examples:

-- SELECT json_value('{"id":1,"first_name":"Mark","last_name":"Trenaman","info":{"phone":"573-411-0171","city":"Washington", "hobbies":["sport", "music", "reading"]}}', '$.id');
-- SELECT json_value('{"id":2,"first_name":"Lisa","last_name":"Kemer","info":{"phone":"601-112-0724","city":"Berlin", "hobbies":["dancing", "cooking"]}}', '$.info.hobbies');
-- SELECT json_value('{"people": [{"name": "Naomi", "age": 35, "colour": "green"}, {"name": "Amos", "age": 24, "colour": ["red", "green", "blue"]}]}', '$.people.*.colour');

-- EOF
