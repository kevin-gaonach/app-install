<#
.SYNOPSIS
Interface graphique PowerShell pour l'installation et la mise a jour d'applications via WinGet.

.DESCRIPTION
Ce script installe le module WinGet si necessaire,
et affiche une interface graphique (GUI) permettant de selectionner et d’installer des applications courantes 
par categories (Developpement, Bureautique, Admins, Gaming, etc.) en utilisant WinGet. 

Trois boutons permettent :
- tout cocher / tout decocher
- installer les applications selectionnees
- mettre a jour toutes les applications WinGet installees

.NOTES
Auteur     : Kevin Gaonach  
Site Web   : https://github.com/kevin-gaonach/app-install 
Version    : 1.0.0.0 
Date       : 2025-07-29

.EXAMPLE
.\winget-essentials-gui.ps1
Lance le script et affiche une selection d'application a installer avec WinGet.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$progressPreference = 'silentlyContinue'

function Show-AppInstallerGUI {

    $form = New-Object Windows.Forms.Form
    $form.AutoSize = $true
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.StartPosition = "CenterScreen"

    # Titre
    $titleLabel = New-Object Windows.Forms.Label
    $titleLabel.Text = "Assistant d’installation"
    $titleLabel.Font = New-Object Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $titleLabel.AutoSize = $true
    $titleLabel.Location = New-Object Drawing.Point(0, 5)
    $form.Controls.Add($titleLabel)

    # Sous-titre
    $subtitleLabel = New-Object Windows.Forms.Label
    $subtitleLabel.Text = "Par Kevin GAONACH"
    $subtitleLabel.Font = New-Object Drawing.Font("Segoe UI", 8)
    $subtitleLabel.AutoSize = $true
    $subtitleLabel.Location = New-Object Drawing.Point(0, 30)
    $form.Controls.Add($subtitleLabel)

    # Information
    $infoLabel = New-Object Windows.Forms.Label
    $infoLabel.Text = "*Les cases grisées correspondent aux applications déjà installées."
    $infoLabel.Font = New-Object Drawing.Font("Segoe UI", 8)
    $infoLabel.AutoSize = $true
    $infoLabel.Location = New-Object Drawing.Point(0, 660)
    $form.Controls.Add($infoLabel)

    $form.Add_Shown({
        $titleLabel.Left = ($form.ClientSize.Width - $titleLabel.Width) / 2
        $subtitleLabel.Left = ($form.ClientSize.Width - $subtitleLabel.Width) / 2
        $infoLabel.Left = ($form.ClientSize.Width - $infoLabel.Width) / 2
    })

    $scrollPanel = New-Object Windows.Forms.Panel
    $scrollPanel.Location = New-Object Drawing.Point(0, 60)
    $scrollPanel.Size = New-Object Drawing.Size(780, 600)
    $scrollPanel.AutoScroll = $true
    $form.Controls.Add($scrollPanel)

    $currentY = 5
    $installedWingetIds = (Get-WinGetPackage).id

    $categories = [ordered]@{
        "Essentiels" = [ordered]@{
			"Adobe Reader" = "Adobe.Acrobat.Reader.64-bit"
            "PDFsam" = "PDFsam.PDFsam"
            "7-Zip" = "7zip.7zip"
            "Notepad++" = "Notepad++.Notepad++"
            "Ant Renamer" = "AntSoftware.AntRenamer"
			"CCleaner" = "Piriform.CCleaner"
            "UniGetUI" = "MartiCliment.UniGetUI"
            "WinDirStat" = "WinDirStat.WinDirStat"
        }
		"Internet" = [ordered]@{
            "Chrome" = "Google.Chrome"
            "Firefox" = "Mozilla.Firefox.fr"
			"Brave" = "Brave.Brave"
			"JDownloader" = "AppWork.JDownloader"
			"VPN TunnelBear" = "TunnelBear.TunnelBear"
			"VPN Proton" = "Proton.ProtonVPN"
			"VPN WireGuard" = "WireGuard.WireGuard"
        }
        "Image" = [ordered]@{
            "Greenshot" = "Greenshot.Greenshot"
            "XnView" = "XnSoft.XnViewMP"
			"Gimp" = "9PNSJCLXDZ0V"
        }
        "Video" = [ordered]@{
			"VLC" = "VideoLAN.VLC"
            "Disney+" = "9NXQXXLFST89"
			"Amazon Video" = "9P6RC76MSMMJ"
			"Netflix" = "9WZDNCRFJ3TJ"
			"Plex" = "XP9CDQW6ML4NQN"
            "Molotov" = "MolotovTV.Molotov"
            "TikTok" = "9NH2GPH4JZS4"
            "Canal+" = "9WZDNCRFJ3DH"
        }
        "Musique" = [ordered]@{
            "Virtual DJ" = "AtomixProductions.VirtualDJ"
			"Amazon Music" = "9NMS233VM4Z9"
            "Deezer" = "9NBLGGH6J7VV"
            "Spotify" = "9NCBCSZSJRSB"
        }
		"Sécurité" = [ordered]@{
			"Veeam Agent" = "Veeam.VeeamAgent"
			"Malwarebytes" = "Malwarebytes.Malwarebytes"
            "KeePassXC" = "KeePassXCTeam.KeePassXC"
            "Bitwarden" = "Bitwarden.Bitwarden"
		}
		"Jeux" = [ordered]@{
            "Playnite" = "Playnite.Playnite"
            "Xbox" = "9MV0B5HZVK9Z"
            "Amazon Games" = "Amazon.Games"
            "EA Desktop" = "ElectronicArts.EADesktop"
            "Epic Games" = "EpicGames.EpicGamesLauncher"
            "Steam" = "Valve.Steam"
            "Ubisoft Connect" = "Ubisoft.Connect"
            "GOG Galaxy" = "GOG.Galaxy"
        }
        "Streaming" = [ordered]@{
            "OBS Studio" = "OBSProject.OBSStudio"
            "Voice Mod" = "XP9B0BH6T8Z7KZ"
			"Nvidia Broadcast" = "Nvidia.Broadcast"
        }
		"Monitoring" = [ordered]@{
            "MSI Afterburner" = "Guru3D.Afterburner"
            "Rivatuner Statistics Server" = "Guru3D.RTSS"
			"HWMonitor" = "CPUID.HWMonitor"
			"Crystal Disk Info" = "CrystalDewWorld.CrystalDiskInfo"
        }
		"Benchmark" = [ordered]@{
			"OCCT" = "OCBase.OCCT.Personal"
			"Crystal Disk Mark" = "CrystalDewWorld.CrystalDiskMark"
			"Cinebench R23" = "Maxon.CinebenchR23"
            "Geekbench" = "PrimateLabs.Geekbench.6"
		}
        "Communication" = [ordered]@{
            "Discord" = "Discord.Discord"
            "Teams" = "Microsoft.Teams.Free"
            "Facebook Messenger" = "9WZDNCRF0083"
            "WhatsAPP" = "9NKSQGP7F2NH"
        }
		"Matériel" = [ordered]@{
			"Logitech G HUB" = "Logitech.GHUB"
			"Corsair iCUE 5" = "Corsair.iCUE.5"
			"MSI Center" = "9NVMNJCR03XV"
			"Elgato StreamDeck" = "Elgato.StreamDeck"
		}
		"Admins" = [ordered]@{
			"GitHub Desktop" = "GitHub.GitHubDesktop"
			"System Informer" = "WinsiderSS.SystemInformer"
			"TeamViewer" = "TeamViewer.TeamViewer"
			"mRemoteNG" = "mRemoteNG.mRemoteNG"
			"PuTTY" = "PuTTY.PuTTY"
			"WinSCP" = "WinSCP.WinSCP"
			"Advanced IP Scanner" = "Famatech.AdvancedIPScanner"
			"WireShark" = "WiresharkFoundation.Wireshark"
		}
    }

    $checkboxes = @{}
    $padding = 10
    $checkboxWidth = 180
    $checkboxHeight = 22
    $panelWidth = $scrollPanel.ClientSize.Width

    foreach ($category in $categories.Keys) {
		$groupBox = New-Object Windows.Forms.GroupBox
		$groupBox.Text = $category
		$groupBox.Font = New-Object Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
		$groupBox.Width = $panelWidth - 40
		$groupBox.Location = New-Object Drawing.Point($padding, $currentY)
		
		
		$groupBoxHeight = 0
		$checkboxesInCategory = @()
		
		$columnsPerRow = [math]::Floor(($groupBox.Width - 20) / $checkboxWidth)
		if ($columnsPerRow -lt 1) { $columnsPerRow = 1 }
		
		$appList = @($categories[$category].Keys)
		for ($i = 0; $i -lt $appList.Count; $i++) {
			$column = $i % $columnsPerRow
			$row = [math]::Floor($i / $columnsPerRow)
		
			$x = 20 + ($column * $checkboxWidth)
			$y = 20 + ($row * $checkboxHeight)
		
			$checkbox = New-Object Windows.Forms.CheckBox
			$checkbox.Text = $appList[$i]
			$checkbox.Width = $checkboxWidth - 10
			$checkbox.Location = New-Object Drawing.Point($x, $y)
			$checkbox.Font = New-Object Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
		
		
			$wingetId = $categories[$category][$appList[$i]]
			if ($installedWingetIds -contains $wingetId) {
				$checkbox.Enabled = $false
				$checkbox.Checked = $false
				$checkbox.ForeColor = [System.Drawing.Color]::Gray
			}
		
			$groupBox.Controls.Add($checkbox)
			$checkboxes[$appList[$i]] = $checkbox
			$checkboxesInCategory += $checkbox
		}
		
		
		$rowsUsed = [math]::Ceiling($appList.Count / $columnsPerRow)
		$groupBoxHeight = ($rowsUsed * $checkboxHeight) + 30
		$groupBox.Height = $groupBoxHeight
		
		$scrollPanel.Controls.Add($groupBox)
		$currentY += $groupBoxHeight + 10
		
    }

    $bottomY = $scrollPanel.Bottom + 20

    # Bouton Tout cocher/décocher
    $toggleAllButton = New-Object Windows.Forms.Button
    $toggleAllButton.Text = "Tout cocher"
    $toggleAllButton.Width = 60
    $toggleAllButton.Height = 40
    $toggleAllButton.Location = New-Object Drawing.Point(20, $bottomY)
    $form.Controls.Add($toggleAllButton)

    $toggleAllButton.Add_Click({
    $shouldCheck = $false
    foreach ($cb in $checkboxes.Values) {
        if ($cb.Enabled -and -not $cb.Checked) {
            $shouldCheck = $true
            break
        }
    }

    foreach ($cb in $checkboxes.Values) {
        if ($cb.Enabled) {
            $cb.Checked = $shouldCheck
        }
    }

    $toggleAllButton.Text = if ($shouldCheck) { "Tout décocher" } else { "Tout cocher" }
    })


    # Bouton d'installation
    $installButton = New-Object Windows.Forms.Button
    $installButton.Text = "Installer les applications sélectionnées"
    $installButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $installButton.Width = 200
    $installButton.Height = 40
    $installButton.Location = New-Object Drawing.Point(560, $bottomY)
    $form.Controls.Add($installButton)

    # Bouton de mise à jour
    $updateButton = New-Object Windows.Forms.Button
    $updateButton.Text = "Mettre à jour les applications installées"
    $updateButton.Width = 140
    $updateButton.Height = 40
    $updateButton.Location = New-Object Drawing.Point(90, $bottomY)
    $form.Controls.Add($updateButton)

    $form.Height = $updateButton.Bottom + 40

    $appNamesById = @{}
    foreach ($category in $categories.Keys) {
        foreach ($appName in $categories[$category].Keys) {
            $id = $categories[$category][$appName]
            $appNamesById[$id] = $appName
        }
    }

    $installButton.Add_Click({
        $selectedApps = @()
        foreach ($category in $categories.Keys) {
            foreach ($appName in $categories[$category].Keys) {
                if ($checkboxes[$appName].Checked) {
                    $selectedApps += $categories[$category][$appName]
                }
            }
        }

        if ($selectedApps.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Aucune application sélectionnée.", "Info", "OK", "Information")
            return
        }

        foreach ($id in $selectedApps) {
            $appName = $appNamesById[$id]
            Write-Host "Installation de $appName ($id)..." -ForegroundColor Cyan
            $install = Install-WinGetPackage -Id $id -Mode Silent -ErrorAction Stop

            if ($install.Status -eq "Ok") {
                Write-Host "Installation de $appName réussie." -ForegroundColor Green
            } else {
                Write-Host "Échec d'installation de $appName : $($install.Status) $($install.ExtendedErrorCode)" -ForegroundColor Red
            }
        }

        [System.Windows.Forms.MessageBox]::Show("Installation terminée", "Terminé", "OK", "Information")
    })

    $updateButton.Add_Click({
        $UpdateAvailable = (Get-WinGetPackage | Where-Object IsUpdateAvailable).Id

        if ($UpdateAvailable.Count -gt 0) {
            foreach ($id in $UpdateAvailable) {
                $appName = $appNamesById[$id]
                Write-Host "Mise à jour de $appName ($id)..." -ForegroundColor Cyan
                $update = Update-WinGetPackage -Id $id -Mode Silent -ErrorAction Stop

                if ($update.Status -eq "Ok") {
                    Write-Host "Mise à jour de $appName réussie." -ForegroundColor Green
                } else {
                    Write-Host "Échec de mise à jour de $appName : $($update.Status) $($update.ExtendedErrorCode)" -ForegroundColor Red
                }
            }

            [System.Windows.Forms.MessageBox]::Show("Mise à jour terminée", "Succès", "OK", "Information")
        } else {
            Write-Host "Aucune mise à jour disponible." -ForegroundColor Cyan
            [System.Windows.Forms.MessageBox]::Show("Aucune mise à jour", "Succès", "OK", "Information")
        }
    })

    [void]$form.ShowDialog()
}

# Vérifie si le module powershell WinGet est déjà disponible
if (-not (Get-Module -ListAvailable -Name "Microsoft.WinGet.Client")) {
    Write-Host "Installation du module WinGet PowerShell depuis PSGallery..." -ForegroundColor Blue
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Write-Host "Exécution de Repair-WinGetPackageManager pour initialisation..." -ForegroundColor Blue
    Repair-WinGetPackageManager
    Write-Host "Installation de WinGet terminée." -ForegroundColor Green
}

Show-AppInstallerGUI
