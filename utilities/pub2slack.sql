CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

CREATE OR REPLACE TABLE pub2slack_channels(
    channel    VARCHAR(256)
  , webhook    VARCHAR(256)
  , pubrole    VARCHAR(128)
);

/*
    Examples:

    CREATE ROLE slack_general;
    GRANT ROLE slack_general TO <user>;

    INSERT INTO pub2slack_channels VALUES ('general',  'TE100F6H2/BENTD9WD6/VByhPjjLtM5RJdSqXexKhgUc', 'slack_general');
    INSERT INTO pub2slack_channels VALUES ('slackbot', 'TE100F6H2/BE1KQFTA7/L4SVD0dAvWrO1fEbhEY4hsi0', NULL);

    If pubrole is NULL then anyone can publish into the channel.
*/

--/
CREATE OR REPLACE SCRIPT pub2slack(channel, message) RETURNS TABLE AS

    all_ok    = true
    resp_code = 200
    resp_mesg = "OK"
    webhook   = ""

    if message == NULL or #message == 0 then
        resp_code = -1
        resp_mesg = "Message is empty"
        all_ok = false
    end

    if all_ok and (channel == NULL or #channel == 0) then
        resp_code = -2
        resp_mesg = "Channel is not specified"
        all_ok = false
    end

    if all_ok then
        suc, res = pquery([[
            SELECT webhook
            FROM   pub2slack_channels
            WHERE  channel = :ch
               AND (pubrole IS NULL OR UPPER(pubrole) IN (SELECT granted_role FROM exa_user_role_privs));
        ]], {ch = channel})

        if not suc then
            resp_code = res.error_code
            resp_mesg = res.error_message
            all_ok = false
        elseif #res == 0 then
            resp_code = -3
            resp_mesg = "Channel is not defined or permitted"
            all_ok = false
        else
            webhook = res[1][1]
            suc, res = pquery([[SELECT exa_toolbox.pub2slackfn(:wh, :msg)]], {wh = webhook, msg = message})
            if not suc then
                resp_code = res.error_code
                resp_mesg = res.error_message
            else
                resp_code = res[1][1]
                resp_mesg = res[1][2]
            end
        end
    end

    return {{resp_code, resp_mesg}}, "resp_code INT, resp_message VARCHAR(200)"
/

--/
CREATE OR REPLACE PYTHON SCALAR SCRIPT pub2slackfn(webhook VARCHAR(256), message VARCHAR(100000)) EMITS (resp_code INT, resp_mesg VARCHAR(200)) AS

import httplib

def run(ctx):

    host = "hooks.slack.com"
    path = "/services/" + ctx.webhook
    headers = {"Content-type": "application/json"}

    sl = httplib.HTTPSConnection(host)
    sl.request("POST", path, '{"text": "' + ctx.message + '"}', headers)
    resp = sl.getresponse();
    ctx.emit(resp.status, resp.reason)
/

/*
    Example:
    EXECUTE SCRIPT pub2slack('general','Test');
*/

-- EOF
