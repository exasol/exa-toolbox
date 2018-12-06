/*
json_table.sql JSON data that is stored in EXASOL tables can be accessed through UDFs. 
This script presents a generic Python UDF json_table to access field values in JSON documents through path expressions. 
See also https://www.exasol.com/support/browse/SOL-570
*/
--/
create or replace python scalar script EXA_TOOLBOX.json_table(...) emits(...) as

import json

def run(ctx):
	try:
		obj = json.loads(ctx[0])
	except:
		raise Exception('Invalid JSON: '+ctx[0])

	if exa.meta.input_column_count != exa.meta.output_column_count+1:
		raise Exception('The UDF must be called with a JSON as first input parameter and one more input paramater for every output parameter')

	## find out the levels used in path expressions
	levels = {}
	for p in range(1, exa.meta.input_column_count):
		path = ctx[p]
		starpos = path.rfind('[*]')
		if starpos >= 0:										# $.attr[*].val or $.attr[*]
			if starpos != path.find('[*]'):						# two [*] found?
				raise Exception('Feature not supported: nested arrays')
			level = path[:starpos]								# $.attr
			if level not in levels: levels[level] = []
			levels[level].append(p)
		else:													# $.val
			if "$" not in levels: levels["$"] = []				# $
			levels["$"].append(p)


	## for each level evaluate path expression and generate parts
	## of the output table. The result table is the cross product of its parts.
	tbl = None
	for level, path_refs in levels.iteritems():
		tbl_part = []
		if level == "$": 
			if type(obj) is list:
				current = obj
			else:
				current = [ obj ]
		else:
			attr = level[2:]
			current = visit_path(obj, attr)

		for element in current:							# foreach child of $.attr
			row = {}
			for p in path_refs:
				path = ctx[p]
				if path.startswith(level+'[*]'):
					path = path[len(level)+4:]		# $.attr[*].subattr => subattr
				else:
					path = path[len(level)+1:]		# $.subattr => subattr
				val = visit_path(element, path)
				if val == None:
					val = None
				elif type(val) is list or type(val) is dict: 
					val = json.dumps(val)
				elif exa.meta.output_columns[p-1].type is decimal.Decimal:
					val = decimal.Decimal(val)
				elif exa.meta.output_columns[p-1].type is unicode and type(val) is not unicode:
					val = str(val)
				elif exa.meta.output_columns[p-1].type is datetime.date and type(val) is not datetime.date:
					val = datetime.datetime.strptime(val, '%Y-%m-%d').date()
				elif exa.meta.output_columns[p-1].type is datetime.datetime and type(val) is not datetime.datetime:
					val = datetime.datetime.strptime(val, '%Y-%m-%dT%H:%M:%S.%fZ')
				elif exa.meta.output_columns[p-1].type is float and type(val) is not float:
					val = float(val)
				elif exa.meta.output_columns[p-1].type is bool and type(val) is not bool:
					val = bool(val)
				elif exa.meta.output_columns[p-1].type is int and type(val) is not int:
					val = int(val)
				row[p] = val
			tbl_part.append(row)						

		tbl = cross_product(tbl, tbl_part)

	for row in tbl:
		rowarr = []
		for k,v in row.iteritems():
			rowarr.insert(k,v)
		ctx.emit(*rowarr)

	##for k, v in response.iteritems():
	##	ctx.emit(str(k), str(v))

def cross_product(a, b):
	if a == None: return b
	if b == None: return a
	res = []
	for aa in a:
		for bb in b:
			row = {}
			row.update(aa)
			row.update(bb)
			res.append(row)
	return res

# visit_path traverses a nested dictionary
# input: element["something"]["like"]["this"] = 5, 
#        path = "something.like.this"
# output: 5
def visit_path(element, path):
	val = element
	while path != '':
		dotpos = path.find('.')
		if dotpos < 0:		# no dot
			attr = path
			path = ''
		else:
			attr = path[:dotpos]
			path = path[dotpos+1:]
		if type(val) is not dict or attr not in val:
			return None
		val = val[attr]
	return val
/