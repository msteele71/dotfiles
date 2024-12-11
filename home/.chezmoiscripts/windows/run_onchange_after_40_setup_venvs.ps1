$home_volume = $null
if (Test-Path "F:\") {
	$home_volume = "F:"
} elseif (Test-Path "D:\") {
	$home_volume = "D:"
} else {
	throw [System.Exception]::new("Could not locate home volume (D:\ or F:\)")
}

if (-not (Test-Path "${home_volume}\venv\tools")) {
	Write-Host "creating tools venv" -ForegroundColor Blue
	python -m venv "${home_volume}\venv\tools"
	"${home_volume}\venv\tools\Scripts\activate.ps1"
	try {
		pip install boto3
	} catch {
		Write-Host "Could not install python modules, you may need to run win-okta-artifactory-login" -ForegroundColor Red
	}
}