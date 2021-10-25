<#
	Simple PowerShell script to change Windows Night light settings.
#>
param(
	[Parameter(HelpMessage="Turn Night light on, off or toggle it. If no arguments are given, the Night light will be toggled")]
	[Alias("State")]
	[ValidateSet("Toggle", "On", "Off")]
	[string[]]
	$SetState=$null,

	[Parameter(HelpMessage="Turn the Night light schedule on, off or toggle it")]
	[Alias("Schedule")]
	[ValidateSet("Toggle", "On", "Off")]
	[string[]]
	$SetSchedule=$null,

	[Parameter(HelpMessage="Set the start time of the Night light schedule in 'hh:mm'")]
	[Alias("StartTime")]
	<# [ValidateScript()] #>
	[TimeSpan]
	$SetStartTime,

	[Parameter(HelpMessage="Set the end time of the Night light schedule in 'hh:mm'")]
	[Alias("EndTime")]
	<# [ValidateScript()] #>
	[TimeSpan]
	$SetEndTime,

	[Parameter(HelpMessage="Set the temperature of the Night light in Kelvin")]
	[Alias("Temperature")]
	[ValidateRange(1200,6500)]
	[int]
	$SetTemperature=-1,

	[Parameter(HelpMessage="Set the strength of the Night light")]
	[Alias("Strength")]
	[ValidateRange(0,100)]
	[int]
	$SetStrength=-1,



	[Parameter(HelpMessage="Get all the Night light settings")]
	[switch]
	$GetSettings,

	[Parameter(HelpMessage="Get the Night light state")]
	[switch]
	$GetState,

	[Parameter(HelpMessage="Get the Night light is schedule")]
	[switch]
	$GetSchedule,

	[Parameter(HelpMessage="Get the time the Night light turns on")]
	[switch]
	$GetStartTime,

	[Parameter(HelpMessage="Get the time the Night light turns off")]
	[switch]
	$GetEndTime,
	
	[Parameter(HelpMessage="Get the temperature of the Night light in Kelvin")]
	[switch]
	$GetTemperature,

	[Parameter(HelpMessage="Get the strength of the Night light")]
	[switch]
	$GetStrength,


	[Parameter(HelpMessage="Delete the state data registry entry")]
	[switch]
	$DeleteState,

	[Parameter(HelpMessage="Delete the settings data registry entry")]
	[switch]
	$DeleteSettings,

	[Parameter(HelpMessage="Open Windows Settings at the Night light settings")]
	[switch]
	$OpenSettings
)

[console]::WriteLine("State: ${SetState}")
[console]::WriteLine("Schedule: ${SetSchedule}")
[console]::WriteLine("StartTime: {0:hh\:mm}", $SetStartTime)
[console]::WriteLine("EndTime: {0:hh\:mm}", $SetEndTime)
[console]::WriteLine("Temperature: ${SetTemperature}")
[console]::WriteLine("Strength: ${SetStrength}")
[console]::WriteLine("")

$stateKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate\'
$valueName = 'Data'

# fast path
if (
	$SetSchedule -eq $null -and 
	$SetStartTime -eq $null -and 
	$SetEndTime -eq $null -and 
	$SetTemperature -eq -1 -and 
	$SetStrength -eq -1 -and 
	-not $GetSettings -and 
	-not $GetState -and 
	-not $GetSchedule -and 
	-not $GetStartTime -and 
	-not $GetStartTime -and 
	-not $GetEndTime -and 
	-not $GetTemperature -and 
	-not $GetStrength -and
	-not $DeleteState -and
	-not $DeleteSettings -and
	-not $OpenSettings
)
{
	$data = Get-ItemPropertyValue -Path $stateKey -Name $valueName

	#[Microsoft.Win32.RegistryKey]::Open

	if ($data[18] -eq 0x15)
	{
		if ($SetState -eq "On")
		{
			exit 0
		}

		$data[18] = 0x13

		$data = $data[0..22] + $data[25..$data.length] # 43
	}
	elseif ($data[18] -eq 0x13)
	{
		if ($SetState -eq "Off")
		{
			exit 0
		}

		$data[18] = 0x15

		$data = $data[0..22] + (0x10, 0x00) + $data[23..$data.length] # 41
	}
	else
	{
		throw "Data corrupted"
	}

	for ($i = 10; $i -lt 15; $i++)
	{
		if ($data[$i] -ne 0xff)
		{
			$data[$i]++
			break
		}
	}

	Set-ItemProperty -Path $stateKey -Name $valueName -Value $data
	
	exit 0
}

$settingsKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.settings\windows.data.bluelightreduction.settings\'

class Settings
{
	[byte[]]$Data
	[string]$Schedule
	[TimeSpan]$StartTime
	[TimeSpan]$EndTime
	[int]$Temperature
}

function Get-settings
{
	$settings = [Settings]::new()

	$settings.Data = Get-ItemPropertyValue -Path $settingsKey -Name $valueName

	# 23 unknown bytes
	$i = 23

	if ($settings.Data[$i] -eq 0x02 -and $settings.Data[$i + 1] -eq 0x01)
	{
		# 2 scheduled bytes flag
		$i += 2
		$settings.Schedule = "On"
	}
	else
	{
		$settings.Schedule = "Off"
	}

	# 5 unknown bytes
	$i += 5

	if ($settings.Data[$i] -eq 0x0E)
	{
		# 1 start hour byte flag
		$i++
		# 1 start hour byte
		$startHour = $settings.Data[$i++]
	}
	else
	{
		$startHour = 0
	}

	if ($settings.Data[$i] -eq 0x2E)
	{
		# 1 start minute byte flag
		$i++
		# 1 start minute byte
		$startMinute = $settings.Data[$i++]
	}
	else
	{
		$startMinute = 0
	}

	$settings.StartTime = New-TimeSpan -Hours $startHour -Minutes $startMinute

	# 3 unknown bytes
	$i += 3

	if ($settings.Data[$i] -eq 0x0E)
	{
		# 1 end hour byte flag
		$i++
		# 1 end hour byte
		$endHour = $settings.Data[$i++]
	}
	else
	{
		$endHour = 0
	}

	if ($settings.Data[$i] -eq 0x2E)
	{
		# 1 end minute byte flag
		$i++
		# 1 end minute byte
		$endMinute = $settings.Data[$i++]
	}
	else
	{
		$endMinute = 0
	}

	$settings.EndTime = New-TimeSpan -Hours $endHour -Minutes $endMinute

	# 3 unknown bytes
	$i += 3

	$settings.Temperature = ([int]$settings.Data[$i + 1] * 64) + [int][math]::floor(([int]$settings.Data[$i] - 128) / 2)

	# 2 temperature bytes
	# $i += 2

	# 10 remaining unknown bytes
	# $i += 10

	return $settings
}

function Set-settings
{
	param(
		[Parameter(Mandatory)]
		[Settings]
		$settings
		)

	# 23 unknown bytes
	$i = 23

	if ($settings.Data[$i] -eq 0x02 -and $settings.Data[$i + 1] -eq 0x01)
	{
		if ($settings.Schedule -eq "Off" -or $settings.Schedule -eq "Toggle")
		{
			$settings.Data = $settings.Data[0..($i-1)] + $settings.Data[($i+2)..$settings.Data.length]
		}
		else
		{
			# 2 scheduled bytes flag
			$i += 2
		}
	}
	else
	{
		if ($settings.Schedule -eq "On" -or $settings.Schedule -eq "Toggle")
		{
			$settings.Data = $settings.Data[0..($i-1)] + (0x02, 0x01) + $settings.Data[$i..$settings.Data.length]
			$i += 2
		}
	}

	# 5 unknown bytes
	$i += 5

	if ($settings.Data[$i] -eq 0x0E)
	{
		if ($settings.StartTime.Hours -eq 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + $settings.Data[($i+2)..$settings.Data.length]
		}
		else
		{
			# 1 start hour byte flag
			$i++
			# 1 start hour byte
			$settings.Data[$i++] = [byte]$settings.StartTime.Hours
		}
	}
	else
	{
		if ($settings.StartTime.Hours -ne 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + (0x0E, [byte]$settings.StartTime.Hours) + $settings.Data[$i..$settings.Data.length]
			$i += 2
		}
	}

	if ($settings.Data[$i] -eq 0x2E)
	{
		if ($settings.StartTime.Minutes -eq 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + $settings.Data[($i+2)..$settings.Data.length]
		}
		else
		{
			# 1 start minute byte flag
			$i++
			# 1 start minute byte
			$settings.Data[$i++] = [byte]$settings.StartTime.Minutes
		}
	}
	else
	{
		if ($settings.StartTime.Minutes -ne 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + (0x2E, [byte]$settings.StartTime.Minutes) + $settings.Data[$i..$settings.Data.length]
			$i += 2
		}
	}

	# 3 unknown bytes
	$i += 3

	if ($settings.Data[$i] -eq 0x0E)
	{
		if ($settings.EndTime.Hours -eq 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + $settings.Data[($i+2)..$settings.Data.length]
		}
		else
		{
			# 1 end hour byte flag
			$i++
			# 1 end hour byte
			$settings.Data[$i++] = [byte]$settings.EndTime.Hours
		}
	}
	else
	{
		if ($settings.EndTime.Hours -ne 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + (0x0E, [byte]$settings.EndTime.Hours) + $settings.Data[$i..$settings.Data.length]
			$i += 2
		}
	}

	if ($settings.Data[$i] -eq 0x2E)
	{
		if ($settings.EndTime.Minutes -eq 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + $settings.Data[($i+2)..$settings.Data.length]
		}
		else
		{
			# 1 end minute byte flag
			$i++
			# 1 end minute byte
			$settings.Data[$i++] = [byte]$settings.EndTime.Minutes
		}
	}
	else
	{
		if ($settings.EndTime.Minutes -ne 0)
		{
			$settings.Data = $settings.Data[0..($i-1)] + (0x2E, [byte]$settings.EndTime.Minutes) + $settings.Data[$i..$settings.Data.length]
			$i += 2
		}
	}

	# 3 unknown bytes
	$i += 3

	$settings.Data[$i + 1] = [byte]([int][math]::floor($settings.Temperature / 64))
	$settings.Data[$i] = [byte](($settings.Temperature % 64) * 2 + 128)

	# 2 temperature bytes
	# $i += 2

	# 10 remaining unknown bytes
	# $i += 10

	for ($i = 10; $i -lt 15; $i++)
	{
		if ($settings.Data[$i] -ne 0xff)
		{
			$settings.Data[$i]++
			break
		}
	}

	Set-ItemProperty -Path $settingsKey -Name $valueName -Value $settings.Data
}

if ($DeleteState)
{
	Remove-ItemProperty -Path $stateKey -Name $valueName
}

if ($DeleteSettings)
{
	Remove-ItemProperty -Path $settingsKey -Name $valueName
}

if ($SetSchedule -ne $null -or $SetStartTime -ne $null -or $SetEndTime -ne $null -or $SetTemperature -ne -1 -or $SetStrength -ne -1)
{
	if ($SetTemperature -ne -1 -and $SetStrength -ne -1)
	{
		throw "Cannot set temperature and strength at the same time. The Night light strength is the temperature converted to a range from 0 to 100"
	}

	$settings = Get-settings

	if ($SetSchedule -ne $null)
	{
		$settings.Schedule = $SetSchedule
	}

	if ($SetStartTime -ne $null )
	{
		$settings.StartTime = $SetStartTime
	}

	if ($SetEndTime -ne $null)
	{
		$settings.EndTime = $SetEndTime
	}

	if ($SetTemperature -ne -1)
	{
		$settings.Temperature = $SetTemperature
	}

	if ($SetStrength -ne -1)
	{
		$settings.Temperature = ((100 - $SetStrength) * 53 + 1200)
	}

	Set-Settings $settings
}

if ($GetState -or $GetSettings)
{
	$data = Get-ItemPropertyValue -Path $stateKey -Name $valueName

	if ($data[18] -eq 0x15)
	{
		$state = "On"
	}
	elseif ($data[18] -eq 0x13)
	{
		$state = "Off"
	}
	else
	{
		$state = "Unknown"
	}

	[console]::WriteLine("State: ${state}")

	# for ($i = 0; $i -lt $data.length; $i++)
	# {
	# 	[console]::WriteLine("data[{0}]: {1:X2}", $i, $data[$i])
	# }
}

if ($GetSettings -or $GetSchedule -or $GetStartTime -or $GetStartTime -or $GetEndTime -or $GetTemperature -or $GetStrength)
{
	$settings = Get-settings

	for ($i = 0; $i -lt $settings.Data.length; $i++)
	{
		[console]::WriteLine("data[{0}]: {1:X2}", $i, $settings.Data[$i])
	}

	if ($GetSchedule -or $GetSettings)
	{
		[console]::WriteLine("Schedule: {0}", $settings.Schedule)
	}

	if ($GetStartTime -or $GetSettings)
	{
		[console]::WriteLine("StartTime: {0:hh\:mm}", $settings.StartTime)
	}

	if ($GetEndTime -or $GetSettings)
	{
		[console]::WriteLine("EndTime: {0:hh\:mm}", $settings.EndTime)
	}

	if ($GetTemperature -or $GetSettings)
	{
		[console]::WriteLine("Temperature: {0}", $settings.Temperature)
	}

	if ($GetStrength -or $GetSettings)
	{
		[console]::WriteLine("Strength: {0}", 100 - [int][math]::floor(($settings.Temperature - 1200) / 53))
	}
}

if ($OpenSettings)
{
	start "ms-settings:nightlight"
	# opening the settings once seems to display wrong values...
	start "ms-settings:nightlight"
}