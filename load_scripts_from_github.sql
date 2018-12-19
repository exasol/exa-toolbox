-- see second script contained in this file for actual functionality

CREATE SCHEMA IF NOT EXISTS EXA_TOOLBOX;

-- ****************************************
--
--  Get SQL scripts from Github
--
--  Loads scripts from public Github repos and executes the contained files so that the 
--  scripts are available in the database. Only loads files ending with '.sql'
--  Needs an internet connection to work.
--
--  Parameters:
--		repository: URL of the Github repository to get, e.g. 'https://EXA_TOOLBOX.com/EXASOL/database-migration'
-- 		search_subfolders:	if true, search also the folders contained in the repository recursively
--		exclude_folders:	String containing folders that should be excluded from search, specify multiple folders
--							by separating them with a comma, e.g. 'test,secret_folder' 
--
--  Returns table containing:
--		repository,	e.g. 'EXASOL/database-migration/master'
--		filename,		e.g. 'db2_to_exasol.sql'
--		link,			e.g. 'https://raw.githubusercontent.com/EXASOL/database-migration/master/db2_to_exasol.sql'
--		content,		e.g. 'create schema data...'
-- ****************************************
--/
CREATE OR REPLACE PYTHON SCALAR SCRIPT EXA_TOOLBOX.GITHUB_LOAD_SCRIPTS_GET_CONTENT("repo" varchar(4096), "search_subfolders" boolean, "exclude_folders" varchar(4096))
EMITS ("repository" varchar(2000) UTF8, "filename" varchar(2000) UTF8, "link" varchar(2000) UTF8, "content" varchar(2000000) UTF8)
AS

import urllib2
import socket


from HTMLParser import HTMLParser
#################### Class Git Link Parser ##############################
class File_Item:
    repository = ''
    filename = ''
    link = ''
#################### Class Git Link Parser ##############################
# This class can be used to get all the links that are in the table of a github page
class GitLinkParser(HTMLParser):

    def __init__(self):
        HTMLParser.__init__(self)
        self.in_filelist = False
        self.file_list = []
        self.folder_list = []

#---------------------------------------------------------------#

    def feed(self, data):
        self.in_filelist = False
        self.file_list = []
        self.folder_list = []
        HTMLParser.feed(self,data)
#---------------------------------------------------------------#    
    # check for element which contains all the files on github page
    # this check is used to make sure not to include objects mentioned in the readme.md below filelist 
    def check_for_file_container(self, tag, attrs):
        if tag == 'table':
            for attr_name, attr_value_raw in attrs:
                attr_value = str(attr_value_raw)
                if attr_name =='class' and attr_value.find('files') != -1 and attr_value.find('js-navigation-container') != -1:
                    self.in_filelist = True 

#---------------------------------------------------------------#
    # should be used for tags of type <a>
    # adds the title and link to raw code to file_list
    def add_link_to_list(self, attrs):
        title = ''
        link = ''
        ignoreFile = False
        isSqlFile = False
        isFolder = False

        for attr_name, attr_value_raw in attrs:
           attr_value = str(attr_value_raw)
           if attr_name == 'href' and attr_value.endswith('.sql'):
                isSqlFile = True
                link = 'https://raw.githubusercontent.com' + attr_value.replace('blob/', '')
                title = attr_value.replace('blob/', '')
                
           if attr_name == 'href' and attr_value.find('.') == -1 and attr_value.find('tree') != -1:
               isFolder = True
               link = 'https://github.com' + attr_value
           if attr_name == 'title' and attr_value.find('Go to parent directory') != -1:
               ignoreFile = True

        ## after for-loop, decide whether or not to add link
        if isSqlFile:
            slash_pos = title.rfind('/')
            item = File_Item()
            item.repository = title[1:slash_pos]
            item.filename = title[slash_pos+1:len(title)]
            item.link = link
            self.file_list.append(item)
        if isFolder and (not ignoreFile):
            self.folder_list.append(link)


#---------------------------------------------------------------#
    def handle_starttag(self, tag, attrs):

        # sets self.in_filelist to true if in container
        self.check_for_file_container(tag, attrs)

        # if element is a link and we are in the file-list: check for file extension
        if tag == 'a' and self.in_filelist:
            self.add_link_to_list(attrs)
            
#---------------------------------------------------------------#
    # basic implementation. As all links are included in the same div, if a div ends, we do not want to read any more files until the next one starts 
    def handle_endtag(self, tag):
        
        if tag == 'table':
            self.in_filelist = False


################ End Class Git Link Parser ##############################
################ Start actual script  ###################################


def get_folders_and_file_links_helper(repo, ctx):
    data = urllib2.urlopen(repo)
    contents = data.read()
    parser = GitLinkParser()
    parser.feed(contents)
    return parser.folder_list, parser.file_list;

    
#---------------------------------------------------------------#

# checks whether path ends with one of the elements in input_list
# if input_list is empty, returns false
def path_ends_with(path, input_list):
    if len(input_list) == 0 or len(input_list[0]) == 0:
        return False
    for foldername in input_list:
            if path.endswith('/'+ foldername):
              return True

#---------------------------------------------------------------#
def get_files(repo, search_recursive, exclude_folders, ctx):
    folders_to_search = []
    searched_folders = []
    files = []
    folders_to_search.append(repo)

    while (len(folders_to_search) > 0):
        curr_folder = folders_to_search.pop()
        # do not add the same string twice
        if curr_folder in searched_folders:
            continue
        # continue if curr_folder should be excluded
        if path_ends_with(curr_folder, exclude_folders):
            continue
        searched_folders.append(curr_folder)
        # ctx.emit('DEBUG: Current folder', curr_folder, '', '')
        new_folders, new_files = get_folders_and_file_links_helper(curr_folder, ctx)

        if(search_recursive):
            folders_to_search.extend(new_folders)
        files.extend(new_files)

    return  files
    

#---------------------------------------------------------------#

import ctypes
import os

def run(ctx):
    
    exclude_folders = str(ctx.exclude_folders).split(',')

    try:
        file_list = get_files(ctx.repo, ctx.search_subfolders,exclude_folders, ctx)
    except urllib2.URLError as e:
        raise Exception('Could not establish a connection to Github. Please make sure your database has a connection to the internet.')

    
    for item in file_list:
        try:
            data = urllib2.urlopen(item.link)
            content = data.read()
            ctx.emit(item.repository, item.filename, item.link, content)
        except Exception as e:
            ctx.emit('ERROR on '+ item.link,str(e),'', '')
        

/

--SELECT EXA_TOOLBOX.GITHUB_LOAD_SCRIPTS_GET_CONTENT('https://github.com/EXASOL/database-migration', true, 'test') res FROM dual;
-- SELECT EXA_TOOLBOX.GITHUB_LOAD_SCRIPTS_GET_CONTENT('https://github.com/EXASOL/virtual-schemas', true) res FROM dual;


-- ****************************************
--
--  Load scripts from Github
--
--  Loads scripts from public Github repos and executes the contained files so that the 
--  scripts are available in the database. Needs an internet connection to work.
--
--  Parameters:
--		repository:			URL of the Github repository to search, e.g. 'https://EXA_TOOLBOX.com/EXASOL/database-migration'
--		file_filter:		only files that match the file filter will be loaded into the database. if left blank, all files are loaded. e.g. '' or 'to_exasol'
--		files_to_exclude:	Comma seperated list of files you don't want to execute even though they match the file_filter, e.g. 'Example.sql,Dummy.sql'
--		search_recursive:	if true, search also the folders contained in the repository recursively
--		exclude_folders: 	String containing folders that should be excluded from search, specify multiple folders
--							by separating them with a comma, e.g. 'test,secret_folder' 
--
--  Returns:
-- 		Table containing information on which files were loaded
--
-- ****************************************
--/
CREATE OR REPLACE LUA SCRIPT EXA_TOOLBOX.GITHUB_LOAD_SCRIPTS(repository, file_filter, files_to_exclude, search_recursive, exclude_folders) RETURNS TABLE AS


-- checks whether the content of tokenlist starting at strt is a script
-- returns: String - statementType, String - scriptType, String -scriptName,  String -scriptComment
function getStmtType(tokenlist, strt)
	
	stmtType = 'STATEMENT'
	scriptType = 'LUA' -- LUA is the default, other possible values are: JAVA, PYTHON, R
	scriptComment = '' -- Collect comments before 'CREATE'-keyword in this String

	-- search for first token that is no comment or whitespace
	while( sqlparsing.iswhitespaceorcomment(tokenlist[strt]) and strt < #tokenlist) do
		scriptComment = scriptComment .. tokenlist[strt]
		strt = strt + 1
	end

	if(sqlparsing.normalize(tokenlist[strt]) ~= "CREATE") then
		return stmtType, 'NONE' , '', ''
	end

	-- after a create, the next 7 tokens must contain 'script' in order to be a proper script
	-- Maximum number of tokens between CREATE and SCRIPT: 7
	-- CREATE OR REPLACE SCALAR LUA SCRIPT
	nr_search_to = math.min(#tokenlist, strt + 7)
	output('search from '..strt..' until token '..nr_search_to)

	-- use while-loop instead of for-loop here because nr_search_to gets changed in loop
	i = strt + 1;
	while( i <= nr_search_to) do

		-- determine script type. must be explicitly  given if other than lua
		if (tokenlist[i] == 'PYTHON') or (tokenlist[i] == 'JAVA') or (tokenlist[i] == 'R') then
			scriptType = tokenlist[i]
		end
		
		-- if there's a comment token, enlarge the search space by one
		if(sqlparsing.iswhitespaceorcomment(tokenlist[i]) ) then
			
			if (nr_search_to < #tokenlist) then
				output('Whitespace or comment in script search space --> skip token and enlarge search space by one')
				nr_search_to = nr_search_to +1
			end
		else
			if(string.find(tokenlist[i], ';')) then
				output('found semicolon before "SCRIPT"-keyword --> no script')
				return stmtType, 'NONE', '', ''
			end
			output('search for "SCRIPT" or "FUNCTION" in '.. sqlparsing.normalize(tokenlist[i]))
			tok = sqlparsing.normalize(tokenlist[i]) 
			if (tok == "SCRIPT" or tok == "FUNCTION") then
				stmtType = tok
				-- find token containing script name
				name_search_pos = i + 1
				while( (not sqlparsing.isidentifier(tokenlist[name_search_pos])) and name_search_pos < #tokenlist) do
					name_search_pos = name_search_pos + 1
				end
				scriptName = tokenlist[name_search_pos]
				return stmtType, scriptType, scriptName, scriptComment
			end
		end
	i = i +1
	end -- end while-loop
	return stmtType, 'NONE', '', ''

end

---------------------------------------------------------------------------------
-- get rid of whitespaces and tabs
-- then check if remaining token start with a newline
function starts_with_newline(token)
	t = string.gsub(token, ' ', '')
	t = string.gsub(t, '	', '')
	t = string.gsub(t, '\n+', '\n')

	nl = '\n'
	return t:sub(1, #nl) == nl
end

-- check if last token is a newline
function ends_with_newline(token)
	nl = '\n'
   return token:sub(-#nl) == nl
end

---------------------------------------------------------------------------------
-- returns token number of '/' if tokenstring contains newline followed by '/'
function findScriptEnd(tokenlist, startToken)
	for i = startToken + 1, #tokenlist do
		if (ends_with_newline(tokenlist[i-1]) and tokenlist[i] == '/') or tokenlist[i] == '\n/\n' then
			-- check if the slash is really the end of the script. this is the case if the slash is either
			-- the last token or there are only spaces, tabs and one newline in the next one
			
			if(i+1 > #tokenlist or (i+1 <= #tokenlist and starts_with_newline(tokenlist[i+1]))) then
				return i
			end
		end
	end
	return nil
end

---------------------------------------------------------------------------------

-- split by delimiter into array and include delimiter also in the array
function split(str, delim)
   -- Eliminate bad cases...
   if string.find(str, delim) == nil then
      return { str }
   end

   local result = {}
   local pat = "(.-)" .. delim .. "()"
   local nb = 0
   local lastPos
   for part, pos in string.gfind(str, pat) do
      nb = nb + 1
      result[nb] = part
	  nb = nb + 1
	  result[nb] = delim
      lastPos = pos

   end
   -- Handle the last field
	rest = string.sub(str, lastPos)
	if( rest ~= nil and #rest ~= 0) then
		result[nb + 1] = rest
	end

   return result
end

---------------------------------------------------------------------------------
-- create a new tokenlist that is also splitted by CRLF / CRLF
function splitBySlash(tokenlist)
-- create a string that contains a CRLF
scriptEndToken = '\n/\n'

	new_tokenlist = {}
	for i = 1, #tokenlist do
		if string.find(tokenlist[i],scriptEndToken) then
			splitted = split(tokenlist[i], scriptEndToken)
			for j = 1, #splitted do
				table.insert(new_tokenlist, splitted[j])
			end
		else
			table.insert(new_tokenlist, tokenlist[i])
		end
	end
return new_tokenlist
end

---------------------------------------------------------------------------------
-- returns a table containing an entry for each statement of script file, each row consists of:
-- stmt, stmtType, scriptName, scriptComment
function getStatements(script_file)
	statements = {}

	tokenlist = sqlparsing.tokenize(script_file)
	tokenlist = splitBySlash(tokenlist)
	
	startTokenNr = 1
	searchForward = true
	searchSameLevel = false
	ignoreFunction = sqlparsing.iswhitespaceorcomment
	stmtEnd = ';'
	skriptStart= 'CREATE'

-- Debugging --------
-- output('---- TOKENLIST START ----')
-- 	for i = 1, #tokenlist do
-- 		output(i..'	'..tokenlist[i])
-- 	end
-- output('---- TOKENLIST END ----')
-- Debugging --------
	
	
	while startTokenNr <= #tokenlist do
		
		-- check if the next statement is a script
		stmtType, scriptType, scriptName, scriptComment = getStmtType(tokenlist, startTokenNr)
		if (isScriptOrFunction(stmtType)) then
			output('---> is script. Search for / starting at '.. startTokenNr)
			-- check whether token before / is a newline, if not, it's no proper script end
			endTokenNr = findScriptEnd(tokenlist, startTokenNr)
			if endTokenNr ~= nil then
				output('End token nr is '..endTokenNr..' text: '..tokenlist[endTokenNr])
			end

		else
			output('---> is NO script. Search for '..stmtEnd..' starting at '.. startTokenNr)
			endTokenNr = sqlparsing.find(tokenlist, startTokenNr, searchForward, searchSameLevel, ignoreFunction, stmtEnd)
			if endTokenNr ~= nil then
				endTokenNr = endTokenNr[1]
				output('End token nr is '..endTokenNr..' text: '..tokenlist[endTokenNr])
			end
		end
		
		if endTokenNr == nil then
			output('No endtoken found, setting to #tokenlist: '.. #tokenlist)
			endTokenNr = #tokenlist
		end

		stmt = {unpack(tokenlist, startTokenNr, endTokenNr)}
		stmt = table.concat(stmt, "")
		table.insert(statements, {stmt, stmtType, scriptName, scriptComment})
		startTokenNr = endTokenNr  + 1

	end
	return statements
end

-- check whether input text is SCRIPT or FUNCTION
function isScriptOrFunction(stmt_type)
	if(stmt_type == 'SCRIPT' or stmt_type == 'FUNCTION') then
		return true
	else
		return false
	end
end

-- executes all statements contained in script_statements ahead of first script 
-- and adds statements contained in script_statements after script as a comment to the script
function execute_scripts_with_comments(filename, script_statements)
	
	info = {}
	execute_this = true
	script_name = ''

----------------
	-- script_statements[j][2] contains: stmt_is_script
	-- all statemtns before first script: put execute flag
	j = 1
	while (j <= #script_statements and  (isScriptOrFunction(script_statements[j][2]) == false)) do
		stmt 				= script_statements[j][1]
		stmt_type 			= script_statements[j][2]
		stmt_name 			= script_statements[j][3]

		execute_this = true
		add_as_comment = ''
		executed = ''
		table.insert(info, {filename, stmt_name, stmt, stmt_type, execute_this, add_as_comment, executed})

		j = j +1
	end
	
	-- this part is executed after for all the scripts
	while (j <= #script_statements) do

		stmt 			= script_statements[j][1]
		stmt_type 		= script_statements[j][2]
		stmt_name 		= script_statements[j][3]
		add_as_comment 	= script_statements[j][4]

		execute_this = false
		executed = ''

		if ( isScriptOrFunction(stmt_type)) then
			execute_this = true

			-- collect all the comments, this are all statements where is_script is false
			c = j + 1
			while (c <= #script_statements and  (not script_statements[c][2])) do
				comment_stmt = script_statements[c][1]
				add_as_comment = add_as_comment .. comment_stmt

				c = c + 1
			end
		end
		table.insert(info, {filename, stmt_name, stmt, stmt_type, execute_this, add_as_comment, executed})
		j = j +1
	end


	-- for-loop to actually execute the statements collected in info-table
	for j = 1, #info do
		stmt_name 		= info[j][2]
		stmt 			= info[j][3]
		stmt_type	 	= info[j][4]
		execute_this	= info[j][5]
		add_as_comment 	= info[j][6]
		executed_this_stmt = ''
	
		if ( execute_this) then
			stmt_suc, stmt_res = pquery(stmt)
			if stmt_suc then 
				executed_this_stmt = 'YES'
			else
				executed_this_stmt = 'FAILED: '.. stmt_res.error_message
			end
		end

		if (add_as_comment ~= '') then
			stmt_suc, stmt_res = pquery([[comment on ]]..stmt_type..[[ ::s is :c]], {s=stmt_name, c=add_as_comment})
			if stmt_suc then
				executed_this_stmt = executed_this_stmt ..' , and commented'
			else
				executed_this_stmt = executed_this_stmt .. ', failed to comment: '.. stmt_res.error_message
			end
		end

		info[j][7] = executed_this_stmt
	end -- end for-loop

	return info
end

function string.startswith(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

-- append rows of table t2 to t1
function appendTable(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

-- check whether filename is contained in name_list
function file_in_list(filename,name_list)
	for i=1, #name_list do
		if filename == name_list[i] then
			return true
		end
	end
	return false
end
---------------------------------------------------------------------------------
------------------------- actual script -----------------------------------------

info_out = {}
info_detailed = {}
execute_all_statements = false
execute__stmts_before_script = true

if(files_to_exclude == null) then
	files_to_exclude = {}
else
	files_to_exclude = split(files_to_exclude, ',')
end

suc, res = pquery([[SELECT EXA_TOOLBOX.GITHUB_LOAD_SCRIPTS_GET_CONTENT(:r, :rec, :exc) res FROM dual]], {r=repository, rec=search_recursive, exc=exclude_folders})
--suc, res = pquery([[SELECT 'repo', filename, link, content from test.gitFiles where id = 4]])

if not suc then
	error(res.error_message)
end

if #res == 0 then
	error('Could not retreive files from github, maybe the url or file_filter is wrong?')
end


for i = 1,#res do

	repository 	= res[i][1]
	filename	= res[i][2]
	link	 	= res[i][3]
	content  	= res[i][4]

	-- check for errors: if an error occured in the python script, repository will start with 'ERROR'
	if string.startswith(repository, 'ERROR') then
		exit('Problem retrieving files: ' .. repository)
	end

	-- check whether file_filter machtes and file is not ignored
	if (file_filter == null or string.find(filename, file_filter)) and (files_to_exclude == null or (not file_in_list(filename,files_to_exclude))) then

		script_statements = getStatements(content)

		new_info = execute_scripts_with_comments(filename, script_statements)
		info_detailed = appendTable(info_detailed, new_info)

		--table.insert(info_out,{repository, filename, 'Executed'} )

	end -- end if
end -- end outer for-loop



-- depending on detail level, use exit(info_out, ...) or exit(info_detailed, ... )

--exit(info_out, "Repo varchar(2000000), filename varchar (2000000), executed varchar(20000)")


exit(info_detailed, "file_name varchar(2000000), stmt_name varchar(2000000), stmt varchar(2000000), stmt_type varchar(10), should_be_executed boolean, comment_on_this varchar(20000), executed varchar(20000)")

/


--repository, file_filter, search_recursive
EXECUTE SCRIPT EXA_TOOLBOX.GITHUB_LOAD_SCRIPTS(
'https://github.com/EXASOL/exa-toolbox' -- repository
, '' 			-- 	file_filter
, 'Example.sql,load_scripts_from_github.sql' --	files_to_exclude
, true			-- search_recursive
, 'test'		-- exclude this folder from search
)
--with output
;


