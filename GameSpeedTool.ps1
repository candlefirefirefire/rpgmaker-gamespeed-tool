param([switch]$Test)

#Requires -Version 5.0
# =============================================================================
#  RPG Maker 游戏加速工具 (GameSpeedTool) - GUI
#  支持: RPG Maker MV / MZ (NW.js)
#  RGSS (XP/VX/VX Ace) 不支持注入, 请用 CE Speedhack
# =============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = 'Stop'
$script:Games = New-Object System.Collections.ArrayList
$script:Root = 'E:\game'

$corePath = Join-Path $PSScriptRoot 'GameSpeedTool.Core.ps1'
. $corePath

if ($Test) {
    Write-Output "Scanning: $script:Root"
    $games = Scan-Games $script:Root
    $games | Select-Object Name, Engine, Dir | Format-Table -AutoSize -Wrap
    $games | Group-Object Engine | Select-Object Name, Count | Format-Table -AutoSize
    return
}

# -----------------------------------------------------------------------------
# GUI
# -----------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$script:Version = '1.1.0'
$form.Text = "RPG Maker 游戏加速工具 v$($script:Version)"
$form.ClientSize = New-Object System.Drawing.Size(1100, 740)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(900, 600)
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

$lblRoot = New-Object System.Windows.Forms.Label
$lblRoot.Text = '游戏根目录:'
$lblRoot.Location = New-Object System.Drawing.Point(12, 16)
$lblRoot.AutoSize = $true

$txtRoot = New-Object System.Windows.Forms.TextBox
$txtRoot.Location = New-Object System.Drawing.Point(96, 12)
$txtRoot.Size = New-Object System.Drawing.Size(640, 26)
$txtRoot.Text = $script:Root

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = '浏览...'
$btnBrowse.Location = New-Object System.Drawing.Point(744, 10)
$btnBrowse.Size = New-Object System.Drawing.Size(80, 28)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = '扫描游戏'
$btnScan.Location = New-Object System.Drawing.Point(832, 10)
$btnScan.Size = New-Object System.Drawing.Size(100, 28)

$lblSpeed = New-Object System.Windows.Forms.Label
$lblSpeed.Text = '默认倍速:'
$lblSpeed.Location = New-Object System.Drawing.Point(12, 56)
$lblSpeed.AutoSize = $true

$numSpeed = New-Object System.Windows.Forms.NumericUpDown
$numSpeed.Location = New-Object System.Drawing.Point(96, 52)
$numSpeed.Size = New-Object System.Drawing.Size(60, 26)
$numSpeed.Minimum = 1
$numSpeed.Maximum = 8
$numSpeed.Value = 2

$btnInstallSel = New-Object System.Windows.Forms.Button
$btnInstallSel.Text = '安装选中'
$btnInstallSel.Location = New-Object System.Drawing.Point(180, 50)
$btnInstallSel.Size = New-Object System.Drawing.Size(90, 28)

$btnInstallAll = New-Object System.Windows.Forms.Button
$btnInstallAll.Text = '安装全部'
$btnInstallAll.Location = New-Object System.Drawing.Point(278, 50)
$btnInstallAll.Size = New-Object System.Drawing.Size(90, 28)

$btnRestoreSel = New-Object System.Windows.Forms.Button
$btnRestoreSel.Text = '还原选中'
$btnRestoreSel.Location = New-Object System.Drawing.Point(376, 50)
$btnRestoreSel.Size = New-Object System.Drawing.Size(90, 28)

$btnRestoreAll = New-Object System.Windows.Forms.Button
$btnRestoreAll.Text = '全部还原'
$btnRestoreAll.Location = New-Object System.Drawing.Point(474, 50)
$btnRestoreAll.Size = New-Object System.Drawing.Size(90, 28)

$btnLaunch = New-Object System.Windows.Forms.Button
$btnLaunch.Text = '启动选中游戏'
$btnLaunch.Location = New-Object System.Drawing.Point(572, 50)
$btnLaunch.Size = New-Object System.Drawing.Size(110, 28)

$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(12, 92)
$listView.Size = New-Object System.Drawing.Size(1076, 470)
$listView.Anchor = 'Top,Left,Right,Bottom'
$listView.View = 'Details'
$listView.CheckBoxes = $true
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.MultiSelect = $false
[void]$listView.Columns.Add('游戏', 300)
[void]$listView.Columns.Add('引擎', 70)
[void]$listView.Columns.Add('状态', 80)
[void]$listView.Columns.Add('路径', 600)

$log = New-Object System.Windows.Forms.TextBox
$log.Location = New-Object System.Drawing.Point(12, 574)
$log.Size = New-Object System.Drawing.Size(1076, 150)
$log.Anchor = 'Left,Right,Bottom'
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = 'Vertical'
$log.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$log.ForeColor = [System.Drawing.Color]::FromArgb(180, 255, 180)
$log.Font = New-Object System.Drawing.Font('Consolas', 9)

$script:LogBox = $log

function Write-Log([string]$Msg) {
    $script:LogBox.AppendText("[" + (Get-Date -Format 'HH:mm:ss') + "] $Msg`r`n")
    $script:LogBox.SelectionStart = $script:LogBox.TextLength
    $script:LogBox.ScrollToCaret()
}

function Get-StatusText($g) {
    if ($g.Engine -eq 'MV' -or $g.Engine -eq 'MZ') {
        return $(if (Test-IsSpeedInstalled $g.Target) { '已安装' } else { '未安装' })
    }
    return '不适用'
}

function Refresh-List {
    $listView.BeginUpdate()
    $listView.Items.Clear()
    foreach ($g in $script:Games) {
        $item = New-Object System.Windows.Forms.ListViewItem($g.Name)
        [void]$item.SubItems.Add($g.Engine)
        $st = Get-StatusText $g
        [void]$item.SubItems.Add($st)
        [void]$item.SubItems.Add($g.Dir)
        $item.Tag = $g
        $item.Checked = (($g.Engine -eq 'MV' -or $g.Engine -eq 'MZ') -and $st -eq '未安装')
        [void]$listView.Items.Add($item)
    }
    $listView.EndUpdate()
}

function Do-Scan {
    $script:Root = $txtRoot.Text.Trim()
    if (-not (Test-Path -LiteralPath $script:Root)) {
        Write-Log "目录不存在: $script:Root"
        return
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    try {
        Write-Log "开始扫描: $script:Root"
        $script:Games = Scan-Games $script:Root
        Refresh-List
        $mv = @($script:Games | Where-Object { $_.Engine -eq 'MV' }).Count
        $mz = @($script:Games | Where-Object { $_.Engine -eq 'MZ' }).Count
        $rg = @($script:Games | Where-Object { $_.Engine -eq 'RGSS' }).Count
        Write-Log "扫描完成: 共 $($script:Games.Count) 个游戏 (MV $mv / MZ $mz / RGSS $rg / 其他 $($script:Games.Count - $mv - $mz - $rg))"
    } catch {
        Write-Log "扫描出错: $($_.Exception.Message)"
    } finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

$btnBrowse.Add_Click({
    try {
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = '选择游戏根目录'
        if ($dlg.ShowDialog() -eq 'OK') {
            $txtRoot.Text = $dlg.SelectedPath
            Do-Scan
        }
    } catch {
        Write-Log "选择目录出错: $($_.Exception.Message)"
    }
})

$btnScan.Add_Click({
    try { Do-Scan } catch { Write-Log "扫描出错: $($_.Exception.Message)" }
})

$btnInstallSel.Add_Click({
    try {
        $speed = [int]$numSpeed.Value
        $count = 0
        foreach ($item in $listView.CheckedItems) {
            $g = $item.Tag
            if ($g.Engine -eq 'MV' -or $g.Engine -eq 'MZ') {
                if (Install-Speed $g $speed) {
                    Write-Log "已安装: $($g.Name) [$($g.Engine)] - $speed 倍速"
                    $count++
                }
            }
        }
        Refresh-List
        Write-Log "安装选中完成: $count 个"
    } catch {
        Write-Log "安装出错: $($_.Exception.Message)"
    }
})

$btnInstallAll.Add_Click({
    try {
        $speed = [int]$numSpeed.Value
        $count = 0
        foreach ($g in $script:Games) {
            if ($g.Engine -eq 'MV' -or $g.Engine -eq 'MZ') {
                if (Install-Speed $g $speed) {
                    Write-Log "已安装: $($g.Name) [$($g.Engine)] - $speed 倍速"
                    $count++
                }
            }
        }
        Refresh-List
        Write-Log "安装全部完成: $count 个 (RGSS 游戏未处理, 请用 CE 变速)"
    } catch {
        Write-Log "安装出错: $($_.Exception.Message)"
    }
})

$btnRestoreSel.Add_Click({
    try {
        $count = 0
        foreach ($item in $listView.CheckedItems) {
            $g = $item.Tag
            if ($g.Engine -eq 'MV' -or $g.Engine -eq 'MZ') {
                if (Restore-Speed $g) {
                    Write-Log "已还原: $($g.Name)"
                    $count++
                }
            }
        }
        Refresh-List
        Write-Log "还原选中完成: $count 个"
    } catch {
        Write-Log "还原出错: $($_.Exception.Message)"
    }
})

$btnRestoreAll.Add_Click({
    try {
        $count = 0
        foreach ($g in $script:Games) {
            if ($g.Engine -eq 'MV' -or $g.Engine -eq 'MZ') {
                if (Restore-Speed $g) { $count++ }
            }
        }
        Refresh-List
        Write-Log "全部还原完成: $count 个"
    } catch {
        Write-Log "还原出错: $($_.Exception.Message)"
    }
})

$btnLaunch.Add_Click({
    try {
        $sel = @($listView.CheckedItems)
        if ($sel.Count -eq 0) {
            Write-Log '请先勾选要启动的游戏'
            return
        }
        $g = $sel[0].Tag
        Write-Log "启动: $($g.Dir)"
        Start-Process -FilePath $g.Launcher -WorkingDirectory $g.Dir
    } catch {
        Write-Log "启动出错: $($_.Exception.Message)"
    }
})

[void]$form.Controls.Add($lblRoot)
[void]$form.Controls.Add($txtRoot)
[void]$form.Controls.Add($btnBrowse)
[void]$form.Controls.Add($btnScan)
[void]$form.Controls.Add($lblSpeed)
[void]$form.Controls.Add($numSpeed)
[void]$form.Controls.Add($btnInstallSel)
[void]$form.Controls.Add($btnInstallAll)
[void]$form.Controls.Add($btnRestoreSel)
[void]$form.Controls.Add($btnRestoreAll)
[void]$form.Controls.Add($btnLaunch)
[void]$form.Controls.Add($listView)
[void]$form.Controls.Add($log)

Write-Log '工具已就绪。正在扫描游戏，请稍等...'
Write-Log '说明: 安装后进游戏默认 2 倍速, 右上角实时显示当前倍速。'
Write-Log '游戏中按 F7 加速(最高 8 倍), F6 减速, F9 显示/隐藏角标。'
Write-Log 'RGSS 引擎(XP/VX/Ace)无法注入, 这类游戏用 Cheat Engine 的 Speedhack 即可。'

try {
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    Do-Scan
} catch {
    Write-Log "启动出错: $($_.Exception.Message)"
}

[void][System.Windows.Forms.Application]::Run($form)
