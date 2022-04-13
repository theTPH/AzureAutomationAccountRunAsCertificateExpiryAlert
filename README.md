# AzureAutomationAccountRunAsCertificateExpiryAlert
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
