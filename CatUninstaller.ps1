Add-Type -AssemblyName System.Windows.Forms

# UI
$form = New-Object Windows.Forms.Form
$form.Text = 'CatUninstaller v9'
$form.Width = 640
$form.Height = 500
$form.StartPosition = 'CenterScreen'

$listbox = New-Object Windows.Forms.ListBox
$listbox.Width = 600
$listbox.Height = 260
$listbox.Top = 20
$listbox.Left = 20
$listbox.Sorted = $true
$form.Controls.Add($listbox)

# App listing
$apps = @()
$regApps = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName -and $_.UninstallString }
foreach ($a in $regApps) {
    $apps += [PSCustomObject]@{
        Name = $a.DisplayName
        Type = 'REG'
        Cmd = $a.UninstallString
    }
}
$uwpApps = Get-AppxPackage | Where-Object { $_.Name -and $_.PackageFullName }
foreach ($u in $uwpApps) {
    $apps += [PSCustomObject]@{
        Name = $u.Name
        Type = 'UWP'
        Cmd = $u.PackageFullName
    }
}
$listbox.Items.AddRange($apps.Name)

# Désinstaller
$btnUninstall = New-Object Windows.Forms.Button
$btnUninstall.Text = 'Désinstaller'
$btnUninstall.Top = 300
$btnUninstall.Left = 20
$btnUninstall.Width = 120
$form.Controls.Add($btnUninstall)

$btnUninstall.Add_Click({
    $sel = $listbox.SelectedItem
    if ($sel) {
        $app = $apps | Where-Object { $_.Name -eq $sel }
        $cmd = $app.Cmd
        if ($app.Type -eq 'REG') {
            if ($cmd -match '/I{(.+?)}') {
                $guid = $Matches[1]
                Start-Process msiexec -ArgumentList "/x{$guid} /quiet" -WindowStyle Hidden
            } elseif (Test-Path $cmd) {
                Start-Process -FilePath $cmd -ArgumentList '/S','/quiet' -WindowStyle Hidden
            } else {
                Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $cmd" -WindowStyle Hidden
            }
        } elseif ($app.Type -eq 'UWP') {
            Remove-AppxPackage -Package $cmd -ErrorAction SilentlyContinue
        }
        [System.Windows.Forms.MessageBox]::Show("App '$sel' désinstallée (ou tentée).", "✅")
    }
})

# Nettoyage
$btnClean = New-Object Windows.Forms.Button
$btnClean.Text = 'Retirer toutes les traces'
$btnClean.Top = 300
$btnClean.Left = 160
$btnClean.Width = 180
$form.Controls.Add($btnClean)

$btnClean.Add_Click({
    $sel = $listbox.SelectedItem
    if ($sel) {
        $dirs = @("C:\Program Files", "C:\Program Files (x86)", "C:\ProgramData", "$env:APPDATA", "$env:LOCALAPPDATA", "$env:TEMP", "$env:USERPROFILE\AppData\Local\Packages")
        foreach ($d in $dirs) {
            Get-ChildItem $d -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$sel*" -or $_.FullName -like "*$sel*" } | ForEach-Object {
                Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        $keys = @("HKCU:\Software", "HKLM:\Software", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall")
        foreach ($k in $keys) {
            Get-ChildItem $k -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "*$sel*" } | ForEach-Object {
                Remove-Item $_.PsPath -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        [System.Windows.Forms.MessageBox]::Show("Traces supprimées pour '$sel'.", "🧹")
    }
})

$form.ShowDialog()
