$key = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.bluelightreduction.bluelightreductionstate\windows.data.bluelightreduction.bluelightreductionstate\'
$value = 'Data'

$data = Get-ItemPropertyValue -Path $key -Name $value

#[Microsoft.Win32.RegistryKey]::Open

if ($data[18] -eq 0x15)
{
	$data[18] = 0x13

	$data = $data[0..22] + $data[25..43]
}
elseif ($data[18] -eq 0x13)
{
	$data[18] = 0x15

	$data = $data[0..22] + (0x10, 0x00) + $data[23..41]
}
else
{
	exit 1
}

for ($i = 10; $i -lt 15; $i++)
{
	if ($data[$i] -ne 0xff)
	{
		$data[$i]++
		break
	}
}

Set-ItemProperty -Path $key -Name $value -Value $data
