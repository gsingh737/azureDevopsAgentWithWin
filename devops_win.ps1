param (
    [string]$URL,
    [string]$PAT,
    [string]$POOL,
    [string]$AGENT
)

Start-Transcript
Write-Host "start"

if (test-path "c:\agent")
{
    Remove-Item -Path "c:\agent" -Force -Confirm:$false -Recurse
}

new-item -ItemType Directory -Force -Path "c:\agent"
set-location "c:\agent"

$env:VSTS_AGENT_HTTPTRACE = $true

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$wr = Invoke-WebRequest https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest -UseBasicParsing
$tag = ($wr | ConvertFrom-Json)[0].tag_name
$tag = $tag.Substring(1)

write-host "$tag is the latest version"
$download = "https://vstsagentpackage.azureedge.net/agent/$tag/vsts-agent-win-x64-$tag.zip"
#overwrite
$download = "https://vstsagentpackage.azureedge.net/agent/2.149.0/vsts-agent-win-x64-2.149.0.zip"


Invoke-WebRequest $download -Out agent.zip
Expand-Archive -Path agent.zip -DestinationPath $PWD
.\config.cmd --unattended --url "$URL" --auth pat --token "$PAT" --pool "$POOL" --agent "$AGENT" --acceptTeeEula --runAsService

Stop-Transcript
exit 0