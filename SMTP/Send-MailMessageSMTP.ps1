\# Skip SSL certificate validation to avoid certificate errors
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

\# Define email parameters
$smtpServer = "localhost"
$smtpPort = 2525
$username = "notification@xyzcorp.com"
$password = "password"
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
$attachments = @("C:\test\dummy.pdf", "C:\test\dummy1.pdf")

\# Send the email
Send-MailMessage `
    -From "gl-notification@greenlightcorp.com" `
    -To "user1@xyzcorp.com" `
    -Cc "user1@gmail.com" `
    -Bcc "user12@gmail.com" `
    -Subject "Test Email from PowerShell" `
    -Body "This is a test email." `
    -SmtpServer $smtpServer `
    -Port $smtpPort `
    -Attachments $attachments `
    -UseSsl `
    -Credential $cred
