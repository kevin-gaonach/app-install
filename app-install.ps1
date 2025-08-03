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
Auteur     : Kévin Gaonach
Site Web   : https://github.com/kevin-gaonach/app-install
Version    : 1.1.0.0
Date       : 2025-08-01

.EXAMPLE
.\winget-essentials-gui.ps1
Lance le script et affiche une selection d'application a installer avec WinGet.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$progressPreference = 'silentlyContinue'

# Détection si OS serveur
$isServer = ((Get-CimInstance Win32_OperatingSystem).ProductType -ne 1)

function ConvertTo-SubnetMaskLength {
    param (
        [Parameter(Mandatory)]
        [ValidatePattern("^(\d{1,3}\.){3}\d{1,3}$")]
        [string]$SubnetMask
    )

        $bytes = $SubnetMask -split '\.' | ForEach-Object { [Convert]::ToByte($_) }
        $binary = ($bytes | ForEach-Object { [Convert]::ToString($_, 2).PadLeft(8, '0') }) -join ''
        return ($binary -split '0')[0].Length

}

function Convert-PrefixLengthToSubnetMask {
    param (
        [Parameter(Mandatory)]
        [ValidateRange(0,32)]
        [int]$PrefixLength
    )

    $mask = [uint32]0
    for ($i = 0; $i -lt $PrefixLength; $i++) {
        $mask = $mask -bor (1 -shl (31 - $i))
    }

    # Convertir directement avec les octets en BigEndian
    $bytes = [BitConverter]::GetBytes($mask)

    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($bytes)
    }

    return ($bytes | ForEach-Object { $_ }) -join '.'
}

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
    $subtitleLabel.Text = "1.1.0.0"
    $subtitleLabel.Font = New-Object Drawing.Font("Segoe UI", 8)
    $subtitleLabel.AutoSize = $true
    $subtitleLabel.Location = New-Object Drawing.Point(0, 30)
    $form.Controls.Add($subtitleLabel)

    # Création du TabControl
    $tabControl = New-Object Windows.Forms.TabControl
    $tabControl.Location = New-Object Drawing.Point(5, 55)
    $tabControl.Size = New-Object Drawing.Size(790, 740)

    $form.Controls.Add($tabControl)

    # Onglet Applications
    $tabApps = New-Object Windows.Forms.TabPage
    $tabApps.Text = "Applications"
    $tabControl.TabPages.Add($tabApps)

    # Panel scrollable pour les applications
    $scrollPanel = New-Object Windows.Forms.Panel
    $scrollPanel.Location = New-Object Drawing.Point(0, 0)
    $scrollPanel.Size = New-Object Drawing.Size(780, 640)
    $scrollPanel.AutoScroll = $true
    $tabApps.Controls.Add($scrollPanel)

    $currentY = 5
    $appY = $scrollPanel.Bottom

    # Information
    $infoLabel = New-Object Windows.Forms.Label
    $infoLabel.Text = "*Les cases grisées correspondent aux applications déjà installées."
    $infoLabel.Font = New-Object Drawing.Font("Segoe UI", 8)
    $infoLabel.AutoSize = $true
    $infoLabel.Location = New-Object Drawing.Point(0, $appY)
    $tabApps.Controls.Add($infoLabel)

    $form.Add_Shown({
        $titleLabel.Left = ($form.ClientSize.Width - $titleLabel.Width) / 2
        $subtitleLabel.Left = ($form.ClientSize.Width - $subtitleLabel.Width) / 2
        $infoLabel.Left = ($form.ClientSize.Width - $infoLabel.Width) / 2
    })

    $appY = $infoLabel.Bottom

        # Champ de recherche WinGet

    $searchTextBox = New-Object Windows.Forms.TextBox
    $searchTextBox.Location = New-Object Drawing.Point(180, $appY)
    $searchTextBox.Width = 260
    $searchTextBox.Height = 40
    $searchTextBox.Multiline = $true
    $tabApps.Controls.Add($searchTextBox)

    $searchButton = New-Object Windows.Forms.Button
    $searchButton.Text = "Chercher une application"
    $searchButton.Width = 150
    $searchButton.Height = 40
    $searchButton.Location = New-Object Drawing.Point(450, $appY)
    $tabApps.Controls.Add($searchButton)

    $searchButton.Add_Click({
        $query = $searchTextBox.Text.Trim()
        if ([string]::IsNullOrEmpty($query)) {
            [System.Windows.Forms.MessageBox]::Show("Veuillez entrer un nom d'application à rechercher.", "Erreur", "OK", "Error")
            return
        }
        try {
            $results = Find-WinGetPackage -Name $query -ErrorAction Stop
            if ($results.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("Aucun résultat trouvé.", "Info", "OK", "Information")
                return
            }

            # Fenêtre de sélection
            $resultForm = New-Object Windows.Forms.Form
            $resultForm.Text = "Résultats de recherche WinGet"
            $resultForm.StartPosition = "CenterScreen"
            $resultForm.Size = New-Object Drawing.Size(600,400)

            $resultList = New-Object Windows.Forms.ListBox
            $resultList.Location = New-Object Drawing.Point(10,10)
            $resultList.Size = New-Object Drawing.Size(560,300)
            $resultList.Font = New-Object Drawing.Font("Consolas", 9)
            foreach ($pkg in $results) {
                $resultList.Items.Add("$($pkg.Name) - $($pkg.Version) ($($pkg.Id)) [$($pkg.Source)]")
            }
            $resultForm.Controls.Add($resultList)

            $installButton = New-Object Windows.Forms.Button
            $installButton.Text = "Installer le package sélectionné"
            $installButton.Width = 150
            $installButton.Height = 40
            $installButton.Location = New-Object Drawing.Point(200,320)
            $resultForm.Controls.Add($installButton)

            $installButton.Add_Click({
                if ($resultList.SelectedIndex -eq -1) {
                    [System.Windows.Forms.MessageBox]::Show("Sélectionnez un package à installer.", "Erreur", "OK", "Error")
                    return
                }
            $installButton.Enabled = $false
            $selectedLine = $resultList.SelectedItem
            if ($selectedLine -match '\(([^)]+)\)') {
                $packageId = $matches[1]
            }
            if ($selectedLine -match '^(.+?)\s+-') {
            $packageName = $matches[1]
            }
            $resultForm.Close()
            Write-Host "Installation de $packageName ($packageId)..." -ForegroundColor Cyan
			$install = Install-WinGetPackage -Id $packageId -Mode Silent -ErrorAction Stop
			if ($install.Status -eq "Ok") {
                Write-Host "Installation de $packageName ($packageId) réussie." -ForegroundColor Green
            } else {
                Write-Host "Échec d'installation de $packageName ($packageId) : $($install.Status) $($install.ExtendedErrorCode)" -ForegroundColor Red
            }
			[System.Windows.Forms.MessageBox]::Show("Installation terminée", "Terminé", "OK", "Information")
            })
            $resultForm.ShowDialog()
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Erreur lors de la recherche : $_", "Erreur", "OK", "Error")
        }
    })

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
        "Communication" = [ordered]@{
            "Discord" = "Discord.Discord"
            "Teams" = "Microsoft.Teams.Free"
            "Facebook Messenger" = "9WZDNCRF0083"
            "WhatsAPP" = "9NKSQGP7F2NH"
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
        "Image" = [ordered]@{
            "Greenshot" = "Greenshot.Greenshot"
            "XnView" = "XnSoft.XnViewMP"
			"Gimp" = "9PNSJCLXDZ0V"
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
        "Streaming" = [ordered]@{
            "OBS Studio" = "OBSProject.OBSStudio"
            "Voice Mod" = "XP9B0BH6T8Z7KZ"
			"Nvidia Broadcast" = "Nvidia.Broadcast"
        }
		"Matériel" = [ordered]@{
			"Logitech G HUB" = "Logitech.GHUB"
			"Corsair iCUE 5" = "Corsair.iCUE.5"
			"MSI Center" = "9NVMNJCR03XV"
			"Elgato StreamDeck" = "Elgato.StreamDeck"
		}
		"Sécurité" = [ordered]@{
			"Veeam Agent" = "Veeam.VeeamAgent"
			"Malwarebytes" = "Malwarebytes.Malwarebytes"
            "KeePassXC" = "KeePassXCTeam.KeePassXC"
            "Proton Pass" = "Proton.ProtonPass"
		}
		"Admins" = [ordered]@{
			"GitHub Desktop" = "GitHub.GitHubDesktop"
            "Visual Studio Code" = "Microsoft.VisualStudioCode"
			"System Informer" = "WinsiderSS.SystemInformer"
			"TeamViewer" = "TeamViewer.TeamViewer"
			"mRemoteNG" = "mRemoteNG.mRemoteNG"
			"WinSCP" = "WinSCP.WinSCP"
			"Advanced IP Scanner" = "Famatech.AdvancedIPScanner"
			"WireShark" = "WiresharkFoundation.Wireshark"
		}
    }

    if ($isServer) {

    $categories.Remove("Communication")
    $categories.Remove("Video")
    $categories.Remove("Musique")
    $categories.Remove("Jeux")
    $categories.Remove("Image")
    $categories.Remove("Streaming")
    $categories.Remove("Monitoring")
    $categories.Remove("Benchmark")
    $categories.Remove("Matériel")

    $categories["Essentiels"].Remove("CCleaner")
    $categories["Essentiels"].Remove("PDFsam")
    $categories["Essentiels"].Remove("Adobe Reader")
    $categories["Essentiels"].Remove("Ant Renamer")
    $categories["Internet"].Remove("VPN TunnelBear")
    $categories["Internet"].Remove("VPN Proton")
    $categories["Internet"].Remove("VPN WireGuard")

    }

    $installedWingetIds = (Get-WinGetPackage).id

    $appNamesById = @{}
    foreach ($category in $categories.Keys) {
        foreach ($appName in $categories[$category].Keys) {
            $id = $categories[$category][$appName]
            $appNamesById[$id] = $appName
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

    # Bouton d'installation
    $installButton = New-Object Windows.Forms.Button
    $installButton.Text = "Installer les applications"
    $installButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $installButton.Width = 150
    $installButton.Height = 40
    $installButton.Location = New-Object Drawing.Point(610, $appY)
    $tabApps.Controls.Add($installButton)

        $installButton.Add_Click({
            $installButton.Enabled = $false
    try {
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
                Write-Host "Installation de $appName ($id) réussie." -ForegroundColor Green
            } else {
                Write-Host "Échec d'installation de $appName ($id) : $($install.Status) $($install.ExtendedErrorCode)" -ForegroundColor Red
            }
        }

        [System.Windows.Forms.MessageBox]::Show("Installation terminée", "Terminé", "OK", "Information")
            } finally {
        $installButton.Enabled = $true
    }
    })

    # Bouton Tout cocher/décocher
    $toggleAllButton = New-Object Windows.Forms.Button
    $toggleAllButton.Text = "Tout cocher"
    $toggleAllButton.Width = 150
    $toggleAllButton.Height = 40
    $toggleAllButton.Location = New-Object Drawing.Point(20, $appY)
    $tabApps.Controls.Add($toggleAllButton)
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

    # Onglet Configurations
    $tabConfig = New-Object Windows.Forms.TabPage
    $tabConfig.Text = "Configurations"
    $tabControl.TabPages.Add($tabConfig)

    $confY = 30

    function UpdateNetworkConfigFields {
    $interface = $interfaceComboBox.SelectedItem

    # Met à jour les champs IP
    $ipTextBox.Text = (Get-NetIPAddress -InterfaceAlias $interface -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    $subnetTextBox.Text = Convert-PrefixLengthToSubnetMask -PrefixLength ((Get-NetIPAddress -InterfaceAlias $interface -AddressFamily IPv4 -ErrorAction SilentlyContinue).PrefixLength)
    $gatewayTextBox.Text = (Get-NetRoute -InterfaceAlias $interface -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop
    $ipButton.Add_Click({
        $ipButton.Enabled = $false
        try {
            $ip = $ipTextBox.Text.Trim()
            $subnet = $subnetTextBox.Text.Trim()
            $gateway = $gatewayTextBox.Text.Trim()

            if ([string]::IsNullOrEmpty($ip) -or [string]::IsNullOrEmpty($subnet) -or [string]::IsNullOrEmpty($gateway)) {
                [System.Windows.Forms.MessageBox]::Show("Veuillez remplir tous les champs.", "Erreur", "OK", "Error")
                return
            }

            Write-Host "Configuration de l'adresse IP..." -ForegroundColor Cyan
			Get-NetIPAddress -InterfaceAlias $interface | Remove-NetIPAddress -Confirm:$false
			Get-NetRoute -InterfaceAlias $interface -DestinationPrefix "0.0.0.0/0" | Remove-NetRoute -Confirm:$false
	        New-NetIPAddress -InterfaceAlias $interface  -IPAddress $ip -PrefixLength (ConvertTo-SubnetMaskLength $subnet) -DefaultGateway $gateway -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("Configuration IP effectuée.", "Information", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de la configuration IP : $_", "Erreur", "OK", "Error")
        } finally {
            $ipButton.Enabled = $true
        }
    })

    # DHCP
    $dhcpEnabled = (Get-NetIPInterface -InterfaceAlias $interface -ErrorAction SilentlyContinue).Dhcp
    $dhcpButton.Enabled = -not $dhcpEnabled
    $dhcpButton.Add_Click({
        $dhcpButton.Enabled = $false
        try {
            Write-Host "Activation du DHCP..." -ForegroundColor Cyan
            Set-NetIPInterface -InterfaceAlias $interface -Dhcp Enabled -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("DHCP activé avec succès.", "Information", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de l'activation du DHCP : $_", "Erreur", "OK", "Error")
        } finally {
            $dhcpButton.Enabled = $true
        }
    })

    # IPv6
    $ipv6Enabled = (Get-NetAdapterBinding -Name $interface -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue).Enabled

    if ($ipv6Enabled) {
        $ipv6Button.Text = "Désactiver l'IPv6"
        $ipv6Button.Enabled = $true
        $ipv6Button.Add_Click({
            $ipv6Button.Enabled = $false
            try {
                Write-Host "Désactivation de l'IPv6..." -ForegroundColor Cyan
                Disable-NetAdapterBinding -Name $interface -ComponentID ms_tcpip6 -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("IPv6 désactivé avec succès.", "Information", "OK", "Information")
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Échec de la désactivation de l'IPv6 : $_", "Erreur", "OK", "Error")
            } finally {
                $ipv6Button.Enabled = $true
                UpdateNetworkConfigFields
            }
        })
    } else {
        $ipv6Button.Text = "Activer l'IPv6"
        $ipv6Button.Enabled = $true
        $ipv6Button.Add_Click({
            $ipv6Button.Enabled = $false
            try {
                Write-Host "Activation de l'IPv6..." -ForegroundColor Cyan
                Enable-NetAdapterBinding -Name $interface -ComponentID ms_tcpip6 -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("IPv6 activé avec succès.", "Information", "OK", "Information")
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Échec de l'activation de l'IPv6 : $_", "Erreur", "OK", "Error")
            } finally {
                $ipv6Button.Enabled = $true
                UpdateNetworkConfigFields
            }
        })
    }

    # DNS
    $dnsTextBox.Text = (Get-DnsClientServerAddress -InterfaceAlias $interface -ErrorAction SilentlyContinue).ServerAddresses -join ", "
    $dnsButton.Add_Click({
        $dnsButton.Enabled = $false
        try {
            $dnsServers = $dnsTextBox.Text.Trim().Split(",") | ForEach-Object { $_.Trim() }
            if ($dnsServers.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("Veuillez entrer au moins un serveur DNS.", "Erreur", "OK", "Error")
                return
            }
            Write-Host "Configuration des serveurs DNS..." -ForegroundColor Cyan
            Set-DnsClientServerAddress -InterfaceAlias $interface -ServerAddresses $dnsServers -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("Configuration DNS effectuée.", "Information", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de la configuration DNS : $_", "Erreur", "OK", "Error")
        } finally {
            $dnsButton.Enabled = $true
        }
    })
    }

    # Selecteur de l'interface réseau
    $interfaceLabel = New-Object Windows.Forms.Label
    $interfaceLabel.Text = "Interface réseau :"
    $interfaceLabel.Location = New-Object Drawing.Point(20, $confY)
    $interfaceLabel.AutoSize = $true
    $tabConfig.Controls.Add($interfaceLabel)

    $interfaceComboBox = New-Object Windows.Forms.ComboBox
    $interfaceComboBox.Location = New-Object Drawing.Point(140, $confY)
    $interfaceComboBox.Width = 280
    $interfaceComboBox.DropDownStyle = "DropDownList"
    $interfaces = Get-NetAdapter | Select-Object -ExpandProperty Name
    $interfaceComboBox.Items.AddRange($interfaces)
    $tabConfig.Controls.Add($interfaceComboBox)

    $interfaceComboBox.SelectedIndex = 0
    $interface = $interfaceComboBox.SelectedItem

    $interfaceComboBox.Add_SelectedIndexChanged({
        $global:interface = $interfaceComboBox.SelectedItem
        UpdateNetworkConfigFields
    })

    # Bouton pour activer le DHCP
    $dhcpButton = New-Object Windows.Forms.Button
    $dhcpButton.Text = "Activer le DHCP"
    $dhcpButton.Width = 150
    $dhcpButton.Height = 20
    $dhcpButton.Location = New-Object Drawing.Point(430, $confY)
    $tabConfig.Controls.Add($dhcpButton)

    # Bouton pour  l'IPv6
    $ipv6Button = New-Object Windows.Forms.Button
    $ipv6Button.Text = "Désactiver l'IPv6"
    $ipv6Button.Width = 150
    $ipv6Button.Height = 20
    $ipv6Button.Location = New-Object Drawing.Point(590, $confY)
    $tabConfig.Controls.Add($ipv6Button)

    $confY += 60

    # Labels pour la configuration IP
    $iPlabel = New-Object Windows.Forms.Label
    $iPlabel.Text = "Adresse IP"
    $iPlabel.Location = New-Object Drawing.Point(140, $confY)
    $iPlabel.AutoSize = $true
    $tabConfig.Controls.Add($iPlabel)

    $subnetLabel = New-Object Windows.Forms.Label
    $subnetLabel.Text = "Masque de sous-réseau"
    $subnetLabel.Location = New-Object Drawing.Point(290, $confY )
    $subnetLabel.AutoSize = $true
    $tabConfig.Controls.Add($subnetLabel)

    $gatewayLabel = New-Object Windows.Forms.Label
    $gatewayLabel.Text = "Passerelle"
    $gatewayLabel.Location = New-Object Drawing.Point(440, $confY)
    $gatewayLabel.AutoSize = $true
    $tabConfig.Controls.Add($gatewayLabel)

    $confY += 20

    # Champs de saisie pour la configuration IP

    $confipLabel = New-Object Windows.Forms.Label
    $confipLabel.Text = "Configuration IP :"
    $confipLabel.Location = New-Object Drawing.Point(20, $confY)
    $confipLabel.AutoSize = $true
    $tabConfig.Controls.Add($confipLabel)

    $ipTextBox = New-Object Windows.Forms.TextBox
    $ipTextBox.Location = New-Object Drawing.Point(140, $confY)
    $ipTextBox.Width = 140
    $tabConfig.Controls.Add($ipTextBox)

    $subnetTextBox = New-Object Windows.Forms.TextBox
    $subnetTextBox.Location = New-Object Drawing.Point(290, $confY)
    $subnetTextBox.Width = 140
    $tabConfig.Controls.Add($subnetTextBox)

    $gatewayTextBox = New-Object Windows.Forms.TextBox
    $gatewayTextBox.Location = New-Object Drawing.Point(440, $confY)
    $gatewayTextBox.Width = 140
    $tabConfig.Controls.Add($gatewayTextBox)

    # Bouton de configuration IP
    $ipButton = New-Object Windows.Forms.Button
    $ipButton.Text = "Configurer l'adresse IP"
    $ipButton.Width = 150
    $ipButton.Height = 20
    $ipButton.Location = New-Object Drawing.Point(590, $confY)
    $tabConfig.Controls.Add($ipButton)

    $confY += 60

    # Information configuration DNS
    $dnsLabel = New-Object Windows.Forms.Label
    $dnsLabel.Text = "Configuration DNS :"
    $dnsLabel.Location = New-Object Drawing.Point(20, $confY)
    $dnsLabel.AutoSize = $true
    $tabConfig.Controls.Add($dnsLabel)
    $dnsTextBox = New-Object Windows.Forms.TextBox
    $dnsTextBox.Location = New-Object Drawing.Point(140, $confY)
    $dnsTextBox.Width = 200
    $dnsTextBox.Text = (Get-DnsClientServerAddress -InterfaceAlias $interface).ServerAddresses -join ", "
    $tabConfig.Controls.Add($dnsTextBox)
    # Bouton de configuration DNS
    $dnsButton = New-Object Windows.Forms.Button
    $dnsButton.Text = "Configurer le DNS"
    $dnsButton.Width = 150
    $dnsButton.Height = 20
    $dnsButton.Location = New-Object Drawing.Point(360, $confY)
    $tabConfig.Controls.Add($dnsButton)

    UpdateNetworkConfigFields

    $confY += 130

    # Champ de saisie du nom de l'ordinateur
    $computerNameLabel = New-Object Windows.Forms.Label
    $computerNameLabel.Text = "Nom de l'ordinateur :"
    $computerNameLabel.Location = New-Object Drawing.Point(20, $confY)
    $computerNameLabel.AutoSize = $true
    $tabConfig.Controls.Add($computerNameLabel)
    $computerNameTextBox = New-Object Windows.Forms.TextBox
    $computerNameTextBox.Location = New-Object Drawing.Point(140, $confY)
    $computerNameTextBox.Width = 200
    $computerNameTextBox.Text = (Get-CimInstance Win32_ComputerSystem).Name
    $tabConfig.Controls.Add($computerNameTextBox)

    # Bouton de changement de nom de l'ordinateur
    $renameButton = New-Object Windows.Forms.Button
    $renameButton.Text = "Changer le nom"
    $renameButton.Width = 150
    $renameButton.Height = 20
    $renameButton.Location = New-Object Drawing.Point(360, $confY)
    $tabConfig.Controls.Add($renameButton)
    $renameButton.Add_Click({
        $renameButton.Enabled = $false
        try {
            $newName = $computerNameTextBox.Text.Trim()
            if ([string]::IsNullOrEmpty($newName)) {
                [System.Windows.Forms.MessageBox]::Show("Veuillez entrer un nom d'ordinateur valide.", "Erreur", "OK", "Error")
                return
            }
            Write-Host "Changement du nom de l'ordinateur en '$newName'..." -ForegroundColor Cyan
            Rename-Computer -NewName $newName
            [System.Windows.Forms.MessageBox]::Show("Ordinateur renomé.", "Information", "OK", "Information")
        } finally {
            $renameButton.Enabled = $true
        }
    })

    $confY += 50

    # Champ de saisie du domaine
    $domainLabel = New-Object Windows.Forms.Label
    $domainLabel.Text = "Domaine :"
    $domainLabel.Location = New-Object Drawing.Point(20, $confY)
    $domainLabel.AutoSize = $true
    $tabConfig.Controls.Add($domainLabel)
    $domainTextBox = New-Object Windows.Forms.TextBox
    $domainTextBox.Location = New-Object Drawing.Point(140, $confY)
    $domainTextBox.Width = 200
    $domainTextBox.Text = (Get-CimInstance Win32_ComputerSystem).Domain
    $tabConfig.Controls.Add($domainTextBox)

    # Bouton de mise au domaine
    $domainButton = New-Object Windows.Forms.Button
    $domainButton.Text = "Mettre au domaine"
    $domainButton.Width = 150
    $domainButton.Height = 20
    $domainButton.Location = New-Object Drawing.Point(360, $confY)
    $tabConfig.Controls.Add($domainButton)
    $domainButton.Add_Click({
        $domainButton.Enabled = $false
        try {
            Write-Host "Mise au domaine..." -ForegroundColor Cyan
            $credential = Get-Credential -Message "Entrez les informations d'identification du domaine"
            Add-Computer -DomainName $domainTextBox.Text -Credential $credential
            [System.Windows.Forms.MessageBox]::Show("Mise au domaine effectuée.", "Information", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de la mise au domaine : $_", "Erreur", "OK", "Error")
        } finally {
            $domainButton.Enabled = $true
        }
    })

    # Informations de redemarrage

    $confY = 660

    $restartInfoLabel = New-Object Windows.Forms.Label
    $restartInfoLabel.Text = "*Pour appliquer les changements, redémarrez l'ordinateur."
    $restartInfoLabel.Location = New-Object Drawing.Point(100, $confY)
    $restartInfoLabel.AutoSize = $true
    $tabConfig.Controls.Add($restartInfoLabel)

    # Bouton de redémarrage
    $restartButton = New-Object Windows.Forms.Button
    $restartButton.Text = "Redémarrer"
    $restartButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $restartButton.Width = 150
    $restartButton.Height = 40
    $restartButton.Location = New-Object Drawing.Point(610, $confY)
    $tabConfig.Controls.Add($restartButton)
    $restartButton.Add_Click({
        $restartButton.Enabled = $false
        try {
            Write-Host "Redémarrage de l'ordinateur..." -ForegroundColor Cyan
            Restart-Computer -ErrorAction Stop
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec du redémarrage : $_", "Erreur", "OK", "Error")
        } finally {
            $restartButton.Enabled = $true
        }
    })

    # Onglet Optimisations
    $tabOpti = New-Object Windows.Forms.TabPage
    $tabOpti.Text = "Optimisations"
    $tabControl.TabPages.Add($tabOpti)

    $optiY = 20
    $optiX = 300

        function UpdateConfigButtons {
    # Bureau à distance
    $remoteDekstopStatus = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections").fDenyTSConnections
    if ($remoteDekstopStatus -eq 0) {
        $remoteDesktopButton.Text = "Désactiver le Bureau à distance"
    } else {
        $remoteDesktopButton.Text = "Activer le Bureau à distance"
    }

    # UAC
    $uacStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
    if ($uacStatus -eq 1) {
        $uacButton.Text = "Désactiver l'UAC"
    } else {
        $uacButton.Text = "Activer l'UAC"
    }

    # Pare-feu
    $firewallStatus = (Get-NetFirewallProfile -All).Enabled
    if ($firewallStatus -contains $true) {
        $firewallButton.Text = "Désactiver le Pare-feu"
    } else {
        $firewallButton.Text = "Activer le Pare-feu"
    }
    }

    # Bouton bureau à distance
    $remoteDekstopStatus = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections").fDenyTSConnections
    $remoteDesktopButton = New-Object Windows.Forms.Button
    if ($remoteDekstopStatus -eq 0) {
        $remoteDesktopButton.Text = "Désactiver le Bureau à distance"
    } else {
        $remoteDesktopButton.Text = "Activer le Bureau à distance"
    }
    $remoteDesktopButton.Width = 150
    $remoteDesktopButton.Height = 40
    $remoteDesktopButton.Location = New-Object Drawing.Point($optiX, $optiY)
    $tabOpti.Controls.Add($remoteDesktopButton)
    $remoteDesktopButton.Add_Click({
        $remoteDesktopButton.Enabled = $false
        try {
             $remoteDekstopStatus = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections").fDenyTSConnections
            if ($remoteDekstopStatus -eq 0) {
                Write-Host "Désactivation du Bureau à distance..." -ForegroundColor Cyan
                Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1 -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Bureau à distance désactivé.", "Information", "OK", "Information")
            } else {
                Write-Host "Activation du Bureau à distance..." -ForegroundColor Cyan
                Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -ErrorAction Stop
                $fwrules = Get-NetFirewallRule | Where-Object { ($_ | Get-NetFirewallPortFilter).LocalPort -eq 3389 }
                if ($fwrules) {
                    $fwrules | Enable-NetFirewallRule
                } else {
                    New-NetFirewallRule -DisplayName "Remote Desktop (TCP-In)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3389 -Name "Allow-RDP-TCP" -Profile Any
                    New-NetFirewallRule -DisplayName "Remote Desktop (UDP-In)" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 3389 -Name "Allow-RDP-UDP" -Profile Any
                }
                [System.Windows.Forms.MessageBox]::Show("Bureau à distance activé.", "Information", "OK", "Information")
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de l'activation/désactivation du Bureau à distance : $_", "Erreur", "OK", "Error")
        } finally {
            $remoteDesktopButton.Enabled = $true
            UpdateConfigButtons
        }
})

    $optiY += 50

    # Bouton UAC
    $uacStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
    $uacButton = New-Object Windows.Forms.Button
    $uacButton.Width = 150
    $uacButton.Height = 40
    $uacButton.Location = New-Object Drawing.Point($optiX, $optiY)
    if ($uacStatus -eq 1) {
        $uacButton.Text = "Désactiver l'UAC"
    } else {
        $uacButton.Text = "Activer l'UAC"
    }
    $tabOpti.Controls.Add($uacButton)

    $uacButton.Add_Click({
    $uacButton.Enabled = $false
    try {
        $uacStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
        if ($uacStatus -eq 1) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -ErrorAction Stop
        Write-Host "Désactivation de l'UAC..." -ForegroundColor Cyan
        [System.Windows.Forms.MessageBox]::Show("UAC désactivé.", "Information", "OK", "Information")
        } else {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1 -ErrorAction Stop
        Write-Host "Activation de l'UAC..." -ForegroundColor Cyan
        [System.Windows.Forms.MessageBox]::Show("UAC activé.", "Information", "OK", "Information")
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur lors du changement UAC : $_", "Erreur", "OK", "Error")
    } finally {
        $uacButton.Enabled = $true
        UpdateConfigButtons
    }
})

    $optiY += 50

    # Bouton desactivation du pare-feu
    $firewallStatus = (Get-NetFirewallProfile -All).Enabled
    $firewallButton = New-Object Windows.Forms.Button
    if ($firewallStatus -contains $true) {
        $firewallButton.Text = "Désactiver le pare-feu"
    } else {
        $firewallButton.Text = "Activer le pare-feu"
    }
    $firewallButton.Width = 150
    $firewallButton.Height = 40
    $firewallButton.Location = New-Object Drawing.Point($optiX, $optiY)
    $tabOpti.Controls.Add($firewallButton)
    $firewallButton.Add_Click({
        $firewallButton.Enabled = $false
        try {
            $firewallStatus = (Get-NetFirewallProfile -All).Enabled
            if ($firewallStatus -contains $true) {
                Write-Host "Désactivation du pare-feu..." -ForegroundColor Cyan
                Set-NetFirewallProfile -All -Enabled False -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Pare-feu désactivé.", "Information", "OK", "Information")
            } else {
                Write-Host "Activation du pare-feu..." -ForegroundColor Cyan
                Set-NetFirewallProfile -All -Enabled True -ErrorAction Stop
                [System.Windows.Forms.MessageBox]::Show("Pare-feu activé.", "Information", "OK", "Information")
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de l'activation/désactivation du pare-feu : $_", "Erreur", "OK", "Error")
        } finally {
            $firewallButton.Enabled = $true
            UpdateConfigButtons
        }
    })

    $optiY += 50

    # Bouton de nettoyage du système
    $cleanupButton = New-Object Windows.Forms.Button
    $cleanupButton.Text = "Nettoyer le système"
    $cleanupButton.Width = 150
    $cleanupButton.Height = 40
    $cleanupButton.Location = New-Object Drawing.Point($optiX, $optiY)
    $tabOpti.Controls.Add($cleanupButton)
    $cleanupButton.Add_Click({
        $cleanupButton.Enabled = $false
        try {
            Write-Host "Nettoyage du système..." -ForegroundColor Cyan
            # Exécute le nettoyage de disque
            Start-Process "cleanmgr.exe" -Wait -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("Nettoyage terminé.", "Information", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec du nettoyage : $_", "Erreur", "OK", "Error")
        } finally {
            $cleanupButton.Enabled = $true
        }
    })

    $optiY += 50

    # Bouton de debloat
    $debloatButton = New-Object Windows.Forms.Button
    $debloatButton.Text = "Debloat le système"
    $debloatButton.Width = 150
    $debloatButton.Height = 40
    $debloatButton.Location = New-Object Drawing.Point($optiX, $optiY)
    $tabOpti.Controls.Add($debloatButton)
    $debloatButton.Add_Click({
    $debloatButton.Enabled = $false
    try {
        Write-Host "Débloat du système..." -ForegroundColor Cyan
        $tempScript = [System.IO.Path]::Combine($env:TEMP, "debloat.ps1")
        $scriptContent = @'
$packages = @(
    "Microsoft.OutlookForWindows",
    "Clipchamp.Clipchamp",
    "Microsoft.3DBuilder",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.BingWeather",
    "Microsoft.BingSports",
    "Microsoft.BingFinance",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.BingNews",
    "Microsoft.Office.OneNote",
    "Microsoft.Office.Sway",
    "Microsoft.WindowsPhone",
    "Microsoft.CommsPhone",
    "Microsoft.Getstarted",
    "Microsoft.549981C3F5F10",
    "Microsoft.Messaging",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.MixedReality.Portal",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.MSPaint",
    "Microsoft.WindowsMaps",
    "Microsoft.MinecraftUWP",
    "Microsoft.People",
    "Microsoft.Wallet",
    "Microsoft.Print3D",
    "Microsoft.OneConnect",
    "Microsoft.MicrosoftSolitaireCollection",
    "microsoft.windowscommunicationsapps",
    "Microsoft.SkypeApp",
    "Microsoft.GroupMe10",
    "MSTeams",
    "Microsoft.Todos",
    "king.com.CandyCrushSaga",
    "king.com.CandyCrushSodaSaga",
    "ShazamEntertainmentLtd.Shazam",
    "Flipboard.Flipboard",
    "9E2F88E3.Twitter",
    "ClearChannelRadioDigital.iHeartRadio",
    "D5EA27B7.Duolingo-LearnLanguagesforFree",
    "AdobeSystemsIncorporated.AdobePhotoshopExpress",
    "PandoraMediaInc.29680B314EFC2",
    "46928bounde.EclipseManager",
    "MicrosoftCorporationII.MicrosoftFamily",
    "ActiproSoftwareLLC.562882FEEB491"
)

foreach ($pkg in $packages) {

        $app = Get-AppxPackage -Name $pkg -ErrorAction SilentlyContinue
        if ($app) {
            Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue
        }
}
'@

        Set-Content -Path $tempScript -Value $scriptContent -Encoding UTF8 -ErrorAction Stop
        Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$tempScript`"" -WindowStyle Hidden -wait
        [System.Windows.Forms.MessageBox]::Show("Debloat Terminé.", "Information", "OK", "Information")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Échec du débloat : $($_.Exception.Message)", "Erreur", "OK", "Error")
    } finally {
        $debloatButton.Enabled = $true
    }
})

    $optiY += 200

    # Bouton de mise à jour des applications
    $updateButton = New-Object Windows.Forms.Button
    $updateButton.Text = "Mettre à jour les applications"
    $updateButton.Width = 150
    $updateButton.Height = 40
    $updateButton.Location = New-Object Drawing.Point($optiX, $optiY)
    $tabOpti.Controls.Add($updateButton)
    $updateButton.Add_Click({
        $updateButton.Enabled = $false
        try {
        $UpdateAvailable = (Get-WinGetPackage | Where-Object IsUpdateAvailable).Id

        if ($UpdateAvailable.Count -gt 0) {
            foreach ($id in $UpdateAvailable) {
                $appName = $appNamesById[$id]
                Write-Host "Mise à jour de $appName ($id)..." -ForegroundColor Cyan
                $update = Update-WinGetPackage -Id $id -Mode Silent -ErrorAction Stop

                if ($update.Status -eq "Ok") {
                    Write-Host "Mise à jour de $appName ($id) réussie." -ForegroundColor Green
                } else {
                    Write-Host "Échec de mise à jour de $appName ($id) : $($update.Status) $($update.ExtendedErrorCode)" -ForegroundColor Red
                }
            }

            [System.Windows.Forms.MessageBox]::Show("Mise à jour terminée", "Succès", "OK", "Information")
        } else {
            Write-Host "Aucune mise à jour disponible." -ForegroundColor Cyan
            [System.Windows.Forms.MessageBox]::Show("Aucune mise à jour", "Succès", "OK", "Information")
        }} finally {
            $updateButton.Enabled = $true
        }
    })

    $optiY += 50
    # Bouton de mise a jour du windows store
    if (-not ($isServer)) {
    $updateStoreButton = New-Object Windows.Forms.Button
    $updateStoreButton.Text = "Vérifier les mises a jour du Microsoft Store"
    $updateStoreButton.Width = 150
    $updateStoreButton.Height = 40
    $updateStoreButton.Location = New-Object Drawing.Point($optiX, $optiY)
    $tabOpti.Controls.Add($updateStoreButton)
    $updateStoreButton.Add_Click({
        $updateStoreButton.Enabled = $false
        try {
            Write-Host "Vérification des mises a jour du Microsoft Store" -ForegroundColor Cyan
            Start-Process "ms-windows-store://downloadsandupdates" -ErrorAction Stop
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de la mise à jour du Microsoft Store : $_", "Erreur", "OK", "Error")
        } finally {
            $updateStoreButton.Enabled = $true
        }
    })

    }

    $optiY += 50

    # Bouton de mise à jour système
    $systemUpdateButton = New-Object Windows.Forms.Button
    $systemUpdateButton.Text = "Vérifier les mises à jour Windows"
    $systemUpdateButton.Width = 150
    $systemUpdateButton.Height = 40
    $systemUpdateButton.Location = New-Object Drawing.Point($optiX, $optiY)
    $tabOpti.Controls.Add($systemUpdateButton)
    $systemUpdateButton.Add_Click({
        $systemUpdateButton.Enabled = $false
        try {
            Write-Host "Vérification des mises à jour de Windows..." -ForegroundColor Cyan
            Start-Process "ms-settings:windowsupdate"
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Échec de la vérification des mises à jour de Windows : $_", "Erreur", "OK", "Error")
        }
        finally {
            $systemUpdateButton.Enabled = $true
        }
        })

    # Onglet Script
    $tabScript = New-Object Windows.Forms.TabPage
    $tabScript.Text = "Script Externe"
    $tabControl.TabPages.Add($tabScript)

    $scriptTextBox = New-Object Windows.Forms.TextBox
    $scriptTextBox.Multiline = $true
    $scriptTextBox.ScrollBars = "Vertical"
    $scriptTextBox.Font = New-Object Drawing.Font("Consolas", 10)
    $scriptTextBox.Location = New-Object Drawing.Point(0,0)
    $scriptTextBox.Size = New-Object Drawing.Size(780, 640)
    $scriptTextBox.Text = @"
Write-Host @'
 /\_/\  
( o.o ) 
 > ^ <
'@
Start-Sleep -Seconds 2
Write-Host "C'est pas un chat !"
Start-Sleep -Seconds 2
Write-Host "C'est une panthère !"
Start-Sleep -Seconds 2
"@
    $tabScript.Controls.Add($scriptTextBox)

    $scripty = 660

    # Inforamtion du script
    $scriptInfoLabel = New-Object Windows.Forms.Label
    $scriptInfoLabel.Text = "*Exécutez un script PowerShell externe pour configurer votre système."
    $scriptInfoLabel.Location = New-Object Drawing.Point(40, $scripty)
    $scriptInfoLabel.AutoSize = $true
    $tabScript.Controls.Add($scriptInfoLabel)

    # Bouton Importer
    $importScriptButton = New-Object Windows.Forms.Button
    $importScriptButton.Text = "Importer un script Powershell"
    $importScriptButton.Width = 150
    $importScriptButton.Height = 40
    $importScriptButton.Location = New-Object Drawing.Point(450,$scripty)
    $tabScript.Controls.Add($importScriptButton)
    $importScriptButton.Add_Click({
        $openDialog = New-Object Windows.Forms.OpenFileDialog
        $openDialog.Filter = "Fichiers PowerShell (*.ps1)|*.ps1"
        if ($openDialog.ShowDialog() -eq "OK") {
            $scriptTextBox.Text = Get-Content -Path $openDialog.FileName -Raw
        }
    })

    # Bouton Exécuter
    $runScriptButton = New-Object Windows.Forms.Button
    $runScriptButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $runScriptButton.Text = "Exécuter le script"
    $runScriptButton.Width = 150
    $runScriptButton.Height = 40
    $runScriptButton.Location = New-Object Drawing.Point(610,$scripty)
    $tabScript.Controls.Add($runScriptButton)
    $runScriptButton.Add_Click({
        $runScriptButton.Enabled = $false
        try {
            $tempScriptPath = [System.IO.Path]::Combine($env:TEMP, "script_zone.ps1")
            Set-Content -Path $tempScriptPath -Value $scriptTextBox.Text -Encoding UTF8 -ErrorAction Stop
            Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$tempScriptPath`"" -Wait
            [System.Windows.Forms.MessageBox]::Show("Script exécuté.", "Information", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Erreur lors de l'exécution : $_", "Erreur", "OK", "Error")
        } finally {
            $runScriptButton.Enabled = $true
        }
    })

    # Onglet Informations système
    $tabInfos = New-Object Windows.Forms.TabPage
    $tabInfos.Text = "Infos Système"
    $tabControl.TabPages.Add($tabInfos)

    # TextBox multi-ligne pour afficher les informations
    $infoTextBox = New-Object Windows.Forms.TextBox
    $infoTextBox.Multiline = $true
    $infoTextBox.ScrollBars = "Vertical"
    $infoTextBox.ReadOnly = $true
    $infoTextBox.Location = New-Object Drawing.Point(0,0)
    $infoTextBox.Size = New-Object Drawing.Size(780, 640)
    $infoTextBox.Font = New-Object Drawing.Font("Consolas", 9)
    $tabInfos.Controls.Add($infoTextBox)

    # Bouton "Exporter"
    $exportButton = New-Object Windows.Forms.Button
    $exportButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $exportButton.Text = "Exporter les informations"
    $exportButton.Width = 150
    $exportButton.Height = 40
    $exportButton.Location = New-Object Drawing.Point(610, 660)
    $tabInfos.Controls.Add($exportButton)

    # Fonction pour récupérer les informations système
    function Get-SystemInfoText {
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

    $info = @()
    $info += "=== Informations système ==="
    $info += "Nom de l'ordinateur : $($cs.Name)"
    $info += "Système : $($os.Caption) $($os.OSArchitecture)"
    $info += "Fabricant : $($cs.Manufacturer)"
    $info += "Modèle : $($cs.Model)"
    $info += "Processeur : $($cpu.Name)"
    $info += "Nombre de coeurs : $($cpu.NumberOfCores)"
    $info += "Mémoire RAM : {0:N0} Mo" -f ($cs.TotalPhysicalMemory / 1MB)
    $info += ""

    $info += "=== Sécurité ==="
    $firewallStatus = Get-NetFirewallProfile -All | Where-Object { $_.Enabled } | Select-Object -ExpandProperty Name
    if ($firewallStatus) {
        $info += "Pare-feu : Activé ($($firewallStatus -join ', '))"
    } else {
        $info += "Pare-feu : Désactivé"
    }
    $uacEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
    if ($uacEnabled -eq 1) { $info += "UAC : Activé" } else { $info += "UAC : Désactivé" }
    $rdpEnabled = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
    if ($rdpEnabled -eq 0) { $info += "Bureau à distance : Activé" } else { $info += "Bureau à distance : Désactivé" }
    $info += ""

    $info += "=== Disques ==="
    $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    foreach ($disk in $disks) {
        $info += "$($disk.DeviceID) : $([math]::Round($disk.FreeSpace/1GB,1)) Go libres / $([math]::Round($disk.Size/1GB,1)) Go"
    }
    $info += ""

    # Interfaces réseau détaillées
    $info += "=== Réseau ==="
    $adapters = Get-NetIPConfiguration | Where-Object { $_.IPv4Address -ne $null }
    foreach ($adapter in $adapters) {
        $info += "Interface : $($adapter.InterfaceAlias)"
        $info += " - IPv4 : $($adapter.IPv4Address.IPAddress)"
        $info += " - Masque : $(Convert-PrefixLengthToSubnetMask -PrefixLength $adapter.IPv4Address.PrefixLength)"
        $info += " - Passerelle : $($adapter.IPv4DefaultGateway.NextHop)"
        $dnsList = $adapter.DnsServer.ServerAddresses -join ", "
        $info += " - DNS : $dnsList"

        # Statut IPv6
		$ipv6Status = (Get-NetAdapterBinding -Name $adapter.InterfaceAlias -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue).Enabled
        if ($ipv6Status) {
			$info += " - IPv6 :Activé"
		} else {
			$info += " - IPv6 :Désactivé"
			}

        # Statut DHCP
        $dhcpStatus = (Get-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -ErrorAction SilentlyContinue).Dhcp
            if ($dhcpStatus) {
                $info += " - DHCP : Activé"
            } else {
                $info += " - DHCP : Désactivé"
            }

        $info += ""
    }

    # Rôles et fonctionnalités si serveur
    if ($isServer) {
        $info += "=== Rôles et fonctionnalités installés ==="
        try {
            $rolesAndFeatures = Get-WindowsFeature | Where-Object { $_.Installed }
            foreach ($feature in $rolesAndFeatures) {
                $info += "- $($feature.DisplayName)"
            }
        } catch {
            $info += "Erreur récupération rôles/fonctionnalités : $_"
        }
        $info += ""
    }
    # Applications installées
    try {
        $info += "=== Applications installées ==="
        $wingetApps = Get-WinGetPackage | Sort-Object Name
        foreach ($app in $wingetApps) {
            $info += "- $($app.Name) $($app.Version)"
        }
    } catch {
        $info += "Impossible de récupérer les applications via WinGet : $_"
    }

    return $info -join "`r`n"
}

# Remplir automatiquement à l’ouverture
$tabInfos.Add_Enter({
    $infoTextBox.Text = Get-SystemInfoText
})

# Fonction pour exporter vers un fichier
$exportButton.Add_Click({
    $saveDialog = New-Object Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Fichiers texte (*.txt)|*.txt"
    $saveDialog.FileName = ("infos - " + $env:COMPUTERNAME + ".txt")

    if ($saveDialog.ShowDialog() -eq "OK") {
            $infoTextBox.Text | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Fichier exporté", "Succès", "OK", "Information")

    }
})

# Onglet Copyright
$tabCopyright = New-Object Windows.Forms.TabPage
$tabCopyright.Text = "À propos"
$tabControl.TabPages.Add($tabCopyright)

# Texte d'information
$copyrightText = @"



Développé par : Kevin Gaonach
Version : 1.1.0.0
GitHub : https://github.com/kevin-gaonach/app-install






Onglets disponibles :

- Applications :
    Installez des applications via WinGet, avec la possibilité de mettre à jour les applications existantes.

- Configuration :
    Configurez les paramètres réseau, le nom de l'ordinateur et le domaine.

- Optimisations :
    Appliquez des optimisations système, nettoyez le disque et débloquez le système.

- Script Externe :
    Exécutez un script PowerShell personnalisé pour configurer votre système

- Infos Système :
    Affichez les informations système détaillées et exportez-les.

- À propos :
    Informations sur l'assistant et le projet GitHub.
"@

$aboutBox = New-Object Windows.Forms.TextBox
$aboutBox.Multiline = $true
$aboutBox.ReadOnly = $true
$aboutBox.Text = $copyrightText
$aboutBox.BorderStyle = "None"
$aboutBox.Font = New-Object Drawing.Font("Segoe UI", 10)
$aboutBox.Location = New-Object Drawing.Point(0, 0)
$aboutBox.Size = New-Object Drawing.Size(780, 640)
$tabCopyright.Controls.Add($aboutBox)

$githubButton = New-Object Windows.Forms.Button
$githubButton.Text = "Ouvrir le projet GitHub"
$githubButton.Location = New-Object Drawing.Point(610, 660)
$githubButton.Width = 150
$githubButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$githubButton.Height = 40
$githubButton.Add_Click({
    Start-Process "https://github.com/kevin-gaonach/app-install"
})
$tabCopyright.Controls.Add($githubButton)

    [void]$form.ShowDialog()
}

# Vérifie si le module powershell WinGet est déjà disponible
if (-not (Get-Module -ListAvailable -Name "Microsoft.WinGet.Client")) {
    Write-Host "Installation du module WinGet PowerShell..." -ForegroundColor Cyan
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Repair-WinGetPackageManager -AllUsers
    Write-Host "Installation de WinGet terminée." -ForegroundColor Green
}

    Import-Module Microsoft.WinGet.Client
    Write-Host "Chargement de l'assistant..." -ForegroundColor Cyan

Show-AppInstallerGUI