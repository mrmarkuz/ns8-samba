*** Settings ***
Resource    keywords.resource
Resource    api.resource
Variables   ./vars.py

*** Test Cases ***
Add the module to the cluster
    [Tags]    create    instance
    ${module_id} =    Create a module instance
    Set Global Variable    ${MID1}    ${module_id}

Retrieve defaults
    ${response} =    Run task    module/${MID1}/get-defaults    {"provision":"new-domain"}
    Set Global Variable    ${IPADDR}    ${response['ipaddress_list'][0]['ipaddress']}
    Should Not Be Empty    ${IPADDR}

Configure the domain
    [Tags]    create    instance
    Set Global Variable    ${DOMAIN}    ${MID1}.test
    Set Global Variable    ${DOMSUFFIX}    dc=${MID1},dc=test
    ${out}    ${err}     ${rc} =    Execute Command
    ...    api-cli run module/${MID1}/configure-module --data '{"provision":"new-domain","realm":"${DOMAIN}","nbdomain":"${nbdomain}","hostname":"${dc1_hostname}","ipaddress":"${IPADDR}","adminuser":"${admuser}","adminpass":"${admpass}"}'
    ...    return_rc=True  return_stdout=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0
    ${val} =     Get server url    ${MID1}
    Set Global Variable    ${SURL}    ${val}
    Wait Until Keyword Succeeds    10s    1s    RootDSE is correct    ${SURL}

The server is reachable after restart
    Execute Command    systemctl restart ${MID1}
    Wait Until Keyword Succeeds    10s    1s    RootDSE is correct    ${SURL}
