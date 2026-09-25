# =============================================================================
#  Global Agenda KSP - Launcher
# =============================================================================
#  Dependency-free GUI launcher: PowerShell + WinForms, both of which ship with
#  Windows. No exe to build, no Python, no pip, no SQLite driver.
#
#  Completion tracking reads out\completions.json, which the control server
#  regenerates whenever a mission ends (Database::ExportCompletionsJson). That
#  indirection exists because PowerShell cannot read SQLite without shipping an
#  extra package.
#
#  Class badges are drawn with GDI+ at runtime rather than using icon files,
#  emoji or symbol fonts: nothing to ship, and identical on every Windows
#  machine regardless of installed fonts.
#
#  Custom difficulty tiers (Rookie..Impossible) are not yet known to the
#  server, so the launcher records when each tier was selected in
#  was active at its timestamp.
#
#  When distributing this launcher, do not include Launcher-Settings.json,
#  out\completions.json - these are per-machine and not for distribution.
# =============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ScriptDir       = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LauncherDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$SettingsPath    = Join-Path $LauncherDir "Launcher-Settings.json"

$Difficulties = @("Rookie","Apprentice","Intermediate","Veteran","Master","Extreme","Insane","Impossible")

$DifficultyDescriptions = @{
    "Rookie"       = "For players unfamiliar with shooters"
    "Apprentice"   = "Good starting area for first timers that are comfortable with games"
    "Intermediate" = "Returning players looking to test the waters"
    "Veteran"      = "Skilled players looking for a challenge -- balancing was based from Veteran UMax"
    "Master"       = "Very skilled veterans looking for a bigger challenge"
    "Extreme"      = "UMax may be doable by the most skilled players"
    "Insane"       = "UMax may be doable by the most skilled players"
    "Impossible"   = "Med/High likely doable, Max/UMax may be impossible"
}


$TierScalars = @{
    "Rookie"       = 1.0
    "Apprentice"   = 1.35
    "Intermediate" = 1.7
    "Veteran"      = 2.0
    "Master"       = 2.2
    "Extreme"      = 2.5
    "Insane"       = 3.0
    "Impossible"   = 4.0
}

$GameDiffs = [ordered]@{
    1029 = "Medium"
    1030 = "High"
    1259 = "Max"
    1471 = "UMax"
}

# Class badge appearance. Two-letter codes keep the chips narrow enough that
# all four fit in a grid cell.
$ClassOrder  = @("Assault","Medic","Recon","Robotics")
$ClassCodes  = @{ "Assault" = "AS"; "Medic" = "ME"; "Recon" = "RE"; "Robotics" = "RO" }
$ClassColors = @{
    "Assault"  = [System.Drawing.Color]::FromArgb(198, 72, 66)
    "Medic"    = [System.Drawing.Color]::FromArgb(66, 166, 92)
    "Recon"    = [System.Drawing.Color]::FromArgb(155, 80, 200)
    "Robotics" = [System.Drawing.Color]::FromArgb(64, 156, 198)
}

# Ordered map list with display numbers.
$MapOrder = [ordered]@{
     1 = "1P_CPFactory01_P"
     2 = "1P_CPFactory02_P"
     3 = "1P_CPFactory03_P"
     4 = "1P_CPFactory04_P"
     5 = "1P_CPFactory05_P"
     6 = "1P_CPLab01_P"
     7 = "1P_CPLab02_P"
     8 = "1P_CPLab03"
     9 = "1P_CPLab04_P"
    10 = "1P_CPLab05_P"
    11 = "1P_CPMine01_P"
    12 = "1P_CPMine02_P"
    13 = "1P_CPMine03_P"
    14 = "1P_CPMine04_P"
    15 = "1P_CPMine05_P"
    16 = "1P_SDColony01_P"
    17 = "1P_SDColony02_P"
    18 = "1P_SDColony03_P"
    19 = "1p_SDColony04_P"
    20 = "1P_SDColony05_P"
    21 = "1P_SDColony06_P"
    22 = "1P_SDDweller01_P"
    23 = "1P_SDDweller02_P"
    24 = "1P_SDDweller03_P"
}
$MapNumberByName = @{}
foreach ($kvp in $MapOrder.GetEnumerator()) { $MapNumberByName[$kvp.Value] = $kvp.Key }

$MapNames = @{
    "1P_CPFactory01_P" = "Weapon Manufacturing Plant"
    "1P_CPFactory02_P" = "Android Assembly Plant"
    "1P_CPFactory03_P" = "Central Industrial Complex"
    "1P_CPFactory04_P" = "Recycling Plant 37"
    "1P_CPFactory05_P" = "Waste Management Center"
    "1P_CPLab01_P"     = "Sector 20 Agent Inception Center"
    "1P_CPLab02_P"     = "Remote Operations Control Center"
    "1P_CPLab03"       = "Embryonic Agent Testing Lab"
    "1P_CPLab04_P"     = "Advanced Weaponry Research Lab"
    "1P_CPLab05_P"     = "Bio-Tech Testing Facility"
    "1P_CPMine01_P"    = "Unobtanium Mine LV-426"
    "1P_CPMine02_P"    = "Mineral Extraction Site A-31"
    "1P_CPMine03_P"    = "Uranium Mining Complex"
    "1P_CPMine04_P"    = "Titanium Processing Site"
    "1P_CPMine05_P"    = "Alumina Mine 1138"
    "1P_SDColony01_P"  = "Recursive Colony Node 1393"
    "1P_SDColony02_P"  = "Bolonov's Entourage"
    "1P_SDColony03_P"  = "Recursive Colony Nest"
    "1p_SDColony04_P"  = "Recursive Communications"
    "1P_SDColony05_P"  = "Terminus Water Station"
    "1P_SDColony06_P"  = "28 Nights Later"
    "1P_SDDweller01_P" = "Canyon Encampment"
    "1P_SDDweller02_P" = "Shifting Sands"
    "1P_SDDweller03_P" = "Dweller Hideout"
    "Dome3_VR_Arena_P" = "VR Arena (home)"
}

function Get-MapDisplay($mapName) {
    if (-not $mapName) { return "" }
    if ($MapNames.ContainsKey($mapName)) { return "$mapName - $($MapNames[$mapName])" }
    return $mapName
}

# --- Path discovery ----------------------------------------------------------
function Test-RepoRoot($path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    if (-not (Test-Path $path)) { return $false }
    return (Test-Path (Join-Path $path "windows-server-menu.bat")) -or
           (Test-Path (Join-Path $path "out\control-server.exe"))
}

function Find-RepoRoot {
    $dir = $ScriptDir
    for ($i = 0; $i -lt 6 -and $dir; $i++) {
        if (Test-RepoRoot $dir) { return $dir }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $sibling = Get-ChildItem -Path $ScriptDir -Directory -ErrorAction SilentlyContinue |
               Where-Object { Test-RepoRoot $_.FullName } | Select-Object -First 1
    if ($sibling) { return $sibling.FullName }
    return $ScriptDir
}

function Find-ClientExe($repoRoot) {
    return ""
}

# --- Settings ----------------------------------------------------------------
$DefaultSettings = @{
    RepoRoot        = $ScriptDir
    ClientExePath   = ""
    Difficulty      = "Apprentice"
    ShowGameConsole = $false
    AllowDupeLogins = $false
    ClientLog       = $false
    NoStartupMovies = $true
    LastTabIndex    = 0
    Channels        = @()
}

function Load-Settings {
    $s = @{}
    foreach ($k in $DefaultSettings.Keys) { $s[$k] = $DefaultSettings[$k] }
    if (Test-Path $SettingsPath) {
        try {
            $raw = Get-Content $SettingsPath -Raw | ConvertFrom-Json
            foreach ($k in $DefaultSettings.Keys) { if ($null -ne $raw.$k) { $s[$k] = $raw.$k } }
            $s.Channels = @($s.Channels | ForEach-Object { [string]$_ })
        } catch { }
    }
    if (-not (Test-RepoRoot $s.RepoRoot))            { $s.RepoRoot      = Find-RepoRoot }
    if (-not $s.ClientExePath -or -not (Test-Path ([string]$s.ClientExePath))) { $s.ClientExePath = Find-ClientExe $s.RepoRoot }
    return $s
}

function Save-Settings($s) {
    try { $s | ConvertTo-Json -Depth 4 | Set-Content -Path $SettingsPath -Encoding UTF8 } catch { }
}

$Settings = Load-Settings

function Get-ServerConfigPath { param($root) if ($root) { Join-Path $root "out\control-server.json" } else { "" } }
function Get-ServerExePath    { param($root) if ($root) { Join-Path $root "out\control-server.exe"  } else { "" } }
function Get-LogDirPath       { param($root) if ($root) { Join-Path $root "out\logs"               } else { "" } }
function Get-CompletionsPath  { param($root) if ($root) { Join-Path $root "out\completions.json"   } else { "" } }




$script:ServerProcess = $null
$script:CurrentMap    = ""

# --- Form --------------------------------------------------------------------
$form               = New-Object System.Windows.Forms.Form
$form.Text          = "Global Agenda KSP - Launcher"
$form.Size          = New-Object System.Drawing.Size(1100, 840)
$form.StartPosition = "CenterScreen"
$form.BackColor     = [System.Drawing.Color]::FromArgb(32, 34, 38)
$form.ForeColor     = [System.Drawing.Color]::White
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9)

function New-Label($text, $x, $y, $w, $h, $bold = $false) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    $l.ForeColor = [System.Drawing.Color]::White
    if ($bold) { $l.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold) }
    return $l
}

function New-TextBox($x, $y, $w, $text) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, 24)
    $t.Text = [string]$text
    $t.BackColor = [System.Drawing.Color]::FromArgb(46, 49, 54)
    $t.ForeColor = [System.Drawing.Color]::White
    $t.BorderStyle = "FixedSingle"
    return $t
}

function New-Check($text, $x, $y, $w, $checked) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $text
    $c.Location = New-Object System.Drawing.Point($x, $y)
    $c.Size = New-Object System.Drawing.Size($w, 22)
    $c.Checked = [bool]$checked
    $c.ForeColor = [System.Drawing.Color]::White
    return $c
}

function New-Button($text, $x, $y, $w, $h, $accent = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = "Flat"
    $b.ForeColor = [System.Drawing.Color]::White
    if ($accent) { $b.BackColor = [System.Drawing.Color]::FromArgb(0, 110, 60) }
    else         { $b.BackColor = [System.Drawing.Color]::FromArgb(58, 62, 68) }
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(90, 95, 102)
    return $b
}

function Browse-Folder($title, $current) {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = $title
    if ($current -and (Test-Path $current)) { $dlg.SelectedPath = $current }
    if ($dlg.ShowDialog() -eq "OK") { return $dlg.SelectedPath }
    return $null
}

# --- Top-level tabs ----------------------------------------------------------
$tabs          = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(8, 8)
$tabs.Size     = New-Object System.Drawing.Size(1068, 718)
$form.Controls.Add($tabs)

# Tab 1: Launcher
$tabMain           = New-Object System.Windows.Forms.TabPage
$tabMain.Text      = "Launcher"
$tabMain.BackColor = [System.Drawing.Color]::FromArgb(32, 34, 38)
$tabs.TabPages.Add($tabMain)

# Tab 2: Advanced
$tabAdvanced           = New-Object System.Windows.Forms.TabPage
$tabAdvanced.Text      = "Advanced"
$tabAdvanced.BackColor = [System.Drawing.Color]::FromArgb(32, 34, 38)
$tabs.TabPages.Add($tabAdvanced)

# Tab 3: User Guide
$tabHelp           = New-Object System.Windows.Forms.TabPage
$tabHelp.Text      = "User Guide"
$tabHelp.BackColor = [System.Drawing.Color]::FromArgb(32, 34, 38)
$tabs.TabPages.Add($tabHelp)

# Tab 4: Gameplay Tips
$tabTips           = New-Object System.Windows.Forms.TabPage
$tabTips.Text      = "Gameplay Tips"
$tabTips.BackColor = [System.Drawing.Color]::FromArgb(32, 34, 38)
$tabs.TabPages.Add($tabTips)

# Tab 5: Patch Notes
$tabPatch          = New-Object System.Windows.Forms.TabPage
$tabPatch.Text     = "Patch Notes"
$tabPatch.BackColor = [System.Drawing.Color]::FromArgb(32, 34, 38)
$tabs.TabPages.Add($tabPatch)

# Tab 6: Completions
$tabDone           = New-Object System.Windows.Forms.TabPage
$tabDone.Text      = "Completions"
$tabDone.BackColor = [System.Drawing.Color]::FromArgb(32, 34, 38)
$tabs.TabPages.Add($tabDone)

# =============================== LAUNCHER TAB ================================

$tabMain.Controls.Add((New-Label "Server folder (base repo folder, like cw-globalagenda-ksp)" 16 10 400 18 $true))
$txtRepo = New-TextBox 16 32 830 $Settings.RepoRoot
$tabMain.Controls.Add($txtRepo)

$tabMain.Controls.Add((New-Label "Game executable (GlobalAgenda.exe, usually in Steam folder)" 16 66 500 18 $true))
$txtExe = New-TextBox 16 88 830 $Settings.ClientExePath
$tabMain.Controls.Add($txtExe)

$btnBrowseRepo = New-Button "Browse..." 854 31 90 26
$btnBrowseRepo.Add_Click({
    $p = Browse-Folder "Select the Server folder (base repo folder, like cw-globalagenda-ksp)" $txtRepo.Text
    if ($p) {
        $txtRepo.Text = $p
        if (-not $txtExe.Text -or -not (Test-Path $txtExe.Text)) {
            $found = Find-ClientExe $p
            if ($found) { $txtExe.Text = $found }
        }
    }
})
$tabMain.Controls.Add($btnBrowseRepo)

$btnBrowseExe = New-Button "Browse..." 854 87 90 26
$btnBrowseExe.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "GlobalAgenda.exe|GlobalAgenda.exe|Executables (*.exe)|*.exe"
    $dlg.Title  = "Select GlobalAgenda.exe"
    if ($txtExe.Text -and (Test-Path $txtExe.Text)) { $dlg.InitialDirectory = Split-Path -Parent $txtExe.Text }
    if ($dlg.ShowDialog() -eq "OK") { $txtExe.Text = $dlg.FileName }
})
$tabMain.Controls.Add($btnBrowseExe)

# Difficulty group -- 8 difficulties, height 245
$grpDiff           = New-Object System.Windows.Forms.GroupBox
$grpDiff.Text      = "Difficulty"
$grpDiff.Location  = New-Object System.Drawing.Point(16, 124)
$grpDiff.Size      = New-Object System.Drawing.Size(240, 248)
$grpDiff.ForeColor = [System.Drawing.Color]::White
$tabMain.Controls.Add($grpDiff)

$tipDiff   = New-Object System.Windows.Forms.ToolTip
$radioDiffs = @()
$dy = 22
foreach ($d in $Difficulties) {
    $r = New-Object System.Windows.Forms.RadioButton
    $r.Text = $d
    $r.Location = New-Object System.Drawing.Point(14, $dy)
    $r.Size = New-Object System.Drawing.Size(200, 22)
    $r.ForeColor = [System.Drawing.Color]::White
    if ($d -eq $Settings.Difficulty) { $r.Checked = $true }
    $tipDiff.SetToolTip($r, $DifficultyDescriptions[$d])
    $grpDiff.Controls.Add($r)
    $radioDiffs += $r
    $dy += 25
}
if (-not ($radioDiffs | Where-Object { $_.Checked })) {
    ($radioDiffs | Where-Object { $_.Text -eq "Veteran" }).Checked = $true
}

$grpClient           = New-Object System.Windows.Forms.GroupBox
$grpClient.Text      = "Client options"
$grpClient.Location  = New-Object System.Drawing.Point(270, 124)
$grpClient.Size      = New-Object System.Drawing.Size(300, 200)
$grpClient.ForeColor = [System.Drawing.Color]::White
$tabMain.Controls.Add($grpClient)

$chkClientLog = New-Check "Write client log (-log)" 14 74 260 $Settings.ClientLog
$chkNoMovies  = New-Check "Skip startup movies (-nostartupmovies)" 14 99 280 $Settings.NoStartupMovies

$lblFixed1 = New-Label "-host=localhost      (always on)" 16 22 270 18
$lblFixed1.ForeColor = [System.Drawing.Color]::FromArgb(150, 155, 160)
$grpClient.Controls.Add($lblFixed1)

$lblFixed2 = New-Label "-seekfreeloading     (always on)" 16 44 270 18
$lblFixed2.ForeColor = [System.Drawing.Color]::FromArgb(150, 155, 160)
$grpClient.Controls.Add($lblFixed2)

$grpClient.Controls.AddRange(@($chkClientLog, $chkNoMovies))

$grpClient.Controls.Add((New-Label "Additional launch options" 14 128 220 18))
$txtExtraArgs = New-TextBox 14 148 270 $Settings.ExtraArgs
$grpClient.Controls.Add($txtExtraArgs)

# --- Link Server to Game ---------------------------------------------------
$grpLink           = New-Object System.Windows.Forms.GroupBox
$grpLink.Text      = "Link Server to Game"
$grpLink.Location  = New-Object System.Drawing.Point(582, 124)
$grpLink.Size      = New-Object System.Drawing.Size(462, 248)
$grpLink.ForeColor = [System.Drawing.Color]::White
$tabMain.Controls.Add($grpLink)

$lblLinkStatus = New-Object System.Windows.Forms.Label
$lblLinkStatus.Location = New-Object System.Drawing.Point(14, 26)
$lblLinkStatus.Size     = New-Object System.Drawing.Size(430, 22)
$lblLinkStatus.ForeColor = [System.Drawing.Color]::FromArgb(210, 90, 90)
$lblLinkStatus.Font     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblLinkStatus.Text     = "● Not linked"
$grpLink.Controls.Add($lblLinkStatus)

$lblLinkDetail = New-Object System.Windows.Forms.Label
$lblLinkDetail.Location  = New-Object System.Drawing.Point(14, 52)
$lblLinkDetail.Size      = New-Object System.Drawing.Size(430, 40)
$lblLinkDetail.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)
$lblLinkDetail.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblLinkDetail.Text      = ""
$grpLink.Controls.Add($lblLinkDetail)

$lblLinkNote = New-Object System.Windows.Forms.Label
$lblLinkNote.Location  = New-Object System.Drawing.Point(14, 98)
$lblLinkNote.Size      = New-Object System.Drawing.Size(430, 60)
$lblLinkNote.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
$lblLinkNote.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblLinkNote.Text      = "Links the server to your game install so missions can spawn.`r`nSet the Game executable path above, then click Link."
$grpLink.Controls.Add($lblLinkNote)

$btnLink = New-Button "Link Server to Game" 14 166 240 36 $true
$btnLink.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grpLink.Controls.Add($btnLink)

$btnCheckLink = New-Button "Check" 262 166 80 36
$grpLink.Controls.Add($btnCheckLink)



# Server output -- moved up since Advanced is now its own tab
$tabMain.Controls.Add((New-Label "Server output" 16 384 200 18 $true))
$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Location   = New-Object System.Drawing.Point(16, 406)
$txtOut.Size       = New-Object System.Drawing.Size(1028, 288)
$txtOut.Multiline  = $true
$txtOut.ScrollBars = "Vertical"
$txtOut.ReadOnly   = $true
$txtOut.BackColor  = [System.Drawing.Color]::FromArgb(20, 22, 25)
$txtOut.ForeColor  = [System.Drawing.Color]::FromArgb(120, 220, 140)
$txtOut.Font       = New-Object System.Drawing.Font("Consolas", 9)
$tabMain.Controls.Add($txtOut)

# =============================== ADVANCED TAB ================================

$tabAdvanced.Controls.Add((New-Label "Server & Debug Options" 16 10 400 20 $true))

$chkShowConsole = New-Check "Show game instance console"     16 40 300 $Settings.ShowGameConsole
$chkDupeLogins  = New-Check "Allow duplicate account logins" 16 66 300 $Settings.AllowDupeLogins
$tabAdvanced.Controls.AddRange(@($chkShowConsole, $chkDupeLogins))

$tabAdvanced.Controls.Add((New-Label "Log Channels (debugging)" 16 100 260 18 $true))

$allChannels = @(
    "tgbotfactory","debug","pet_spawn","chat-command","db","skills","soi","flying","factory-map","gametimer","deployable_props",
    "beacon","deploy_phase","dbperf","matchmaking","tcp","ipc","loot","explode-on-death"
)
$chkChannels = @{}
$cx = 16; $cy = 128; $col = 0
foreach ($ch in $allChannels) {
    $c = New-Check $ch $cx $cy 190 ($Settings.Channels -contains $ch)
    $tabAdvanced.Controls.Add($c)
    $chkChannels[$ch] = $c
    $cy += 26
    if ($cy -gt 400 -and $col -eq 0) { $col = 1; $cx = 220; $cy = 128 }
    elseif ($cy -gt 400 -and $col -eq 1) { $col = 2; $cx = 424; $cy = 128 }
}

# =============================== GAME HELP TAB ===============================

# User Guide text
$helpText = @'
FOR ANY LOGIN ISSUE just stop the server and start it again.  Likely a stale session that did not close properly.

QUEUEING MISSIONS
You can queue four difficulties in-game: MISSIONS (M) > TEAM (yes use the Team Queue) > Medium, High, Max, UMax
Medium is the easiest, then High, then Max, and then UMax (Ultra Max).  Enemies will vary between those difficulties.

KEYBINDS
Be sure to change your keybinds to be more usable.  Don't forget crouch!

CLASSES AND DIFFICULTY
Do not start at Veteran or higher if you are new.  This game is meant to be hard at and past that difficulty.

QUEUEING A SPECIFIC MISSION
You can queue a specific mission (instead of it being random) by typing in-game: -mission max 20
Refer to the completions page for mission number.  Can also type -mission 20 max (ordering doesn't matter)
Also -mi works for shorthand: -mi 20 max (or -mi max 20)
To cancel your forced queue, type -mission cancel (or -mi cancel)

DIFFICULTY TIERS (this launcher)
  Rookie       - For players unfamiliar with shooters
  Apprentice   - Good starting area for first timers that are comfortable with games
  Intermediate - Returning players looking to test the waters
  Veteran      - Skilled players looking for a challenge (balancing based from Veteran UMax)
  Master       - Very skilled veterans looking for a bigger challenge
  Extreme      - UMax may be doable by the most skilled players
  Insane       - UMax may be doable by the most skilled players
  Impossible   - Med/High likely doable, Max/UMax may be impossible
'@

$rtbHelp = New-Object System.Windows.Forms.RichTextBox
$rtbHelp.Location   = New-Object System.Drawing.Point(16, 16)
$rtbHelp.Size       = New-Object System.Drawing.Size(1028, 660)
$rtbHelp.ReadOnly   = $true
$rtbHelp.BackColor  = [System.Drawing.Color]::FromArgb(28, 30, 34)
$rtbHelp.ForeColor  = [System.Drawing.Color]::FromArgb(220, 220, 220)
$rtbHelp.Font       = New-Object System.Drawing.Font("Segoe UI", 10)
$rtbHelp.BorderStyle = "None"
$rtbHelp.Text       = $helpText
$rtbHelp.ScrollBars = "Vertical"
$tabHelp.Controls.Add($rtbHelp)

# Gameplay Tips text
$tipsText = @'
SKILLS (TALENTS)
Pick your skills (talents).  These enable different playstyles, and some missions may require talent changes.

ARMOR
Equip Armor.  You'll find ranged damage protection likely the most useful.

DEVICES (WEAPONS/ABILITIES)
Try different devices and find something that works.  Not everything will be useful in this solo mode.

BOSS ROOM ACCESS
You must defeat 90% of the enemies in the mission to access the boss room.
Bot deaths from any source count for completion percentages.

BOSS ROOM TIMER
Upon entering the boss room you get 4 minutes minimum on timer.

JETPACKS
Some Jetpacks can be used with other weapons equipped, and this is recommended.
'@

$rtbTips = New-Object System.Windows.Forms.RichTextBox
$rtbTips.Location   = New-Object System.Drawing.Point(16, 16)
$rtbTips.Size       = New-Object System.Drawing.Size(1028, 660)
$rtbTips.ReadOnly   = $true
$rtbTips.BackColor  = [System.Drawing.Color]::FromArgb(28, 30, 34)
$rtbTips.ForeColor  = [System.Drawing.Color]::FromArgb(220, 220, 220)
$rtbTips.Font       = New-Object System.Drawing.Font("Segoe UI", 10)
$rtbTips.BorderStyle = "None"
$rtbTips.Text       = $tipsText
$rtbTips.ScrollBars = "Vertical"
$tabTips.Controls.Add($rtbTips)

# Patch Notes text
$patchText = @'
CW Global Agenda KSP Version 1.0.0


SOLO BALANCE CHANGES

Doubled energy regen all classes from 18 to 36 (makes up for lack of other class buffs, has WAY better game feel)

REST device (self heal) is 5 seconds instead of 10

Nerfed alchemist base aoe heal value by half, and regeneration self heal is 5 sec instead of 15 (same hp heal)

Nerfed channeled heals (Techro, Maintenance Drone, etc)

Regeneration is active on every respawn (20hp/sec heal, makes game feel much better to play, not waiting on REST)

Extensive enemy HP tuning for each difficulty, and numerous tweaks to spawns

Doubled HP on all Robo turrets and they start building at 50% hp (no more instagib) [still max 1 turret on ground]

Doubled HP on all Robo drones, and removed one at a time limit for drones (max 3)

Blocked boss entry room until 90% of enemies eliminated in mission


GENERAL FIXES

Removed Support Destroyer from boss adds spawns, as explosion animation is not consistent [at least temporarily]

Removed 28 Nights Later map from pool as there is no current boss spawn [at least temporarily]

Removed Minion Sentinel death animation (shrunk it extremely small), was ragdolling very bad for several seconds [at least temporarily]

Colony Sentry removed as it's not doing anything at the moment [at least temporarily]

1P_SDColony04_P - Recursive Communications - removed adds during boss encounter back room, as they don't move out of room [at least temporarily]

Disabled Dweller EMP Field Generators, as they are simply just annoying.
'@

$rtbPatch = New-Object System.Windows.Forms.RichTextBox
$rtbPatch.Location   = New-Object System.Drawing.Point(16, 16)
$rtbPatch.Size       = New-Object System.Drawing.Size(1028, 660)
$rtbPatch.ReadOnly   = $true
$rtbPatch.BackColor  = [System.Drawing.Color]::FromArgb(28, 30, 34)
$rtbPatch.ForeColor  = [System.Drawing.Color]::FromArgb(220, 220, 220)
$rtbPatch.Font       = New-Object System.Drawing.Font("Segoe UI", 10)
$rtbPatch.BorderStyle = "None"
$rtbPatch.Text       = $patchText
$rtbPatch.ScrollBars = "Vertical"
$tabPatch.Controls.Add($rtbPatch)

# =============================== COMPLETIONS TAB =============================

$tabDone.Controls.Add((New-Label "Account" 16 14 60 20))
$cboAccount = New-Object System.Windows.Forms.ComboBox
$cboAccount.Location      = New-Object System.Drawing.Point(80, 12)
$cboAccount.Size          = New-Object System.Drawing.Size(200, 24)
$cboAccount.DropDownStyle = "DropDownList"
$cboAccount.BackColor     = [System.Drawing.Color]::FromArgb(46, 49, 54)
$cboAccount.ForeColor     = [System.Drawing.Color]::White
$tabDone.Controls.Add($cboAccount)

$btnRefreshDone = New-Button "Refresh" 292 11 90 26
$tabDone.Controls.Add($btnRefreshDone)

$lblDoneInfo = New-Label "" 392 16 210 18
$lblDoneInfo.ForeColor = [System.Drawing.Color]::FromArgb(190, 190, 190)
$tabDone.Controls.Add($lblDoneInfo)

$chkClasses = @{}

$chkClsAssault           = New-Object System.Windows.Forms.CheckBox
$chkClsAssault.Text      = "AS Assault"
$chkClsAssault.Location  = New-Object System.Drawing.Point(660, 14)
$chkClsAssault.Size      = New-Object System.Drawing.Size(96, 22)
$chkClsAssault.Checked   = $true
$chkClsAssault.ForeColor = $ClassColors["Assault"]
$chkClsAssault.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabDone.Controls.Add($chkClsAssault)
$chkClasses["Assault"] = $chkClsAssault

$chkClsMedic             = New-Object System.Windows.Forms.CheckBox
$chkClsMedic.Text        = "ME Medic"
$chkClsMedic.Location    = New-Object System.Drawing.Point(756, 14)
$chkClsMedic.Size        = New-Object System.Drawing.Size(90, 22)
$chkClsMedic.Checked     = $true
$chkClsMedic.ForeColor   = $ClassColors["Medic"]
$chkClsMedic.Font        = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabDone.Controls.Add($chkClsMedic)
$chkClasses["Medic"] = $chkClsMedic

$chkClsRecon             = New-Object System.Windows.Forms.CheckBox
$chkClsRecon.Text        = "RE Recon"
$chkClsRecon.Location    = New-Object System.Drawing.Point(846, 14)
$chkClsRecon.Size        = New-Object System.Drawing.Size(90, 22)
$chkClsRecon.Checked     = $true
$chkClsRecon.ForeColor   = $ClassColors["Recon"]
$chkClsRecon.Font        = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabDone.Controls.Add($chkClsRecon)
$chkClasses["Recon"] = $chkClsRecon

$chkClsRobotics          = New-Object System.Windows.Forms.CheckBox
$chkClsRobotics.Text     = "RO Robotics"
$chkClsRobotics.Location = New-Object System.Drawing.Point(936, 14)
$chkClsRobotics.Size     = New-Object System.Drawing.Size(104, 22)
$chkClsRobotics.Checked  = $true
$chkClsRobotics.ForeColor= $ClassColors["Robotics"]
$chkClsRobotics.Font     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabDone.Controls.Add($chkClsRobotics)
$chkClasses["Robotics"] = $chkClsRobotics

$tabsDone          = New-Object System.Windows.Forms.TabControl
$tabsDone.Location = New-Object System.Drawing.Point(12, 48)
$tabsDone.Size     = New-Object System.Drawing.Size(1036, 588)
$tabDone.Controls.Add($tabsDone)

$lblMapRegions = New-Label "1-15: Commonwealth   |   16-24: Sonoran" 12 670 400 18
$lblMapRegions.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$tabDone.Controls.Add($lblMapRegions)

# --- Badge drawing -----------------------------------------------------------
$script:BadgeFont = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)

function Draw-ClassBadges($g, $bounds, $text) {
    $done = if ($text) { @($text -split ',\s*' | Where-Object { $_ }) } else { @() }
    $slotW  = 32
    $badgeW = 28
    $h = 16
    $y = $bounds.Y + [int](($bounds.Height - $h) / 2)
    $x = $bounds.X + 4
    foreach ($cls in $ClassOrder) {
        if ($done -contains $cls) {
            $rect  = New-Object System.Drawing.Rectangle($x, $y, $badgeW, $h)
            $brush = New-Object System.Drawing.SolidBrush($ClassColors[$cls])
            $g.FillRectangle($brush, $rect)
            $brush.Dispose()
            $fmt = New-Object System.Drawing.StringFormat
            $fmt.Alignment     = [System.Drawing.StringAlignment]::Center
            $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
            $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $g.DrawString($ClassCodes[$cls], $script:BadgeFont, $white, [System.Drawing.RectangleF]$rect, $fmt)
            $white.Dispose()
            $fmt.Dispose()
        }
        $x += $slotW
    }
}

$doneViews = @("Game Difficulties") + $Difficulties
$doneLists = @{}

foreach ($v in $doneViews) {
    $page           = New-Object System.Windows.Forms.TabPage
    $page.Text      = $v
    $page.BackColor = [System.Drawing.Color]::FromArgb(32, 34, 38)
    $tabsDone.TabPages.Add($page)

    $lv               = New-Object System.Windows.Forms.ListView
    $lv.Location      = New-Object System.Drawing.Point(8, 8)
    $lv.Size          = New-Object System.Drawing.Size(1012, 570)
    $lv.View          = "Details"
    $lv.FullRowSelect = $true
    $lv.GridLines     = $true
    $lv.BackColor     = [System.Drawing.Color]::FromArgb(24, 26, 29)
    $lv.ForeColor     = [System.Drawing.Color]::White
    $lv.OwnerDraw     = $true
    [void]$lv.Columns.Add("#", 44)
    [void]$lv.Columns.Add("Map", 344)
    foreach ($dn in $GameDiffs.Values) { [void]$lv.Columns.Add($dn, 152) }

    $lv.Add_DrawColumnHeader({ param($s, $e) $e.DrawDefault = $true })
    $lv.Add_DrawItem({ param($s, $e) })
    $lv.Add_DrawSubItem({
        param($s, $e)
        $bg = New-Object System.Drawing.SolidBrush($s.BackColor)
        $e.Graphics.FillRectangle($bg, $e.Bounds)
        $bg.Dispose()
        $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(52, 55, 60))
        $e.Graphics.DrawLine($gridPen, $e.Bounds.Left, $e.Bounds.Bottom-1, $e.Bounds.Right, $e.Bounds.Bottom-1)
        $gridPen.Dispose()
        if ($e.ColumnIndex -le 1) {
            $fg = New-Object System.Drawing.SolidBrush($e.Item.ForeColor)
            $fmt = New-Object System.Drawing.StringFormat
            $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
            $fmt.Trimming      = [System.Drawing.StringTrimming]::EllipsisCharacter
            $fmt.FormatFlags   = [System.Drawing.StringFormatFlags]::NoWrap
            $r = New-Object System.Drawing.RectangleF(
                    ($e.Bounds.X + 4), $e.Bounds.Y, ($e.Bounds.Width - 8), $e.Bounds.Height)
            $e.Graphics.DrawString($e.SubItem.Text, $s.Font, $fg, $r, $fmt)
            $fmt.Dispose(); $fg.Dispose()
        } else {
            Draw-ClassBadges $e.Graphics $e.Bounds $e.SubItem.Text
        }
    })

    $page.Controls.Add($lv)
    $doneLists[$v] = $lv
}

function Load-Completions {
    $path = Get-CompletionsPath $txtRepo.Text
    if (-not $path -or -not (Test-Path $path)) {
        $lblDoneInfo.Text = "No completions.json yet."
        foreach ($lv in $doneLists.Values) { $lv.Items.Clear() }
        $cboAccount.Items.Clear()
        return
    }
    try { $data = Get-Content $path -Raw | ConvertFrom-Json }
    catch { $lblDoneInfo.Text = "completions.json unreadable."; return }

    $all = @($data.completions)
    if ($all.Count -eq 0) {
        $lblDoneInfo.Text = "No successful missions yet."
        foreach ($lv in $doneLists.Values) { $lv.Items.Clear() }
        return
    }

    $accounts = @($all | ForEach-Object { $_.players } | ForEach-Object { $_.account } | Sort-Object -Unique)
    $prev = $cboAccount.SelectedItem
    $cboAccount.Items.Clear()
    [void]$cboAccount.Items.Add("(all accounts)")
    foreach ($a in $accounts) { [void]$cboAccount.Items.Add($a) }
    if ($prev -and $cboAccount.Items.Contains($prev)) { $cboAccount.SelectedItem = $prev }
    else { $cboAccount.SelectedIndex = 0 }

    $lblDoneInfo.Text = "$($all.Count) successful mission(s)."
    Render-Completions $all
}

function Render-Completions($all) {
    $acct = $cboAccount.SelectedItem
    $activeClasses = @($ClassOrder | Where-Object { $chkClasses[$_].Checked })

    foreach ($view in $doneViews) {
        $lv = $doneLists[$view]
        $lv.BeginUpdate()
        $lv.Items.Clear()

        $grid = @{}
        foreach ($c in $all) {
            if ($view -ne "Game Difficulties") {
                $cTier = if ($c.PSObject.Properties['tier']) { $c.tier } else { 'Veteran' }
                if ($cTier -ne $view) { continue }
            }
            $diffId = [int]$c.difficulty
            if (-not $GameDiffs.Contains($diffId)) { continue }
            foreach ($p in $c.players) {
                if ($acct -and $acct -ne "(all accounts)" -and $p.account -ne $acct) { continue }
                if ($activeClasses -notcontains $p.class) { continue }
                if (-not $grid.ContainsKey($c.map)) { $grid[$c.map] = @{} }
                if (-not $grid[$c.map].ContainsKey($diffId)) { $grid[$c.map][$diffId] = @{} }
                $grid[$c.map][$diffId][$p.class] = $true
            }
        }

        foreach ($kvp in $MapOrder.GetEnumerator()) {
            $num     = $kvp.Key
            $mapName = $kvp.Value
            $numStr  = "$num"
            $item    = New-Object System.Windows.Forms.ListViewItem($numStr)
            $disp    = Get-MapDisplay $mapName
            if ($mapName -eq "1P_CPFactory03_P" -or $mapName -eq "1P_CPFactory04_P") {
                $disp = "$disp (DLC)"
            }
            if ($mapName -eq "1P_SDColony06_P") {
                $disp = "$disp (disabled)"
            }
            [void]$item.SubItems.Add($disp)
            foreach ($diffId in $GameDiffs.Keys) {
                $cell = ""
                if ($grid.ContainsKey($mapName) -and $grid[$mapName].ContainsKey($diffId)) {
                    $cell = (($ClassOrder | Where-Object { $grid[$mapName][$diffId].ContainsKey($_) }) -join ", ")
                }
                [void]$item.SubItems.Add($cell)
            }
            $item.ForeColor = [System.Drawing.Color]::White
            [void]$lv.Items.Add($item)
        }
        $lv.EndUpdate()
    }
}

function Refresh-CompletionsView {
    $path = Get-CompletionsPath $txtRepo.Text
    if ($path -and (Test-Path $path)) {
        try { Render-Completions @((Get-Content $path -Raw | ConvertFrom-Json).completions) } catch { }
    }
}

$btnRefreshDone.Add_Click({ Load-Completions })
$cboAccount.Add_SelectedIndexChanged({ Refresh-CompletionsView })
foreach ($cls in $ClassOrder) { $chkClasses[$cls].Add_CheckedChanged({ Refresh-CompletionsView }) }

$tabs.Add_SelectedIndexChanged({
    if ($tabs.SelectedTab -eq $tabDone) {
        Load-Completions
        $want = Get-SelectedDifficulty
        foreach ($p in $tabsDone.TabPages) { if ($p.Text -eq $want) { $tabsDone.SelectedTab = $p; break } }
    }
})


# --- Link functions ----------------------------------------------------------
function Get-LinkedGamePath {
    $repo = $txtRepo.Text
    if (-not $repo) { return "" }
    $detail = Join-Path $repo "out\client\.linked_from"
    if (Test-Path $detail) { return (Get-Content $detail -Raw).Trim() }
    return ""
}

function Get-LinkState {
    $repo    = $txtRepo.Text
    $gameExe = $txtExe.Text
    if (-not $repo) { return "none" }
    $clientExe = Join-Path $repo "out\client\Binaries\GlobalAgenda.exe"
    if (-not (Test-Path $clientExe)) { return "none" }
    $linkedFrom = Get-LinkedGamePath
    if ($linkedFrom -and $gameExe -and ($linkedFrom -ine $gameExe)) { return "mismatch" }
    return "linked"
}

function Update-LinkStatus {
    $state = Get-LinkState
    switch ($state) {
        "linked" {
            $lblLinkStatus.Text      = "[Linked]"
            $lblLinkStatus.ForeColor = [System.Drawing.Color]::FromArgb(90, 210, 120)
            $src = Get-LinkedGamePath
            $lblLinkDetail.Text = if ($src) { "Linked to: $src" } else { "out\client\Binaries\GlobalAgenda.exe present" }
            $btnLink.Text = "Re-link Server to Game"
        }
        "mismatch" {
            $lblLinkStatus.Text      = "[Path mismatch - re-link]"
            $lblLinkStatus.ForeColor = [System.Drawing.Color]::FromArgb(220, 180, 50)
            $src = Get-LinkedGamePath
            $lblLinkDetail.Text = "Linked to: $src`r`nGame exe above is different - re-link to update."
            $btnLink.Text = "Re-link Server to Game"
        }
        default {
            $lblLinkStatus.Text      = "[Not linked]"
            $lblLinkStatus.ForeColor = [System.Drawing.Color]::FromArgb(210, 90, 90)
            $lblLinkDetail.Text      = "Click Link after setting the Game executable path above."
            $btnLink.Text = "Link Server to Game"
        }
    }
}

function Invoke-LinkServerToGame {
    $gameExe  = $txtExe.Text
    $repoRoot = $txtRepo.Text

    if (-not $repoRoot -or -not (Test-RepoRoot $repoRoot)) {
        Write-Out "Server folder not set — use Browse first."; return
    }
    if (-not $gameExe -or -not (Test-Path $gameExe)) {
        Write-Out "Game exe not found — set the path above first."; return
    }
    if ([IO.Path]::GetFileName($gameExe) -ine "GlobalAgenda.exe") {
        Write-Out "Path must point to GlobalAgenda.exe"; return
    }
    $sourceBin = Split-Path -Parent $gameExe
    if ([IO.Path]::GetFileName($sourceBin) -ine "Binaries") {
        Write-Out "GlobalAgenda.exe must be inside a Binaries folder"; return
    }
    $dll = Join-Path $repoRoot "out\dinput8.dll"
    if (-not (Test-Path $dll)) {
        Write-Out "dinput8.dll not found in out\ -- run Rebuild DLL first, or place a pre-built dinput8.dll in the out\ folder."; return
    }
    $sourceRoot = Split-Path -Parent $sourceBin
    $client     = Join-Path $repoRoot "out\client"
    $clientBin  = Join-Path $client "Binaries"

    Write-Out "Linking server to game..."

    # Remove existing out\client safely
    if (Test-Path -LiteralPath $client -ErrorAction SilentlyContinue) {
        try {
            $item = Get-Item -LiteralPath $client -Force
            if ($item.LinkType) {
                [System.IO.Directory]::Delete($client)
            } else {
                foreach ($child in (Get-ChildItem -LiteralPath $client -Force)) {
                    if ($child.LinkType) { [System.IO.Directory]::Delete($child.FullName) }
                    else { Remove-Item -LiteralPath $child.FullName -Recurse -Force }
                }
                Remove-Item -LiteralPath $client -Force
            }
        } catch { Write-Out "Warning removing old out\client: $_" }
    }

    # Create out\client\Binaries
    try { New-Item -ItemType Directory -Path $clientBin -Force | Out-Null } catch {
        Write-Out "Failed to create out\client\Binaries: $_"; return
    }

    # Copy ALL files from Steam Binaries (DLLs, configs, etc.)
    Write-Out "Copying game Binaries..."
    $copied = 0; $failed = 0
    try {
        Get-ChildItem -LiteralPath $sourceBin -File | ForEach-Object {
            try {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $clientBin $_.Name) -Force
                $copied++
            } catch { $failed++ }
        }
    } catch { Write-Out "Warning during Binaries copy: $_" }
    Write-Out "Copied $copied file(s) from game Binaries."

    # Always overwrite with our hook DLL after the Steam copy
    try { Copy-Item -LiteralPath $dll -Destination (Join-Path $clientBin "dinput8.dll") -Force }
    catch { Write-Out "Warning: could not copy dinput8.dll: $_" }

    # Create junctions for Engine, TgGame, PreReqs
    foreach ($name in @("Engine","TgGame","PreReqs")) {
        $target = Join-Path $sourceRoot $name
        if (Test-Path -LiteralPath $target) {
            try { New-Item -ItemType Junction -Path (Join-Path $client $name) -Target $target | Out-Null }
            catch { Write-Out "Warning: could not junction $name $_" }
        }
    }

    # Save link source for display
    try { $gameExe | Set-Content -Path (Join-Path $client ".linked_from") -Encoding UTF8 } catch { }

    Write-Out "Linked. Server will now spawn game instances from: $sourceRoot"
    Update-LinkStatus
}

# =============================== BOTTOM BUTTONS & STATUS =====================

$btnStartServer = New-Button "Start Local Server"  16 730 190 40 $true
$btnLaunchGame  = New-Button "Launch Game"        214 730 170 40 $true
$btnStopServer  = New-Button "Stop Server"        392 730 150 40
$btnRebuild     = New-Button "Rebuild DLL"        550 730 140 40
$btnOpenLogs    = New-Button "Open Logs"          698 730 120 40
$btnSave        = New-Button "Save Settings"      826 730 130 40
$form.Controls.AddRange(@($btnStartServer,$btnLaunchGame,$btnStopServer,$btnRebuild,$btnOpenLogs,$btnSave))

$lblStatusServer           = New-Label "Server: stopped" 16 778 320 26
$lblStatusServer.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblStatusServer.ForeColor = [System.Drawing.Color]::FromArgb(210, 90, 90)
$form.Controls.Add($lblStatusServer)

$lblStatusRest             = New-Label "" 340 778 736 26
$lblStatusRest.Font        = New-Object System.Drawing.Font("Segoe UI", 11)
$lblStatusRest.ForeColor   = [System.Drawing.Color]::FromArgb(215, 215, 215)
$form.Controls.Add($lblStatusRest)

function Write-Out($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    $txtOut.AppendText("[$ts] $msg`r`n")
    $txtOut.SelectionStart = $txtOut.TextLength
    $txtOut.ScrollToCaret()
}

function Get-SelectedDifficulty {
    ($radioDiffs | Where-Object { $_.Checked } | Select-Object -First 1).Text
}

function Update-Status {
    $running = ($script:ServerProcess -and -not $script:ServerProcess.HasExited)
    if ($running) {
        $lblStatusServer.Text      = "Server: running (PID $($script:ServerProcess.Id))"
        $lblStatusServer.ForeColor = [System.Drawing.Color]::FromArgb(90, 210, 120)
    } else {
        $lblStatusServer.Text      = "Server: stopped"
        $lblStatusServer.ForeColor = [System.Drawing.Color]::FromArgb(210, 90, 90)
    }
    $rest = "Difficulty: $(Get-SelectedDifficulty)"
    if ($script:CurrentMap) { $rest += "   |   Current Map: $(Get-MapDisplay $script:CurrentMap)" }
    $lblStatusRest.Text = $rest
}

# =============================== ACTIONS =====================================

function Get-UiSettings {
    $enabled = @()
    foreach ($ch in $allChannels) { if ($chkChannels[$ch].Checked) { $enabled += $ch } }
    return @{
        RepoRoot        = $txtRepo.Text
        ClientExePath   = $txtExe.Text
        Difficulty      = Get-SelectedDifficulty
        ShowGameConsole = $chkShowConsole.Checked
        AllowDupeLogins = $chkDupeLogins.Checked
        ClientLog       = $chkClientLog.Checked
        NoStartupMovies = $chkNoMovies.Checked
        LastTabIndex    = [int]$tabs.SelectedIndex
        Channels        = $enabled
    }
}

function Apply-ServerConfig($s) {
    $cfgPath = Get-ServerConfigPath $s.RepoRoot
    if (-not $cfgPath) {
        Write-Out "Server folder path is not set - use Browse to select it."
        return $false
    }
    try {
        if (Test-Path $cfgPath) {
            $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
        } else {
            # First run - create a fresh config
            $cfg = [PSCustomObject]@{
                game_binary = "out/client/Binaries/GlobalAgenda.exe"
                host = "127.0.0.1"
                hostdns = "127.0.0.1"
                home_map_name = "Dome3_VR_Arena_P"
                home_map_game_mode = "TgGame.TgGame_Mission"
                tcp_port = 9000
                chat_port = 9001
                ipc_port = 9010
                udp_port_range = [PSCustomObject]@{ lo = 9002; hi = 9020 }
                admin_token = ""
                startup_timeout_seconds = 120
                fix_package_guids = $true
                clear_logs = $false
                log_dir = "out/logs"
                db_path = "out/server.db"
                enabled_channels = @()
                enabled_crash_channels = @()
                announcers = @()
            }
        }
        # Apply launcher settings to config
        # Use Add-Member to handle both existing and fresh configs
        $cfg | Add-Member -NotePropertyName "show_game_console"              -NotePropertyValue ([bool]$s.ShowGameConsole) -Force
        $cfg | Add-Member -NotePropertyName "allow_duplicate_account_logins" -NotePropertyValue ([bool]$s.AllowDupeLogins) -Force
        $cfg | Add-Member -NotePropertyName "enabled_channels"               -NotePropertyValue @($s.Channels) -Force
        $tierScalar = $TierScalars[$s.Difficulty]
        if (-not $tierScalar) { $tierScalar = 1.0 }
        $cfg | Add-Member -NotePropertyName 'tier_scalar' -NotePropertyValue ([double]$tierScalar) -Force
        $cfg | Add-Member -NotePropertyName 'tier_name' -NotePropertyValue ([string]$s.Difficulty) -Force
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $cfgPath -Encoding UTF8
        Write-Out "Applied server options to control-server.json"
        return $true
    } catch {
        Write-Out "Failed to update control-server.json: $_"
        return $false
    }
}

$script:OutLogPath = ""
$script:ErrLogPath = ""
$script:OutOffset  = 0
$script:ErrOffset  = 0

function Read-NewText($file, [ref]$offset) {
    if (-not $file -or -not (Test-Path $file)) { return "" }
    try {
        $fs = [System.IO.File]::Open($file, [System.IO.FileMode]::Open,
                                     [System.IO.FileAccess]::Read,
                                     [System.IO.FileShare]::ReadWrite)
        try {
            if ($fs.Length -lt $offset.Value) { $offset.Value = 0 }
            if ($fs.Length -eq $offset.Value) { return "" }
            [void]$fs.Seek($offset.Value, [System.IO.SeekOrigin]::Begin)
            $buf = New-Object byte[] ($fs.Length - $offset.Value)
            $read = $fs.Read($buf, 0, $buf.Length)
            $offset.Value += $read
            return [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
        } finally { $fs.Dispose() }
    } catch { return "" }
}

function Pump-ServerOutput {
    $chunk = ""
    $chunk += Read-NewText $script:OutLogPath ([ref]$script:OutOffset)
    $chunk += Read-NewText $script:ErrLogPath ([ref]$script:ErrOffset)
    if (-not $chunk) { return }
    $txtOut.AppendText($chunk)
    $txtOut.SelectionStart = $txtOut.TextLength
    $txtOut.ScrollToCaret()
    foreach ($line in ($chunk -split "`r?`n")) {
        if ($line -match 'GSC_GO_PLAY.*?map=([A-Za-z0-9_]+)') {
            $script:CurrentMap = $Matches[1]
            Update-Status
        }
    }
}

$outputTimer          = New-Object System.Windows.Forms.Timer
$outputTimer.Interval = 400
$outputTimer.Add_Tick({ Pump-ServerOutput })

$btnStartServer.Add_Click({
    if ($script:ServerProcess -and -not $script:ServerProcess.HasExited) {
        Write-Out "Server is already running."
        return
    }
    $s = Get-UiSettings
    if (-not (Test-RepoRoot $s.RepoRoot)) {
        Write-Out "Server folder doesn't look right - use Browse to select it."
        return
    }
    Save-Settings $s
    # Kill any leftover mission instances before starting
    $instDir = Join-Path $s.RepoRoot "out\client"
    $killed = 0
    foreach ($p in @(Get-Process -Name "GlobalAgenda" -ErrorAction SilentlyContinue)) {
        try {
            if ($p.Path -and $p.Path.StartsWith($instDir, [StringComparison]::OrdinalIgnoreCase)) {
                $p | Stop-Process -Force
                $killed++
            }
        } catch { }
    }
    if ($killed -gt 0) { Write-Out "Cleared $killed leftover mission instance(s)." }
    if (-not (Apply-ServerConfig $s)) { return }

    $exe = Get-ServerExePath $s.RepoRoot
    if (-not (Test-Path $exe)) {
        Write-Out "control-server.exe not found - run Rebuild DLL first."
        return
    }

    $outDir = Join-Path $s.RepoRoot "out"
    $script:OutLogPath = Join-Path $outDir "launcher-server.out.log"
    $script:ErrLogPath = Join-Path $outDir "launcher-server.err.log"
    $script:OutOffset  = 0
    $script:ErrOffset  = 0
    foreach ($f in @($script:OutLogPath, $script:ErrLogPath)) {
        try { Set-Content -Path $f -Value "" -NoNewline -Encoding UTF8 } catch { }
    }

    try {
        $proc = Start-Process -FilePath $exe `
                    -ArgumentList ('--config "' + (Get-ServerConfigPath $s.RepoRoot) + '"') `
                    -WorkingDirectory $s.RepoRoot `
                    -RedirectStandardOutput $script:OutLogPath `
                    -RedirectStandardError  $script:ErrLogPath `
                    -WindowStyle Hidden -PassThru
        $script:ServerProcess = $proc
        $outputTimer.Start()
        Update-Status
        Write-Out "Server started (PID $($proc.Id))."
    } catch {
        Write-Out "Failed to start server: $_"
    }
})

$btnLaunchGame.Add_Click({
    $s = Get-UiSettings
    Save-Settings $s

    if (-not $s.ClientExePath -or -not (Test-Path $s.ClientExePath)) {
        Write-Out "Game exe not found - use Browse to point at GlobalAgenda.exe."
        return
    }

    $gameArgs = @("-host=localhost", "-seekfreeloading")
    if ($s.ClientLog)       { $gameArgs += "-log" }
    if ($s.NoStartupMovies) { $gameArgs += "-nostartupmovies" }

    try {
        $wd = Split-Path -Parent $s.ClientExePath
        Start-Process -FilePath $s.ClientExePath -ArgumentList $gameArgs -WorkingDirectory $wd | Out-Null
        Write-Out "Game launched: $($gameArgs -join ' ')"
    } catch {
        Write-Out "Failed to launch game: $_"
    }
})

$btnStopServer.Add_Click({
    if ($script:ServerProcess -and -not $script:ServerProcess.HasExited) {
        try { $script:ServerProcess.Kill(); Write-Out "Server stopped." }
        catch { Write-Out "Failed to stop server: $_" }
    } else {
        $stray = Get-Process -Name "control-server" -ErrorAction SilentlyContinue
        if ($stray) { $stray | Stop-Process -Force; Write-Out "Stopped stray control-server process(es)." }
        else        { Write-Out "Server is not running." }
    }
    $instDir = Join-Path (Get-UiSettings).RepoRoot "out\client"
    $killed = 0
    foreach ($p in @(Get-Process -Name "GlobalAgenda" -ErrorAction SilentlyContinue)) {
        try {
            if ($p.Path -and $p.Path.StartsWith($instDir, [StringComparison]::OrdinalIgnoreCase)) {
                $p | Stop-Process -Force
                $killed++
            }
        } catch { }
    }
    if ($killed -gt 0) { Write-Out "Stopped $killed leftover mission instance(s)." }

    Pump-ServerOutput
    $outputTimer.Stop()
    

$script:ServerProcess = $null
    $script:CurrentMap = ""
    Update-Status
})

$btnRebuild.Add_Click({
    $s = Get-UiSettings
    $bat = Join-Path $s.RepoRoot "windows-server-menu.bat"
    if (-not (Test-Path $bat)) {
        Write-Out "windows-server-menu.bat not found - check the server folder path."
        return
    }
    Write-Out "Opening build menu - choose option 1 in the new window."
    Start-Process -FilePath "cmd.exe" -ArgumentList "/k", "`"$bat`"" -WorkingDirectory $s.RepoRoot
})

$btnOpenLogs.Add_Click({
    $s = Get-UiSettings
    $dir = Get-LogDirPath $s.RepoRoot
    if ($dir -and (Test-Path $dir)) { Start-Process explorer.exe $dir }
    else { Write-Out "Log folder not found - the server may not have run yet." }
})

$btnSave.Add_Click({
    $s = Get-UiSettings
    Save-Settings $s
    Apply-ServerConfig $s | Out-Null
    Write-Out "Settings saved. Difficulty: $($s.Difficulty)"
})


$btnLink.Add_Click({ Invoke-LinkServerToGame })
$btnCheckLink.Add_Click({
    $repo    = $txtRepo.Text
    $gameExe = $txtExe.Text
    Write-Out "--- Link Check ---"
    Write-Out "Server folder : $repo"
    Write-Out "Game exe      : $gameExe"
    $clientExe = if ($repo) { Join-Path $repo "out\client\Binaries\GlobalAgenda.exe" } else { "" }
    $clientDll = if ($repo) { Join-Path $repo "out\client\Binaries\dinput8.dll" } else { "" }
    $hookDll   = if ($repo) { Join-Path $repo "out\dinput8.dll" } else { "" }
    Write-Out "client exe    : $clientExe -- $(if (Test-Path $clientExe) { 'EXISTS' } else { 'MISSING' })"
    Write-Out "client dll    : $clientDll -- $(if (Test-Path $clientDll) { 'EXISTS' } else { 'MISSING' })"
    Write-Out "hook dll      : $hookDll -- $(if (Test-Path $hookDll) { 'EXISTS' } else { 'MISSING' })"
    $linkedFrom = Get-LinkedGamePath
    if ($linkedFrom) { Write-Out "Linked from   : $linkedFrom" }
    $state = Get-LinkState
    Write-Out "Status        : $state"
    if ($state -eq "mismatch") { Write-Out "WARNING: linked path does not match current game exe - click Re-link to update." }
    if ($state -eq "none")     { Write-Out "WARNING: out\client\Binaries\GlobalAgenda.exe not found - click Link to set up." }
    Write-Out "--- End Check ---"
    Update-LinkStatus
})

foreach ($r in $radioDiffs) {
    $r.Add_CheckedChanged({
        if ($this.Checked) {
            Update-Status
            if ($script:ServerProcess -and -not $script:ServerProcess.HasExited) {
                Write-Out "Difficulty changed -- stopping server. Click Start Server to apply new tier."
                try { $script:ServerProcess.Kill() } catch { }
                $outputTimer.Stop()
                $script:ServerProcess = $null
                $script:CurrentMap = ""
                Update-Status
            }
        }
    })
}

# Close launcher: always stop the server, no prompt
$form.Add_FormClosing({
    $s = Get-UiSettings
    Save-Settings $s
    if ($script:ServerProcess -and -not $script:ServerProcess.HasExited) {
        try { $script:ServerProcess.Kill() } catch { }
    }
    # Kill any leftover mission instances
    $instDir = Join-Path $s.RepoRoot "out\client"
    foreach ($p in @(Get-Process -Name "GlobalAgenda" -ErrorAction SilentlyContinue)) {
        try {
            if ($p.Path -and $p.Path.StartsWith($instDir, [StringComparison]::OrdinalIgnoreCase)) {
                $p | Stop-Process -Force
            }
        } catch { }
    }
})

# --- Startup -----------------------------------------------------------------
if (Test-RepoRoot $Settings.RepoRoot) { Write-Out "Server folder: $($Settings.RepoRoot)" }
else { Write-Out "Server folder may be wrong - use Browse if the server won't start." }

if ($Settings.ClientExePath -and (Test-Path $Settings.ClientExePath)) { Write-Out "Game exe: $($Settings.ClientExePath)" }
else { Write-Out "Game exe not found automatically - use Browse to select GlobalAgenda.exe." }

Write-Out "Ready."
Update-Status
Update-LinkStatus

# Restore last tab
$lastTab = [int]$Settings.LastTabIndex
if ($lastTab -ge 0 -and $lastTab -lt $tabs.TabPages.Count) {
    $tabs.SelectedIndex = $lastTab
    if ($tabs.TabPages[$lastTab] -eq $tabDone) {
        Load-Completions
        $want = Get-SelectedDifficulty
        foreach ($p in $tabsDone.TabPages) { if ($p.Text -eq $want) { $tabsDone.SelectedTab = $p; break } }
    }
}

[void]$form.ShowDialog()
