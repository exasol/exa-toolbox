--/

create or replace PYTHON3 script "databricks"."preprocessor" AS
import re    
def convert_to_exasol_sql(input_sql):
    
    # This part adds an alias if alias is missing after the CAST() function. 
    def cast_add_alias(match): 
        expr = match.group(1).strip()
        type_ = match.group(2).strip().upper()

        expr_clean = expr.replace('`', '').replace('"', '')
        base = re.sub(r"[^a-zA-Z0-9_]", "", expr_clean.split('.')[-1])

        return f'CAST("{expr_clean}" AS {type_}) AS "{base}"'

    pattern_missing_alias = re.compile(
    r'CAST\s*\(\s*([^)]+?)\s+AS\s+([A-Z0-9_]+(?:\(\d+\))?)\s*\)(?!\s+AS)', 
    flags=re.IGNORECASE
)
    
    sql_keywords = {
        "all", "alter", "and", "as", "at", "between", "by", "case", "create", "cross", "concat", "delete", "desc", "distinct", "drop", "else", "end", "endif",
        "except", "false", "flush", "from", "full", "group", "having", "if", "ifnull", "import", "in", "inner", "insert", "interval", "into", "is", "join", "kill", "left", "limit", "long", "lower",
        "like", "not", "null", "offset", "on", "or", "order", "outer", "over", "partition", "replace", "schema", "select", "session", "statement", "statistics", "system", "table", "then", "true", "truncate", "update", "upper", "union", "varchar", "view", "when", "where",
        "with", 
        
        #  Databricks Functions
        "abs", "acos", "acosh", "add_months", "aes_decrypt", "aes_encrypt", "aggregate", "ai_analyze_sentiment", 
        "ai_classify", "ai_extract", "ai_fix_grammar", "ai_forecast", "ai_gen", "ai_generate_text", "ai_mask", 
        "ai_query", "ai_similarity", "ai_summarize", "ai_translate", "any", "any_value", "approx_count_distinct", 
        "approx_percentile", "approx_top_k", "array", "array_agg", "array_append", "array_compact", "array_contains", 
        "array_distinct", "array_except", "array_insert", "array_intersect", "array_join", "array_max", "array_min", 
        "array_position", "array_prepend", "array_remove", "array_repeat", "array_size", "array_sort", "array_union", 
        "arrays_overlap", "arrays_zip", "ascii", "asin", "asinh", "assert_true", "atan", "atan2", "atanh", "avg", 
        "base64", "between", "bigint", "bin", "binary", "bit_and", "bit_count", "bit_get", "bit_length", "bit_or", 
        "bit_reverse", "bit_xor", "bitmap_bit_position", "bitmap_bucket_number", "bitmap_construct_agg", "bitmap_count", 
        "bitmap_or_agg", "bool_and", "bool_or", "boolean", "bround", "btrim", "cardinality", "case", "cast", "cbrt", 
        "ceil", "ceiling", "char", "char_length", "character_length", "charindex", "chr", "cloud_files_state", "coalesce", 
        "collate", "collation", "collect_list", "collect_set", "concat", "concat_ws", "contains", "conv", "convert_timezone", 
        "corr", "cos", "cosh", "cot", "count", "count_if", "count_min_sketch", "covar_pop", "covar_samp", "crc32", "csc", 
        "cube", "cume_dist", "curdate", "current_catalog", "current_database", "current_date", "current_metastore", 
        "current_recipient", "current_schema", "current_timestamp", "current_timezone", "current_user", "current_version", 
        "date", "date_add", "date_diff", "date_format", "date_from_unix_date", "date_part", "date_sub", "date_trunc", 
        "dateadd", "datediff", "day", "dayname", "dayofmonth", "dayofweek", "dayofyear", "decimal", "decode", "degrees", 
        "dense_rank", "div", "double", "e", "element_at", "elt", "encode", "endswith", "equal_null", "event_log", "every", 
        "exists", "exp", "explode", "explode_outer", "expm1", "extract", "factorial", "filter", "find_in_set", "first", 
        "first_value", "flatten", "float", "floor", "forall", "format_number", "format_string", "from_avro", "from_csv", 
        "from_json", "from_unixtime", "from_utc_timestamp", "from_xml", "get", "get_json_object", "getbit", "getdate", 
        "greatest", "grouping", "grouping_id", "h3_boundaryasgeojson", "h3_boundaryaswkb", "h3_boundaryaswkt", "h3_centerasgeojson", 
        "h3_centeraswkb", "h3_centeraswkt", "h3_compact", "h3_coverash3", "h3_coverash3string", "h3_distance", "h3_h3tostring", 
        "h3_hexring", "h3_ischildof", "h3_ispentagon", "h3_isvalid", "h3_kring", "h3_kringdistances", "h3_longlatash3", 
        "h3_longlatash3string", "h3_maxchild", "h3_minchild", "h3_pointash3", "h3_pointash3string", "h3_polyfillash3", 
        "h3_polyfillash3string", "h3_resolution", "h3_stringtoh3", "h3_tessellateaswkb", "h3_tochildren", "h3_toparent", 
        "h3_try_coverash3", "h3_try_coverash3string", "h3_try_distance", "h3_try_polyfillash3", "h3_try_polyfillash3string", 
        "h3_try_tessellateaswkb", "h3_try_validate", "h3_uncompact", "h3_validate", "hash", "hex", "histogram_numeric", 
        "hll_sketch_agg", "hll_sketch_estimate", "hll_union", "hll_union_agg", "hour", "http_request", "hypot", "if", "iff", 
        "ifnull", "ilike", "in", "initcap", "inline", "input_file_block_length", "input_file_block_start", "input_file_name", 
        "instr", "int", "is_account_group_member", "is_valid_utf8", "is_variant_null", "is distinct", "is false", 
        "isnan", "isnotnull", "isnull", "is true", "java_method", "json_array_length", "json_object_keys", "json_tuple", 
        "kurtosis", "lag", "last", "last_day", "last_value", "lcase", "lead", "least", "left", "len", "length", "levenshtein", 
        "like", "list_secrets", "ln", "locate", "log", "log10", "log1p", "log2", "lower", "lpad", "ltrim", "make_date", 
        "make_dt_interval", "make_interval", "make_timestamp", "make_valid_utf8", "make_ym_interval", "map", "map_concat", 
        "map_contains_key", "map_entries", "map_filter", "map_from_arrays", "map_from_entries", "map_keys", "map_values", 
        "map_zip_with", "mask", "max", "max_by", "md5", "mean", "median", "min", "min_by", "minute", "mod", "mode", 
        "monotonically_increasing_id", "month", "months_between", "named_struct", "nanvl", "negative", "next_day", "not", 
        "now", "nth_value", "ntile", "nullif", "nullifzero", "nvl", "nvl2", "octet_length", "or", "overlay", "parse_json", 
        "parse_url", "percent_rank", "percentile", "percentile_approx", "percentile_cont", "percentile_disc", "pi", "printf", 
        "quarter", "radians", "raise_error", "rand", "randn", "random", "randstr", "range", "rank", "read_files", "read_kafka", 
        "read_kinesis", "read_pubsub", "read_pulsar", "read_state_metadata", "read_statestore", "reduce", "reflect", "regexp", 
        "regexp_count", "regexp_extract", "regexp_extract_all", "regexp_instr", "regexp_like", "regexp_replace", 
        "regexp_substr", "regr_avgx", "regr_avgy", "regr_count", "regr_intercept", "regr_r2", "regr_slope", "regr_sxx", 
        "regr_sxy", "regr_syy", "repeat", "replace", "reverse", "right", "rint", "rlike", "round", "row_number", "rpad", 
        "rtrim", "schema_of_csv", "schema_of_json", "schema_of_json_agg", "schema_of_variant", "schema_of_variant_agg", 
        "schema_of_xml", "sec", "second", "secret", "sentences", "sequence", "session_user", "sha", "sha1", "sha2", "shiftleft", 
        "shiftright", "shiftrightunsigned", "shuffle", "sign", "signum", "sin", "sinh", "size", "skewness", "slice", "smallint", 
        "some", "sort_array", "soundex", "space", "spark_partition_id", "split", "split_part", "sqrt", "stack", "startswith", 
        "std", "stddev", "stddev_pop", "stddev_samp", "str_to_map", "string", "struct", "substr", "substring", "substring_index", 
        "sum", "table_changes", "tan", "tanh", "timediff", "timestamp", "timestamp_micros", "timestamp_millis", "timestamp_seconds", 
        "timestampadd", "timestampdiff", "tinyint", "to_avro", "to_binary", "to_char", "to_csv", "to_date", "to_json", 
        "to_number", "to_timestamp", "to_unix_timestamp", "to_utc_timestamp", "to_varchar", "to_xml", "transform", 
        "transform_keys", "transform_values", "translate", "trim", "trunc", "try_add", "try_aes_decrypt", "try_avg", "try_cast", 
        "try_divide", "try_element_at", "try_mod", "try_multiply", "try_parse_json", "try_reflect", "try_secret", 
        "try_subtract", "try_sum", "try_to_binary", "try_to_number", "try_to_timestamp", "try_url_decode", "try_validate_utf8", 
        "try_variant_get", "try_zstd_decompress", "typeof", "ucase", "unbase64", "unhex", "uniform", "unix_date", "unix_micros", 
        "unix_millis", "unix_seconds", "unix_timestamp", "upper", "url_decode", "url_encode", "user", "uuid", "validate_utf8", 
        "var_pop", "var_samp", "variance", "variant_explode", "variant_explode_outer", "variant_get", "vector_search", 
        "version", "weekday", "weekofyear", "width_bucket", "window", "window_time", "xpath", "xpath_boolean", "xpath_double", 
        "xpath_float", "xpath_int", "xpath_long", "xpath_number", "xpath_short", "xpath_string", "xxhash64", "year", "zeroifnull", 
        "zip_with", "zstd_compress", "zstd_decompress"}

    from functools import lru_cache
    @lru_cache(maxsize=None)
    
    def is_sql_keyword(word, input_sql):
        """Determine if a word is a keyword in SQL and if it's used in function or identifier context."""
        # Check if the word is a SQL keyword
        if word.lower() in ("null", "end"):
            return True
        
        # Check if the word is a SQL keyword (already in the list)
        if word.lower() in sql_keywords:
            # If the word is preceded by a dot (.) — likely referencing a column in a CTE or table alias
            if re.search(r'\.\s*\b' + re.escape(word) + r'\b', input_sql, flags=re.IGNORECASE):
                return False  # Treat it as a column/identifier in a CTE or table
            
        if word.lower() in sql_keywords:
            # If followed by 'AS', it is used as an identifier
            if re.search(rf'\b{word}\s+AS ', input_sql, flags=re.IGNORECASE):
                return False  # It's being used as an alias (identifier)
            return True  # If not followed by parentheses or AS, treat as an identifier
  
        return False
    
    def normalize_identifier(match, input_sql):
        word = match.group(0).strip('"')
        expression = match.string  # This is the expression the word is from
        
        # Skip numeric literals (integers or floats)
        if re.fullmatch(r'\d+(\.\d+)?', word):
            return word
        
        if is_sql_keyword(word, input_sql):
            return word  # Treat as function, no quotes
        
        return f'"{word}"'  # fallback   
    
    #Literals in Single Quotes will not be touched
    def normalize_sql_safely(input_sql):
        # Split SQL into parts, preserving string literals as-is
        parts = re.split(r"('(?:''|[^'])*')", input_sql)  # split on single-quoted string literals
        normalized_parts = []
        
        for part in parts:
            if part.startswith("'") and part.endswith("'"):
                normalized_parts.append(part)  # it's a string literal, keep as-is
                
            else:
                normalized = re.sub(
                    r'"([^"]+)"|([A-Za-z0-9_]+)',  # updated regex
                    lambda match: normalize_identifier(match, input_sql),
                    part
                )
                normalized_parts.append(normalized)
      
        return ''.join(normalized_parts)
    
    # This part converts STRING to CHAR(256) coming within CAST Function
    exasol_sql = re.sub(
    r"CAST\(([^)]+) AS STRING\)", 
    r"CAST(\1 AS CHAR(256))", 
    input_sql, 
    flags=re.IGNORECASE
    )

    exasol_sql = re.sub(pattern_missing_alias, cast_add_alias, exasol_sql)  # step 1: replace CAST AS STRING
    exasol_sql = exasol_sql.replace("`", '"')                        # step 2: replace backticks with double quotes
    exasol_sql = normalize_sql_safely(exasol_sql)   
    exasol_sql = re.sub(r"<> *''", 'IS NOT NULL', exasol_sql)
    exasol_sql = re.sub(r"!= *''", 'IS NOT NULL', exasol_sql)
    exasol_sql = re.sub(r'"d"(\s*\'\d{4}-\d{2}-\d{2}\')', r'd\1', exasol_sql, flags=re.IGNORECASE)
    
    return exasol_sql
    
def adapter_call(request):
       return convert_to_exasol_sql(request)

/
