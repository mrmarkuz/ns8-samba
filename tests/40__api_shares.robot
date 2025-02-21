*** Settings ***
Library           SSHLibrary
Library    Collections
Resource          keywords.resource
Suite Setup       Add test accounts
Suite Teardown    Remove test accounts

*** Variables ***
${PASSWORD}       Nethesis,1234
@{SHARES}         @{EMPTY}

*** Keywords ***
Add test accounts
    Run task    module/${MID1}/add-group    {"group":"g1","users":[]}
    Run task    module/${MID1}/add-group    {"group":"g2","users":[]}
    Run task    module/${MID1}/add-user     {"user":"first.user","display_name":"First User","locked":false,"groups":["g1"],"password":"${PASSWORD}"}
    Run task    module/${MID1}/add-user     {"user":"second.user","display_name":"Second User","locked":false,"groups":["g2"],"password":"${PASSWORD}"}
    Run task    module/${MID1}/add-user     {"user":"third.user","display_name":"Third User","locked":false,"groups":[],"password":"${PASSWORD}"}

Remove test accounts
    Run task    module/${MID1}/remove-user     {"user":"first.user"}
    Run task    module/${MID1}/remove-user     {"user":"second.user"}
    Run task    module/${MID1}/remove-user     {"user":"third.user"}
    Run task    module/${MID1}/remove-group    {"group":"g1"}
    Run task    module/${MID1}/remove-group    {"group":"g2"}

User can write to share
    [Arguments]    ${user}    ${share}
    # Run "put" command two times, to check the file is created with proper permissions and can be overwritten too
    ${stdout}  ${stderr}  ${rc} =  Execute Command    runagent -m ${MID1} bash -c "podman exec samba-dc smbclient -c 'put README.md ; put README.md' -U ${user} //127.0.0.1/${share} ${PASSWORD}"
    ...                            return_rc=${TRUE}    return_stdout=${TRUE}    return_stderr=${TRUE}
    Should Be Equal As Integers    ${rc}    ${0}    msg=smbclient_failed

User can read from share
    [Arguments]    ${user}    ${share}
    ${stdout}  ${stderr}  ${rc} =  Execute Command    runagent -m ${MID1} bash-c "podman exec samba-dc smbclient -c 'get README.md' -U ${user} //127.0.0.1/${share} ${PASSWORD}"
    ...                            return_rc=${TRUE}    return_stdout=${TRUE}    return_stderr=${TRUE}
    Should Be Equal As Integers    ${rc}    ${0}    msg=smbclient_failed

*** Test Cases ***
Create Erwshare for everyone
    Run task    module/${MID1}/add-share    {"name":"Erwshare","group":"g1","permissions":"erw","description":"Public share"}

Create Grwshare for the main group only
    Run task    module/${MID1}/add-share    {"name":"Grwshare","group":"g1","permissions":"grw","description":"Private share"}

Create Ergrwshare for the main group that everyone can read
    Run task    module/${MID1}/add-share    {"name":"Ergrwshare","group":"g1","permissions":"ergrw","description":"Mixed share"}

Shares are listed
    ${oshares} =    Run task    module/${MID1}/list-shares    ""
    Length Should Be    ${oshares}[shares]    3
    Set Suite Variable    @{SHARES}    @{oshares}[shares]

Share comments are set
    @{dlist} =    Create List
    FOR       ${element}    IN    @{SHARES}
        Append To List    ${dlist}    ${element}[description]
    END
    List Should Contain Value    ${dlist}    Public share
    List Should Contain Value    ${dlist}    Private share
    List Should Contain Value    ${dlist}    Mixed share

ACLs are present
    FOR       ${element}    IN    @{SHARES}
        ${acls_length} =    Get Length    ${element}[acls]
        Should Be True    ${acls_length} > 0    msg=zero length array for acls
    END

Share comment can change
    Run task    module/${MID1}/alter-share    {"name":"Erwshare","description":"Everyone share"}
    ${oshares} =    Run task    module/${MID1}/list-shares    ""    decode_json=${FALSE}
    Should Contain    ${oshares}    "Everyone share"

Users can collaborate on Erwshare
    User can write to share    third.user     Erwshare
    User can read from share    first.user    Erwshare
    User can write to share    first.user     Erwshare
    User can read from share    second.user    Erwshare
    User can write to share    second.user    Erwshare
    User can read from share    third.user    Erwshare

Only members of g1 can access Grwshare
    User can write to share    first.user     Grwshare
    User can read from share   first.user     Grwshare
    Run Keyword And Expect Error    smbclient_failed*    User can read from share    second.user    Grwshare
    Run Keyword And Expect Error    smbclient_failed*    User can read from share    third.user     Grwshare

Members of g1 can write and everyone else can read Ergrwshare
    User can write to share    first.user     Ergrwshare
    User can read from share   first.user     Ergrwshare
    User can read from share   second.user    Ergrwshare
    User can read from share   third.user     Ergrwshare
    Run Keyword And Expect Error    smbclient_failed*    User can write to share    second.user    Ergrwshare
    Run Keyword And Expect Error    smbclient_failed*    User can write to share    third.user     Ergrwshare

Change the group of Ergrwshare to g2
    Run task    module/${MID1}/reset-share-acls    {"name":"Ergrwshare","group":"g2","permissions":"ergrw"}

After ACL reset Ergrwshare is writable by g2 members
    User can write to share    second.user     Ergrwshare
    User can read from share   second.user     Ergrwshare
    User can read from share   first.user      Ergrwshare
    User can read from share   third.user      Ergrwshare
    Run Keyword And Expect Error    smbclient_failed*    User can write to share    first.user     Ergrwshare
    Run Keyword And Expect Error    smbclient_failed*    User can write to share    third.user     Ergrwshare

Remove the shares
    Run task    module/${MID1}/remove-share    {"name":"Erwshare"}
    Run task    module/${MID1}/remove-share    {"name":"Grwshare"}
    Run task    module/${MID1}/remove-share    {"name":"Ergrwshare"}
    ${oshares} =    Run task    module/${MID1}/list-shares    ""
    Length Should Be    ${oshares}[shares]    0
    Run Keyword And Expect Error    smbclient_failed*    User can read from share    first.user    Erwshare
    Run Keyword And Expect Error    smbclient_failed*    User can read from share    first.user    Ergrwshare
    Run Keyword And Expect Error    smbclient_failed*    User can read from share    second.user   Grwshare
