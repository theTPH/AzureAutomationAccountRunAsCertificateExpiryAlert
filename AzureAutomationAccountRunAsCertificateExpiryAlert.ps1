<#
.SYNOPSIS
	This script checks the certificate status of an Azure Automation Account RunAs Certificate and sends an alert if the certificate expires within 30 days.
.DESCRIPTION 
	This script checks the certificate status of an Azure Automation Account RunAs Certificate and sends an alert if the certificate expires within 30 days.
	This script is intendet to be used with a KeyVault that stores the e-mail credentials. 
	In our use case the KeyVault can only be accessed by a private endpoint thus requiring this script to be run on a hybrid worker.
	Therefore the System Identity running this workbook needs the following RBAC rigths in the Azure tennant:
		- Read on KeyVault
		- Read on AutomationAccount
	The following Powershell modules are required:
		- Az.Automation
		- Az.KeyVault
.PARAMETER Subscription
	The Subscription containig the ressources such as VMs, LAW, KeyVault, Hostpool.
.PARAMETER AAResourceGroup
	The RessourceGroup of the automation account.
.PARAMETER AutomationAccountName
	The Name of the automation account.
.PARAMETER KeyvaultID
	The KeyvaultID where the WorkspaceKey is stored.
.PARAMETER KeyvaultMailUserName
	Key for mail user username in the KeyVault.
.PARAMETER KeyvaultMailUserPassword
	Key for mail user password in the KeyVault.
.PARAMETER SMTPServer
	SMTP Server for the service e-mail account.
.PARAMETER Sender
	Sender for alert e-mails.
.PARAMETER Recipients
	Array of Users that should recive the alert e-mail.
.NOTES
#>

Param (
	[Parameter (Mandatory = $true)]
	[String] $Subscription,
	[Parameter (Mandatory = $true)]
	[String] $AAResourceGroup,
	[Parameter (Mandatory = $true)]
	[String] $AutomationAccountName,
	[Parameter (Mandatory = $true)]
	[String] $KeyvaultID,
  [Parameter (Mandatory = $true)]
	[String] $KeyvaultMailUserName,
	[Parameter (Mandatory = $true)]
	[String] $KeyvaultMailUserPassword,
	[Parameter (Mandatory = $true)]
	[String] $SMTPServer,
	[PARAMETER (Mandatory = $true)]
	[String] $Sender,
	[Parameter (Mandatory = $true)]
	[Array] $Recipients
)

function Create-EMail
{
    [CmdletBinding()]
   	Param(
       	[Parameter(Mandatory)]
        [Int]$RemainingDays,
		[Parameter(Mandatory)]
        [String]$CertificateName,
		[Parameter (Mandatory)]
		[String] $AutomationAccountName

   	)
	$Subject = "Expiring certificate on Azure automation account " + $AutomationAccountName
	$Body = "This is an automated alert email sent by the Azure Runbook AutomationAccountCertificateExpiryAlert." `
		+ "`r`nThe certificate " + $CertificateName + " on the Azure automation account " + $AutomationAccountName + " is about to expire in " +$RemainingDays + " days." `
		+ "`r`nPlease shedule to replace this certificate." `
		+ "`r`nKind regards" `
		+ "`r`AVD Team"
	return $Subject, $Body
}


Write-Output ("Running script on: " + $env:computername)
#Connect to Azure with the identity of the automation account
try {
    Write-Output ("Connecting to Azure Account...")
    Connect-AzAccount `
    -Identity `
    -SubscriptionId $Subscription `
    -ErrorAction Stop| Out-Null 
}
catch {
    $ErrorMessage = $PSItem.Exception.message
    Write-Error ("Could not connect to Azure Account: "+$ErrorMessage)
    exit(1)
    Break
}

#Create Credentials
try {
	Write-Output ("Creating E-Mail credentials...")
	$MailUserName = Get-AzKeyVaultSecret -ResourceId $KeyvaultID -Name $KeyvaultMailUserName -AsPlainText
	$MailUserPassword = Get-AzKeyVaultSecret -ResourceId $KeyvaultID -Name $KeyvaultMailUserPassword -AsPlainText
	$MailUserPasswordSecure = ConvertTo-SecureString $MailUserPassword -AsPlainText -Force
	$MailUserCredentials = New-Object System.Management.Automation.PSCredential ($MailUserName, $MailUserPasswordSecure)
	Write-Output ("Created E-Mail credentials")
}
catch{	
	$ErrorMessage = $PSItem.Exception.message
    Write-Error ("Could not create E-Mail credentials: "+$ErrorMessage)
    exit(1)
    Break
}

#Get Certificate
try {
	$Certificate = Get-AzAutomationCertificate -ResourceGroupName $AAResourceGroup -AutomationAccountName $AutomationAccountName
}catch{
	$ErrorMessage = $PSItem.Exception.message
    Write-Error ("Could not retrive the certificate: "+$ErrorMessage)
    exit(1)
    Break
}

$ExpirationDate = $Certificate.ExpiryTime
$CurrentTime = (Get-Date).ToUniversalTime()
$RemainingDays = ($ExpirationDate - $CurrentTime).Days

if($RemainingDays -le 30 ){
	Write-Output($Certificate.Name + " will be invalid in " + $RemainingDays + " days!")
	$Subject, $Body = Create-EMail -RemainingDays $RemainingDays -CertificateName $Certificate.Name -AutomationAccountName $AutomationAccountName
	foreach($Recipient in $Recipients){
		Send-MailMessage -Credential $MailUserCredentials -SmtpServer $SMTPServer -From $Sender -To $Recipients -Subject $Subject -Body $Body
		Write-Output("Sent mail to " + $Recipient)
	}
}else{
	Write-Output($Certificate.Name + " is still valid for " + $RemainingDays + " days.")
}
Write-Output("Finished running successfully")
