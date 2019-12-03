using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Read the Teams webhook URL from the application settings
$WebHookURL = $Env:teamsURL

# There are two types of notifications in A2, converge failures and compliance failures
# This section determines type, then forms a new message based on info from the original request
$type = $Request.Body.type
if ($type -eq 'converge_failure') {
    $text = '<b>Converge Failure</b><BR><BR>
        <b>Node:</b> {0}<BR>
        <b>Title:</b> {1}<BR>
        <b>Message:</b> {2}<BR><BR>
        <a href=\"{3}\">View full error</a>' -f $Request.Body.node_name, $Request.Body.exception_title, $Request.Body.exception_message, $Request.Body.automate_failure_url

    $status = [HttpStatusCode]::OK
} elseif ($type -eq 'compliance_failure') {
    $failed_profiles =  $Request.Body.failed_critical_profiles
    foreach ($profile in $failed_profiles){
        $profile_list = $profile_list += $profile.title
    }
    $text = '<b>Compliance Failure</b><BR><BR>
        <b>Node:</b> {0}<BR>
        <b>Test Summary:</b> <font color=\"green\">{1} successful</font>, <font color=\"red\">{2} failures</font>, <font color=\"gray\">{3} skipped</font> <BR>
        <b>Failed Profiles:</b> {4}<BR><BR>
        <a href=\"{5}\">View full error</a>' -f $Request.Body.node_name, $Request.Body.total_number_of_passed_tests, $Request.Body.total_number_of_failed_tests, $Request.Body.total_number_of_skipped_tests, $profile_list, $Request.Body.automate_failure_url

        $status = [HttpStatusCode]::OK
} else {
    $text = "A webhook was recieved. It's either a test from Automate or an unknown payload type."
    $status = [HttpStatusCode]::BadRequest
}

# Form a new JSON payload with the message from above
$body = '{"text" : "' + $text +'."}'

# Try to send the new payload to Teams
try {
    Invoke-WebRequest -Headers @{"ContentType" = "application/json"} -Body $body -uri $WebHookURL -Method Post -UseBasicParsing
}
catch {
    $status = [HttpStatusCode]::InternalServerError
    exit 1
}


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $text
})
