#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Azure Rescue VM ToolKit - No Boot Troubleshooting Tool
.DESCRIPTION
    GUI tool for troubleshooting Azure VM no-boot issues from a rescue VM.
    Provides buttons to read partitions, run DISM, SFC, CHKDSK, and BCD rebuild.
.NOTES
    Must be run as Administrator on the rescue VM after attaching the problematic disk.
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Azure Rescue VM ToolKit" Height="880" Width="900"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip"
        Background="#1E1E2E" Foreground="White">
    <Window.Resources>
        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Height" Value="50"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Center"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Style.Triggers>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.4"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Title -->
        <TextBlock Grid.Row="0" Text="Azure Rescue VM ToolKit" FontSize="22" FontWeight="Bold"
                   Foreground="#89B4FA" HorizontalAlignment="Center" Margin="0,0,0,5"/>
        <TextBlock Grid.Row="1" Text="No-Boot Troubleshooting Tool" FontSize="12"
                   Foreground="#A6ADC8" HorizontalAlignment="Center" Margin="0,0,0,10"/>

        <!-- Disk Selection -->
        <GroupBox Grid.Row="2" Header="Disk Selection" Foreground="#CDD6F4" BorderBrush="#45475A"
                  Margin="0,0,0,10" Padding="10">
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <TextBlock Text="Disk Number:" VerticalAlignment="Center" Margin="0,0,10,0"
                           Foreground="#CDD6F4"/>
                <ComboBox Name="DiskCombo" Width="80" Height="30" FontSize="14" IsEditable="True"/>
                <Button Name="BtnReadPartitions" Content="&#xE8B7;  Read Partitions"
                        Style="{StaticResource ActionButton}" Width="220" Margin="15,0,0,0"
                        Background="#1E66F5" ToolTip="Bring disk online, assign letters, and read all partitions"/>
            </StackPanel>
        </GroupBox>

        <!-- Partition Info -->
        <GroupBox Grid.Row="3" Header="Partition Map" Foreground="#CDD6F4" BorderBrush="#45475A"
                  Margin="0,0,0,10" Padding="5">
            <StackPanel>
                <DataGrid Name="PartitionGrid" Height="130" AutoGenerateColumns="False"
                          IsReadOnly="True" Background="#313244" Foreground="#CDD6F4"
                          BorderBrush="#45475A" GridLinesVisibility="Horizontal"
                          HeadersVisibility="Column" CanUserAddRows="False"
                          HorizontalGridLinesBrush="#45475A" RowBackground="#313244"
                          AlternatingRowBackground="#3B3D50" FontSize="12">
                    <DataGrid.ColumnHeaderStyle>
                        <Style TargetType="DataGridColumnHeader">
                            <Setter Property="Background" Value="#1E1E2E"/>
                            <Setter Property="Foreground" Value="#FFFFFF"/>
                            <Setter Property="FontWeight" Value="Bold"/>
                            <Setter Property="FontSize" Value="12"/>
                            <Setter Property="Padding" Value="6,4"/>
                            <Setter Property="BorderBrush" Value="#45475A"/>
                            <Setter Property="BorderThickness" Value="0,0,1,2"/>
                        </Style>
                    </DataGrid.ColumnHeaderStyle>
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Partition #" Binding="{Binding Number}" Width="80"/>
                        <DataGridTextColumn Header="Original Letter" Binding="{Binding OriginalLetter}" Width="100"/>
                        <DataGridTextColumn Header="Assigned Letter" Binding="{Binding AssignedLetter}" Width="100"/>
                        <DataGridTextColumn Header="Drive Letter" Binding="{Binding DriveLetter}" Width="90"/>
                        <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="80"/>
                        <DataGridTextColumn Header="Size" Binding="{Binding Size}" Width="80"/>
                        <DataGridTextColumn Header="Label" Binding="{Binding Label}" Width="*"/>
                    </DataGrid.Columns>
                </DataGrid>
                <StackPanel Orientation="Horizontal" Margin="0,8,0,0" HorizontalAlignment="Center">
                    <TextBlock Text="Windows Volume:" VerticalAlignment="Center" Margin="0,0,5,0"
                               Foreground="#CDD6F4"/>
                    <ComboBox Name="WinVolCombo" Width="70" Height="28" FontSize="13" Margin="0,0,20,0"/>
                    <TextBlock Text="System Partition:" VerticalAlignment="Center" Margin="0,0,5,0"
                               Foreground="#CDD6F4"/>
                    <ComboBox Name="SysPartCombo" Width="70" Height="28" FontSize="13"/>
                </StackPanel>
            </StackPanel>
        </GroupBox>

        <!-- Action Buttons -->
        <GroupBox Grid.Row="4" Header="Repair Actions" Foreground="#CDD6F4" BorderBrush="#45475A"
                  Margin="0,0,0,10" Padding="5">
            <StackPanel Margin="5">
                <UniformGrid Rows="2" Columns="4">
                    <Button Name="BtnDism" Content="DISM&#x0a;Scan / Repair"
                            Style="{StaticResource ActionButton}" Background="#DF8E1D" IsEnabled="False"
                            ToolTip="Run DISM ScanHealth then RestoreHealth if corruption found. Auto-detects Online/Offline mode."/>
                    <Button Name="BtnSfc" Content="SFC&#x0a;Scan"
                            Style="{StaticResource ActionButton}" Background="#40A02B" IsEnabled="False"
                            ToolTip="Run System File Checker - auto-detects Online (local) or Offline (attached disk) mode"/>
                    <Button Name="BtnChkdsk" Content="CHKDSK&#x0a;/f /r"
                            Style="{StaticResource ActionButton}" Background="#8839EF" IsEnabled="False"
                            ToolTip="Check and repair filesystem on the Windows volume"/>
                    <Button Name="BtnBcd" Content="BCD&#x0a;Rebuild"
                            Style="{StaticResource ActionButton}" Background="#D20F39" IsEnabled="False"
                            ToolTip="Backup and rebuild Boot Configuration Data"/>
                    <Button Name="BtnSearchFilters" Content="Search&#x0a;Filters"
                            Style="{StaticResource ActionButton}" Background="#009688" IsEnabled="False"
                            ToolTip="Search offline registry for UpperFilters and LowerFilters entries in all device Class GUIDs"/>
                    <Button Name="BtnGetPackages" Content="Check&#x0a;Packages"
                            Style="{StaticResource ActionButton}" Background="#795548" IsEnabled="False"
                            ToolTip="List all installed and staged packages on the offline Windows image using DISM"/>
                    <Button Name="BtnOffline" Content="Disk&#x0a;Offline"
                            Style="{StaticResource ActionButton}" Background="#7287FD" IsEnabled="False"
                            ToolTip="Flush writes and mark the attached disk 'Offline' in Windows so it can be safely detached from this rescue VM. Does not modify data on the disk."/>
                    <Button Name="BtnRevertLetters" Content="Revert&#x0a;Drive Letters"
                            Style="{StaticResource ActionButton}" Background="#E64553" IsEnabled="False"
                            ToolTip="Remove only the drive letters that were assigned by this tool"/>
                </UniformGrid>
                <DockPanel Margin="0,6,0,0">
                    <CheckBox Name="ChkRevertPending" Content="Revert Pending Actions (Offline only)"
                              Foreground="#CDD6F4" FontSize="12" VerticalAlignment="Center"
                              IsEnabled="False" Margin="5,0,0,0"
                              ToolTip="When checked, DISM button runs RevertPendingActions instead of ScanHealth/RestoreHealth. Only available for attached disk."/>
                </DockPanel>
                <DockPanel Margin="0,8,0,0">
                    <Button Name="BtnRemovePackage" Content="Remove Package" DockPanel.Dock="Right"
                            Width="140" Height="36" FontSize="13" FontWeight="SemiBold" Foreground="White"
                            Background="#C62828" BorderThickness="0" Cursor="Hand" IsEnabled="False"
                            Margin="8,0,0,0"
                            ToolTip="Remove the package whose identity is typed in the box (uses DISM)"/>
                    <Button Name="BtnRemoveFilter" Content="Remove Filter" DockPanel.Dock="Right"
                            Width="140" Height="36" FontSize="13" FontWeight="SemiBold" Foreground="White"
                            Background="#00796B" BorderThickness="0" Cursor="Hand" IsEnabled="False"
                            Margin="8,0,0,0"
                            ToolTip="Back up, then remove the UpperFilters/LowerFilters value from the device Class GUID typed in the box (registry key is exported to a .reg backup first)"/>
                    <TextBox Name="TxtPackageName" Height="36" FontSize="13" FontFamily="Consolas"
                             Background="#313244" Foreground="#CDD6F4" BorderBrush="#45475A"
                             VerticalContentAlignment="Center" Padding="8,0"
                             ToolTip="Remove Package: enter the package identity (e.g. Package_for_KB5034441~31bf3856ad364e35~amd64~~10.0.1.1).&#x0a;Remove Filter: enter the device Class GUID (e.g. {4D36E967-E325-11CE-BFC1-08002BE10318})."/>
                </DockPanel>
            </StackPanel>
        </GroupBox>

        <!-- Advanced Boot Options -->
        <GroupBox Grid.Row="5" Header="Advanced Boot Options" Foreground="#CDD6F4" BorderBrush="#45475A"
                  Margin="0,0,0,10" Padding="5">
            <UniformGrid Rows="1" Columns="7" Margin="5">
                <Button Name="BtnSafeMode" Content="Safe&#x0a;Mode"
                        Style="{StaticResource ActionButton}" Background="#E6A817" IsEnabled="False"
                        ToolTip="Boot into Safe Mode (minimal drivers, no networking)"/>
                <Button Name="BtnSafeModeNet" Content="Safe Mode&#x0a;+ Network"
                        Style="{StaticResource ActionButton}" Background="#CC8400" IsEnabled="False"
                        ToolTip="Boot into Safe Mode with Networking enabled"/>
                <Button Name="BtnSafeModeCmd" Content="Safe Mode&#x0a;+ CMD"
                        Style="{StaticResource ActionButton}" Background="#B36B00" IsEnabled="False"
                        ToolTip="Boot into Safe Mode with Command Prompt only"/>
                <Button Name="BtnLKGC" Content="Last Known&#x0a;Good (LKGC)"
                        Style="{StaticResource ActionButton}" Background="#2196F3" IsEnabled="False"
                        ToolTip="Boot using Last Known Good Configuration"/>
                <Button Name="BtnDSRM" Content="DSRM&#x0a;Mode"
                        Style="{StaticResource ActionButton}" Background="#9C27B0" IsEnabled="False"
                        ToolTip="Directory Services Restore Mode (Domain Controllers only)"/>
                <Button Name="BtnNoDriverSig" Content="Disable&#x0a;Driver Sig"
                        Style="{StaticResource ActionButton}" Background="#FF5722" IsEnabled="False"
                        ToolTip="Disable Driver Signature Enforcement for this boot"/>
                <Button Name="BtnNormalBoot" Content="Normal&#x0a;Boot"
                        Style="{StaticResource ActionButton}" Background="#4CAF50" IsEnabled="False"
                        ToolTip="Remove all boot overrides and start Windows normally"/>
            </UniformGrid>
        </GroupBox>

        <!-- Output Log -->
        <GroupBox Grid.Row="6" Header="Output Log" Foreground="#CDD6F4" BorderBrush="#45475A"
                  Padding="5">
            <TextBox Name="OutputLog" Background="#181825" Foreground="#A6E3A1" FontFamily="Consolas"
                     FontSize="12" IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                     HorizontalScrollBarVisibility="Auto" TextWrapping="Wrap"
                     BorderThickness="0" Padding="8"/>
        </GroupBox>

        <!-- Status Bar -->
        <Border Grid.Row="7" Background="#313244" CornerRadius="4" Margin="0,8,0,0" Padding="8,4">
            <DockPanel>
                <Button Name="BtnCancel" Content="&#x2715; Cancel" DockPanel.Dock="Right"
                        Background="#D20F39" Foreground="White" FontSize="11" FontWeight="SemiBold"
                        Padding="12,2" Margin="8,0,0,0" Cursor="Hand" BorderThickness="0"
                        Visibility="Collapsed"/>
                <TextBlock Name="StatusText" Text="Ready - Select a disk and click Read Partitions"
                           Foreground="#A6ADC8" FontSize="11" VerticalAlignment="Center"/>
            </DockPanel>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$diskCombo        = $window.FindName("DiskCombo")
$btnReadParts     = $window.FindName("BtnReadPartitions")
$partitionGrid    = $window.FindName("PartitionGrid")
$winVolCombo      = $window.FindName("WinVolCombo")
$sysPartCombo     = $window.FindName("SysPartCombo")
$btnDism          = $window.FindName("BtnDism")
$chkRevertPending = $window.FindName("ChkRevertPending")
$btnSfc           = $window.FindName("BtnSfc")
$btnChkdsk        = $window.FindName("BtnChkdsk")
$btnBcd           = $window.FindName("BtnBcd")
$btnSearchFilters = $window.FindName("BtnSearchFilters")
$btnGetPackages   = $window.FindName("BtnGetPackages")
$btnRemovePackage = $window.FindName("BtnRemovePackage")
$btnRemoveFilter  = $window.FindName("BtnRemoveFilter")
$txtPackageName   = $window.FindName("TxtPackageName")
$btnOffline       = $window.FindName("BtnOffline")
$btnRevertLetters = $window.FindName("BtnRevertLetters")
$btnSafeMode      = $window.FindName("BtnSafeMode")
$btnSafeModeNet   = $window.FindName("BtnSafeModeNet")
$btnSafeModeCmd   = $window.FindName("BtnSafeModeCmd")
$btnLKGC          = $window.FindName("BtnLKGC")
$btnDSRM          = $window.FindName("BtnDSRM")
$btnNoDriverSig   = $window.FindName("BtnNoDriverSig")
$btnNormalBoot    = $window.FindName("BtnNormalBoot")
$outputLog        = $window.FindName("OutputLog")
$statusText       = $window.FindName("StatusText")
$btnCancel        = $window.FindName("BtnCancel")

# Track drive letters assigned by this tool (partition number -> letter)
$script:assignedLetters = @{}

# Track disks this tool has taken offline (disk number -> $true) so the Offline button
# stays disabled for them until 'Read Partitions' brings the disk back online.
$script:offlinedDisks = @{}

# Command execution guard state
$script:isRunning = $false
$script:currentProcess = $null
$script:cancelRequested = $false

# Helper: kill a process and its entire child tree (PS 5.1 has no Kill($true) overload).
# cmd.exe /c spawns DISM/SFC/CHKDSK as children; killing only cmd.exe would orphan them.
function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Process)
    if (-not $Process) { return }
    try {
        $procId = $Process.Id
    } catch {
        return
    }
    # taskkill /T terminates the process and all descendants.
    try {
        Start-Process -FilePath "taskkill" -ArgumentList "/PID $procId /T /F" -WindowStyle Hidden -Wait -ErrorAction Stop | Out-Null
    } catch {
        # Fallback: best-effort kill of the parent only
        try { $Process.Kill() } catch { }
    }
}

# Log file in same directory as the script/exe
$script:scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path -Parent } else { $PWD.Path }
$script:logFilePath = Join-Path $script:scriptDir ("AzureRescueToolKit_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

# DISM scratch directory — kept on the rescue VM (NOT the customer's OS disk) to avoid
# leaving artifacts on the attached disk. Created on demand and cleaned up on exit.
$script:scratchDir = Join-Path $env:TEMP "AzureRescueToolkit_Scratch"
function Get-ScratchDir {
    if (-not (Test-Path $script:scratchDir)) {
        New-Item -Path $script:scratchDir -ItemType Directory -Force | Out-Null
    }
    return $script:scratchDir
}

# Helper: write to log (GUI + file)
function Write-Log {
    param([string]$Message, [string]$Color)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    $outputLog.AppendText("$logLine`r`n")
    $outputLog.ScrollToEnd()
    Add-Content -Path $script:logFilePath -Value $logLine -Encoding UTF8
}

# Helper: update status bar
function Set-Status {
    param([string]$Text)
    $statusText.Text = $Text
}


# Helper: disable all action buttons during command execution
function Disable-AllButtons {
    $btnReadParts.IsEnabled = $false
    $btnDism.IsEnabled = $false
    $chkRevertPending.IsEnabled = $false
    $btnSfc.IsEnabled = $false
    $btnChkdsk.IsEnabled = $false
    $btnBcd.IsEnabled = $false
    $btnSearchFilters.IsEnabled = $false
    $btnGetPackages.IsEnabled = $false
    $btnRemovePackage.IsEnabled = $false
    $btnRemoveFilter.IsEnabled = $false
    $btnOffline.IsEnabled = $false
    $btnRevertLetters.IsEnabled = $false
    $btnSafeMode.IsEnabled = $false
    $btnSafeModeNet.IsEnabled = $false
    $btnSafeModeCmd.IsEnabled = $false
    $btnLKGC.IsEnabled = $false
    $btnDSRM.IsEnabled = $false
    $btnNoDriverSig.IsEnabled = $false
    $btnNormalBoot.IsEnabled = $false
}

# Helper: restore button states based on current combo selections
function Restore-AllButtons {
    $btnReadParts.IsEnabled = $true
    $hasWin = $winVolCombo.SelectedItem -ne $null
    $hasSys = $sysPartCombo.SelectedItem -ne $null
    $btnDism.IsEnabled    = $hasWin
    $localDrv = $env:SystemDrive -replace ':', ''
    $isAttachedR = $hasWin -and ($winVolCombo.SelectedItem -ne $localDrv)
    $chkRevertPending.IsEnabled = $isAttachedR
    if (-not $isAttachedR) { $chkRevertPending.IsChecked = $false }
    $btnSfc.IsEnabled     = $hasWin
    $btnChkdsk.IsEnabled  = $hasWin
    $btnBcd.IsEnabled     = $hasWin -and $hasSys
    $btnSearchFilters.IsEnabled = $hasWin
    $btnGetPackages.IsEnabled = $hasWin
    $btnRemovePackage.IsEnabled = $hasWin
    $btnRemoveFilter.IsEnabled = $hasWin
    $btnOffline.IsEnabled = ($hasWin -or $hasSys -or (-not [string]::IsNullOrEmpty($diskCombo.Text.Trim()))) -and (-not $script:offlinedDisks.ContainsKey($diskCombo.Text.Trim()))
    $btnSafeMode.IsEnabled    = $hasWin
    $btnSafeModeNet.IsEnabled = $hasWin
    $btnSafeModeCmd.IsEnabled = $hasWin
    $btnLKGC.IsEnabled        = $hasWin
    $btnDSRM.IsEnabled        = $hasWin
    $btnNoDriverSig.IsEnabled = $hasWin
    $btnNormalBoot.IsEnabled  = $hasWin
    if ($script:assignedLetters.Count -gt 0) {
        $btnRevertLetters.IsEnabled = $true
    }
    Set-RevertPendingOverride
}

# Helper: when 'Revert Pending Actions (Offline only)' is ticked, the DISM button switches to
# RevertPendingActions mode and no other action applies - grey out every other option so the
# user isn't misled into thinking the checkbox affects them.
function Set-RevertPendingOverride {
    if ($chkRevertPending.IsChecked -eq $true) {
        $btnSfc.IsEnabled = $false
        $btnChkdsk.IsEnabled = $false
        $btnBcd.IsEnabled = $false
        $btnSearchFilters.IsEnabled = $false
        $btnGetPackages.IsEnabled = $false
        $btnRemovePackage.IsEnabled = $false
        $btnRemoveFilter.IsEnabled = $false
        $btnOffline.IsEnabled = $false
        $btnRevertLetters.IsEnabled = $false
        $btnSafeMode.IsEnabled = $false
        $btnSafeModeNet.IsEnabled = $false
        $btnSafeModeCmd.IsEnabled = $false
        $btnLKGC.IsEnabled = $false
        $btnDSRM.IsEnabled = $false
        $btnNoDriverSig.IsEnabled = $false
        $btnNormalBoot.IsEnabled = $false
    }
}

# Helper: guard wrapper for button actions - prevents concurrent execution, shows cancel
function Start-GuardedAction {
    param([scriptblock]$Action)
    if ($script:isRunning) {
        [System.Windows.MessageBox]::Show(
            "A command is currently running. Please wait for it to finish or click Cancel.",
            "Command In Progress",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning)
        return
    }
    $script:isRunning = $true
    $script:cancelRequested = $false
    Disable-AllButtons
    $btnCancel.Visibility = 'Visible'
    $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
    try {
        & $Action
    }
    finally {
        $script:isRunning = $false
        $script:currentProcess = $null
        $script:cancelRequested = $false
        $btnCancel.Visibility = 'Collapsed'
        Restore-AllButtons
    }
}

# Helper: run a command and log output (non-blocking UI with cancel support).
# Uses file redirection + tailing (NOT .NET event handlers). Event-based capture
# (add_OutputDataReceived) runs the callback on a background thread with no PowerShell
# runspace, which hard-crashes Windows PowerShell 5.1 / the PS2EXE build the moment the
# child process emits output. File tailing is crash-safe and still streams live output.
function Invoke-LoggedCommand {
    param([string]$Command, [string]$Description)
    if ($script:cancelRequested) { return $null }
    Write-Log ">>> $Description"
    Write-Log "CMD: $Command"
    Set-Status "Running: $Description..."
    $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()

    try {
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $Command" `
            -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
            -WindowStyle Hidden -PassThru
        $script:currentProcess = $proc

        # Tail the output file and stream new content to the log panel (crash-safe, same thread)
        $readPos = 0
        while (-not $proc.HasExited) {
            $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
            Start-Sleep -Milliseconds 300
            if (Test-Path $outFile) {
                try {
                    $fs = [System.IO.File]::Open($outFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    $sr = New-Object System.IO.StreamReader($fs)
                    [void]$sr.BaseStream.Seek($readPos, [System.IO.SeekOrigin]::Begin)
                    $chunk = $sr.ReadToEnd()
                    $readPos = $sr.BaseStream.Position
                    $sr.Close(); $fs.Close()
                    if ($chunk) { $outputLog.AppendText($chunk); $outputLog.ScrollToEnd() }
                } catch { }
            }
        }
        # Flush any remaining output after exit
        Start-Sleep -Milliseconds 200
        if (Test-Path $outFile) {
            try {
                $fs = [System.IO.File]::Open($outFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $sr = New-Object System.IO.StreamReader($fs)
                [void]$sr.BaseStream.Seek($readPos, [System.IO.SeekOrigin]::Begin)
                $chunk = $sr.ReadToEnd()
                $sr.Close(); $fs.Close()
                if ($chunk) { $outputLog.AppendText($chunk); $outputLog.ScrollToEnd() }
            } catch { }
        }

        if ($script:cancelRequested) {
            Write-Log "CANCELLED by user."
            Set-Status "Cancelled: $Description"
            return $null
        }

        # Build full result from stdout + stderr
        $result = Get-Content $outFile -Raw -ErrorAction SilentlyContinue
        $errText = Get-Content $errFile -Raw -ErrorAction SilentlyContinue
        if ($errText -and $errText.Trim()) {
            $outputLog.AppendText($errText)
            $outputLog.ScrollToEnd()
            $result = "$result`r`n$errText"
        }

        # Write full result to log file
        $timestamp = Get-Date -Format "HH:mm:ss"
        Add-Content -Path $script:logFilePath -Value "[$timestamp] $result" -Encoding UTF8

        Set-Status "Completed: $Description"
        return $result
    }
    catch {
        Write-Log "ERROR: $_"
        Set-Status "Failed: $Description"
        return $null
    }
    finally {
        $script:currentProcess = $null
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
        Remove-Item $errFile -Force -ErrorAction SilentlyContinue
    }
}

# Helper: run diskpart script (non-blocking UI with cancel support)
function Invoke-Diskpart {
    param([string[]]$Commands, [string]$Description)
    if ($script:cancelRequested) { return $null }
    $tempFile = [System.IO.Path]::GetTempFileName()
    $Commands | Set-Content -Path $tempFile -Encoding ASCII
    Write-Log ">>> $Description"
    Write-Log ("DISKPART SCRIPT:`r`n" + ($Commands -join "`r`n"))
    Set-Status "Running Diskpart: $Description..."
    $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

    $outFile = [System.IO.Path]::GetTempFileName()

    try {
        $proc = Start-Process -FilePath "diskpart" -ArgumentList "/s $tempFile" `
            -RedirectStandardOutput $outFile -WindowStyle Hidden -PassThru
        $script:currentProcess = $proc

        while (-not $proc.HasExited) {
            $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
            Start-Sleep -Milliseconds 200
        }

        if ($script:cancelRequested) {
            Write-Log "CANCELLED by user."
            Set-Status "Cancelled: $Description"
            return $null
        }

        $result = ""
        if (Test-Path $outFile) { $result = Get-Content $outFile -Raw -ErrorAction SilentlyContinue }
        Write-Log $result
        Set-Status "Completed: $Description"
        return $result
    }
    catch {
        Write-Log "ERROR: $_"
        Set-Status "Failed: $Description"
        return $null
    }
    finally {
        $script:currentProcess = $null
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    }
}

# Helper: show red warning dialog with override option
# Returns $true if user overrides, $false if user cancels
function Show-RedWarning {
    param(
        [string]$Title,
        [string]$Message,
        [string]$OverrideText
    )

    $warnXaml = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"' +
        ' Title="' + $Title + '" Height="340" Width="520"' +
        ' WindowStartupLocation="CenterOwner" ResizeMode="NoResize"' +
        ' Background="#2D0000" Foreground="White">' +
        '<Grid Margin="20">' +
        '<Grid.RowDefinitions>' +
        '<RowDefinition Height="Auto"/>' +
        '<RowDefinition Height="*"/>' +
        '<RowDefinition Height="Auto"/>' +
        '<RowDefinition Height="Auto"/>' +
        '</Grid.RowDefinitions>' +
        '<Border Grid.Row="0" Background="#FF0000" CornerRadius="6" Padding="12,8" Margin="0,0,0,15">' +
        '<TextBlock Text="WARNING" FontSize="20" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center"/>' +
        '</Border>' +
        '<TextBlock Grid.Row="1" TextWrapping="Wrap" FontSize="13" Foreground="#FFCCCC" Margin="0,0,0,15" Name="MsgBlock"/>' +
        '<Button Grid.Row="2" Content="Go Back and Select Correct Drive"' +
        ' Height="40" FontSize="13" FontWeight="Bold"' +
        ' Background="#4CAF50" Foreground="White" BorderThickness="0"' +
        ' Cursor="Hand" Margin="0,0,0,8" Name="BtnGoBack"/>' +
        '<Button Grid.Row="3" FontSize="11"' +
        ' Height="35" Background="#550000" Foreground="#FF6666"' +
        ' BorderBrush="#FF0000" BorderThickness="1" Cursor="Hand"' +
        ' Name="BtnOverride"/>' +
        '</Grid></Window>'

    $warnReader = New-Object System.Xml.XmlNodeReader ([xml]$warnXaml)
    $warnWindow = [Windows.Markup.XamlReader]::Load($warnReader)
    $warnWindow.Owner = $window

    # Set dynamic content
    $msgBlock = $warnWindow.FindName("MsgBlock")
    $msgBlock.Text = $Message

    $goBackBtn = $warnWindow.FindName("BtnGoBack")
    $overrideBtn = $warnWindow.FindName("BtnOverride")
    $overrideBtn.Content = $OverrideText

    $script:overrideResult = $false

    $goBackBtn.Add_Click({
        $script:overrideResult = $false
        $warnWindow.Close()
    })

    $overrideBtn.Add_Click({
        $secondConfirm = [System.Windows.MessageBox]::Show(
            "Are you ABSOLUTELY SURE?`n`nRunning this command on the wrong drive can cause irreversible damage.",
            "FINAL CONFIRMATION", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Stop)
        if ($secondConfirm -eq "Yes") {
            $script:overrideResult = $true
            $warnWindow.Close()
        }
    })

    $warnWindow.ShowDialog() | Out-Null
    return $script:overrideResult
}

# Helper: validate Windows volume selection (returns $true to proceed, $false to block)
function Test-WindowsVolume {
    param([string]$DriveLetter)
    $winDir = $DriveLetter + ':\Windows'
    if (-not (Test-Path $winDir)) {
        # Show red warning dialog with override
        $result = Show-RedWarning -Title "INVALID WINDOWS VOLUME" `
            -Message ("CRITICAL WARNING: Drive " + $DriveLetter + ": does NOT contain a \Windows folder.`n`nRunning commands against the wrong volume can cause further damage to the VM and make recovery harder.`n`nPlease select the correct Windows Volume.") `
            -OverrideText ("Override and use " + $DriveLetter + ": anyway (NOT RECOMMENDED)")
        return $result
    }
    return $true
}

# Helper: validate System partition selection (returns $true to proceed, $false to block)
function Test-SystemPartition {
    param([string]$DriveLetter)
    $bootDir = $DriveLetter + ':\boot'
    $bootmgr = $DriveLetter + ':\bootmgr'
    $efiDir  = $DriveLetter + ':\EFI'
    if (-not (Test-Path $bootDir) -and -not (Test-Path $bootmgr) -and -not (Test-Path $efiDir)) {
        $result = Show-RedWarning -Title "INVALID SYSTEM PARTITION" `
            -Message ("CRITICAL WARNING: Drive " + $DriveLetter + ": does NOT contain \boot, \bootmgr, or \EFI.`n`nRunning commands against the wrong partition can corrupt boot data and make recovery impossible.`n`nPlease select the correct System Partition.") `
            -OverrideText ("Override and use " + $DriveLetter + ": anyway (NOT RECOMMENDED)")
        return $result
    }
    return $true
}

# Populate disk list on load
$window.Add_Loaded({
    Write-Log "Azure Rescue VM ToolKit started."
    Write-Log "Scanning for available disks..."
    $result = Invoke-Diskpart -Commands @("list disk") -Description "Listing disks"

    if (-not $result) {
        Write-Log "WARNING: Could not read disk list (diskpart returned no output)."
        return
    }

    # Parse disk numbers from output (match lines like "  Disk 0    Online")
    $diskNumbers = [regex]::Matches($result, '(?m)^\s+Disk\s+(\d+)\s') | ForEach-Object { $_.Groups[1].Value }
    $diskNumbers = $diskNumbers | Select-Object -Unique
    foreach ($d in $diskNumbers) {
        $diskCombo.Items.Add($d) | Out-Null
    }
    if ($diskCombo.Items.Count -gt 0) {
        Write-Log "Found $($diskCombo.Items.Count) disk(s). Select the attached rescue disk."
    }
    else {
        Write-Log "WARNING: No disks detected. Ensure the problematic disk is attached."
    }
})

# Enable/disable action buttons when drive letter combos change
$enableActions = {
    if ($script:isRunning) { return }
    $hasWin = $winVolCombo.SelectedItem -ne $null
    $hasSys = $sysPartCombo.SelectedItem -ne $null
    $btnDism.IsEnabled    = $hasWin
    $localDrv = $env:SystemDrive -replace ':', ''
    $isAttachedE = $hasWin -and ($winVolCombo.SelectedItem -ne $localDrv)
    $chkRevertPending.IsEnabled = $isAttachedE
    if (-not $isAttachedE) { $chkRevertPending.IsChecked = $false }
    $btnSfc.IsEnabled     = $hasWin
    $btnChkdsk.IsEnabled  = $hasWin
    $btnBcd.IsEnabled     = $hasWin -and $hasSys
    $btnSearchFilters.IsEnabled = $hasWin
    $btnGetPackages.IsEnabled = $hasWin
    $btnRemovePackage.IsEnabled = $hasWin
    $btnRemoveFilter.IsEnabled = $hasWin
    $btnOffline.IsEnabled = ($hasWin -or $hasSys -or (-not [string]::IsNullOrEmpty($diskCombo.Text.Trim()))) -and (-not $script:offlinedDisks.ContainsKey($diskCombo.Text.Trim()))
    # Advanced Boot Options require Windows volume
    $btnSafeMode.IsEnabled    = $hasWin
    $btnSafeModeNet.IsEnabled = $hasWin
    $btnSafeModeCmd.IsEnabled = $hasWin
    $btnLKGC.IsEnabled        = $hasWin
    $btnDSRM.IsEnabled        = $hasWin
    $btnNoDriverSig.IsEnabled = $hasWin
    $btnNormalBoot.IsEnabled  = $hasWin
    $btnRevertLetters.IsEnabled = ($script:assignedLetters.Count -gt 0)
    if ($hasWin -and $hasSys) {
        Set-Status "Ready - Windows: $($winVolCombo.SelectedItem) | System: $($sysPartCombo.SelectedItem)"
    }
    Set-RevertPendingOverride
}
$winVolCombo.Add_SelectionChanged($enableActions)
$sysPartCombo.Add_SelectionChanged($enableActions)
$chkRevertPending.Add_Checked($enableActions)
$chkRevertPending.Add_Unchecked($enableActions)

# ==================== READ PARTITIONS ====================
$btnReadParts.Add_Click({
    Start-GuardedAction {
    $diskNum = $diskCombo.Text.Trim()
    if ([string]::IsNullOrEmpty($diskNum)) {
        [System.Windows.MessageBox]::Show("Please select or enter a disk number.", "No Disk Selected",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    Write-Log "=========================================="
    Write-Log "READING PARTITIONS FOR DISK $diskNum"
    Write-Log "=========================================="

    # Step 1: Bring disk online and clear readonly
    Invoke-Diskpart -Commands @(
        "select disk $diskNum",
        "online disk",
        "attributes disk clear readonly"
    ) -Description "Bringing Disk $diskNum online"

    # Disk is back online - clear any prior 'offlined' flag so the Offline button re-enables
    if ($script:offlinedDisks.ContainsKey($diskNum)) { $script:offlinedDisks.Remove($diskNum) | Out-Null }

    # Step 2: Get partition list
    $partResult = Invoke-Diskpart -Commands @(
        "select disk $diskNum",
        "list partition"
    ) -Description "Listing partitions on Disk $diskNum"

    # Parse partitions
    if (-not $partResult) {
        Write-Log "WARNING: Could not read partition list for Disk $diskNum (no output). It may have been cancelled or the disk is inaccessible."
        return
    }
    $partitions = [regex]::Matches($partResult, 'Partition (\d+)\s+(\w+)\s+(\d+\s+\w+)')
    if ($partitions.Count -eq 0) {
        Write-Log "WARNING: No partitions found on Disk $diskNum."
        return
    }

    # Step 3: Assign drive letters to all partitions
    # Get currently used drive letters
    $usedLetters = @()
    $volResult = Invoke-Diskpart -Commands @("list volume") -Description "Checking used drive letters"
    if ($volResult) {
        $volMatches = [regex]::Matches($volResult, 'Volume \d+\s+([A-Z])\s')
        foreach ($m in $volMatches) { $usedLetters += $m.Groups[1].Value }
    }

    # Available letters (skip A, B, C and already used ones)
    $availableLetters = 68..90 | ForEach-Object { [char]$_ } | Where-Object { [string]$_ -notin $usedLetters }
    $letterIndex = 0

    $script:assignedLetters = @{}
    $partitionData = @()

    foreach ($part in $partitions) {
        $partNum  = $part.Groups[1].Value
        $partType = $part.Groups[2].Value
        $partSize = $part.Groups[3].Value.Trim()
        $wasAssignedByUs = $false
        $letter = "N/A"

        # Step 3a: Check if partition already has a drive letter
        $detailResult = Invoke-Diskpart -Commands @(
            "select disk $diskNum",
            "select partition $partNum",
            "detail partition"
        ) -Description "Getting detail for Partition $partNum"
        if ($script:cancelRequested) { return }

        $existingLetter = [regex]::Match($detailResult, '\*?\s+Volume \d+\s+([A-Z])\s')
        if ($existingLetter.Success) {
            # Partition already has a drive letter — keep it
            $letter = $existingLetter.Groups[1].Value
            Write-Log "  Partition $partNum already has drive letter ${letter}: — keeping it"
        }
        elseif ($letterIndex -lt $availableLetters.Count) {
            # No existing letter — assign one
            $newLetter = [string]$availableLetters[$letterIndex]
            $assignResult = Invoke-Diskpart -Commands @(
                "select disk $diskNum",
                "select partition $partNum",
                "assign letter=$newLetter"
            ) -Description "Assigning letter $newLetter to Partition $partNum"
            if ($script:cancelRequested) { return }

            if ($assignResult -match "successfully assigned") {
                $letter = $newLetter
                $letterIndex++
                $wasAssignedByUs = $true
                $script:assignedLetters[$partNum] = $letter
                Write-Log "  Partition $partNum had no letter — assigned ${letter}:"
            }
            else {
                Write-Log "  Partition $partNum — could not assign letter (may be a reserved/hidden partition)"
                $letterIndex++
            }
        }
        else {
            Write-Log "  Partition $partNum — no available drive letters remaining"
        }

        # Get volume label from the detail result already retrieved (or re-fetch if assigned new letter)
        $labelDetail = $detailResult
        if ($wasAssignedByUs) {
            $labelDetail = Invoke-Diskpart -Commands @(
                "select disk $diskNum",
                "select partition $partNum",
                "detail partition"
            ) -Description "Getting label for Partition $partNum"
        }
        $label = ""
        if ($labelDetail) {
            $labelMatch = [regex]::Match($labelDetail, '\*?\s+Volume \d+\s+[A-Z]?\s+([\w\s\-]+?)\s{2,}')
            if ($labelMatch.Success) {
                $label = $labelMatch.Groups[1].Value.Trim()
            }
        }

        # Determine original vs assigned display values
        $originalLetter = if ($wasAssignedByUs) { "No Drive Letter" } else { $letter }
        $assignedLetter = if ($wasAssignedByUs) { $letter } else { "-" }

        $partitionData += [PSCustomObject]@{
            Number         = $partNum
            OriginalLetter = $originalLetter
            AssignedLetter = $assignedLetter
            DriveLetter    = $letter
            Type           = $partType
            Size           = $partSize
            Label          = $label
        }
    }

    # Display in grid
    $partitionGrid.ItemsSource = $partitionData

    # Populate drive letter combos
    $winVolCombo.Items.Clear()
    $sysPartCombo.Items.Clear()
    $letters = $partitionData | Where-Object { $_.DriveLetter -ne "N/A" } | Select-Object -ExpandProperty DriveLetter
    foreach ($l in $letters) {
        $winVolCombo.Items.Add($l) | Out-Null
        $sysPartCombo.Items.Add($l) | Out-Null
    }

    # Auto-detect Windows Volume and System Partition
    $detectedWin = $null
    $detectedSys = $null
    foreach ($l in $letters) {
        $winPath = $l + ':\Windows'
        $bcdPath = $l + ':\boot\BCD'
        $efiBcdPath = $l + ':\EFI\Microsoft\Boot\BCD'
        $bootmgrPath = $l + ':\bootmgr'

        if ((Test-Path $winPath) -and -not $detectedWin) {
            $detectedWin = $l
            Write-Log "Auto-detected Windows Volume: ${l}:\ (found \Windows)"
        }
        if (((Test-Path $bcdPath) -or (Test-Path $efiBcdPath) -or (Test-Path $bootmgrPath)) -and -not $detectedSys) {
            $detectedSys = $l
            Write-Log "Auto-detected System Partition: ${l}:\ (found BCD/bootmgr)"
        }
    }

    # If no separate system partition found, check if BCD is on the Windows volume
    if ($detectedWin -and -not $detectedSys) {
        $winBcd = $detectedWin + ':\boot\BCD'
        $winEfiBcd = $detectedWin + ':\EFI\Microsoft\Boot\BCD'
        if ((Test-Path $winBcd) -or (Test-Path $winEfiBcd)) {
            $detectedSys = $detectedWin
            Write-Log "No separate System Partition found. BCD is on Windows Volume ${detectedWin}: (single-partition disk)."
        }
    }

    # Auto-select in dropdowns
    if ($detectedWin) {
        $winVolCombo.SelectedItem = $detectedWin
    }
    if ($detectedSys) {
        $sysPartCombo.SelectedItem = $detectedSys
    }

    Write-Log "=========================================="
    if ($detectedWin -and $detectedSys) {
        if ($detectedWin -eq $detectedSys) {
            Write-Log "Single-partition disk detected: Windows and BCD both on ${detectedWin}:"
        } else {
            Write-Log "Auto-selected: Windows=${detectedWin}: | System=${detectedSys}:"
        }
        Write-Log "Verify the selections above are correct before running commands."
    } else {
        Write-Log "Partition scan complete. Select the Windows Volume and System Partition above."
    }
    if ($script:assignedLetters.Count -gt 0) {
        $assignedList = ($script:assignedLetters.GetEnumerator() | ForEach-Object { "Partition $($_.Key) = $($_.Value):" }) -join ', '
        Write-Log "Drive letters assigned by this tool: $assignedList"
        $btnRevertLetters.IsEnabled = $true
    }
    Write-Log "=========================================="
    if ($detectedWin -and $detectedSys) {
        Set-Status ("Auto-detected - Windows: " + $detectedWin + " | System: " + $detectedSys)
    } else {
        Set-Status "Partitions loaded - select Windows Volume and System Partition"
    }
    }
})

# ==================== DISM SCAN/REPAIR ====================
# Helper: detect DISM error 183 (image already being serviced) and guide the user.
function Test-DismBusy {
    param([string]$Result)
    if ($Result -and $Result -match '(?i)(error:\s*183|being serviced by another DISM|currently being serviced)') {
        Write-Log "DISM ERROR 183: The image is locked by another (or a previous, interrupted) DISM operation."
        [System.Windows.MessageBox]::Show(
            ("DISM reports the image is currently being serviced by another DISM operation (error 183).`n`n" +
             "This usually means a previous DISM run did not finish cleanly (e.g. the tool was closed or the operation was interrupted).`n`n" +
             "To clear it:`n" +
             "1. Make sure no other DISM window/operation is running on this VM.`n" +
             "2. Tick 'Revert Pending Actions (Offline only)' and click DISM once to clear the pending servicing state.`n" +
             "3. Then retry ScanHealth / RestoreHealth.`n`n" +
             "If it still persists, detach and reattach the disk (or reboot the rescue VM) to release the lock."),
            "DISM Image Busy (Error 183)", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        Set-Status "DISM image busy (error 183) - clear pending actions and retry"
        return $true
    }
    return $false
}

$btnDism.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    # Detect if targeting local rescue VM or attached disk
    $localDrive = $env:SystemDrive -replace ':', ''
    $isLocal = ($winDrive -eq $localDrive)
    $revertPending = $chkRevertPending.IsChecked -eq $true

    if ($revertPending -and -not $isLocal) {
        # ── Revert Pending Actions (Offline only) ──
        $scratchDir = Get-ScratchDir

        Write-Log "=========================================="
        Write-Log "DISM REVERT PENDING ACTIONS (Offline)"
        Write-Log "=========================================="
        Write-Log "Target: Attached disk ($winDrive`:)"
        Write-Log "Scratch directory (rescue VM): $scratchDir"

        $dismCmd = 'Dism /Image:' + $winDrive + ':\ /Cleanup-Image /RevertPendingActions /ScratchDir:' + $scratchDir
        $confirm = [System.Windows.MessageBox]::Show(
            "The selected volume ($winDrive`:) is on the attached disk.`n`nThis will run DISM RevertPendingActions in OFFLINE mode:`n$dismCmd`n`nThis reverts pending Windows Update actions on the attached OS disk.",
            "Confirm DISM Revert Pending (Offline)", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne "Yes") { return }

        $revertResult = Invoke-LoggedCommand -Command $dismCmd -Description ('DISM Revert Pending on ' + $winDrive + ':')
        if ($script:cancelRequested) { return }
        if (Test-DismBusy $revertResult) { return }
        Write-Log "DISM Revert Pending Actions complete."

    } elseif ($isLocal) {
        # ── ScanHealth + RestoreHealth (Online) ──
        $scanCmd = 'Dism /Online /Cleanup-Image /ScanHealth'
        $confirm = [System.Windows.MessageBox]::Show(
            "The selected volume ($winDrive`:) is the local VM.`n`nThis will run DISM ScanHealth in ONLINE mode:`n$scanCmd`n`nIf corruption is found, you will be prompted to run RestoreHealth.`nThis may take several minutes.",
            "Confirm DISM Scan (Online)", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne "Yes") { return }

        Write-Log "=========================================="
        Write-Log "DISM SCANHEALTH (Online - Local VM)"
        Write-Log "=========================================="
        Write-Log "Target: Local VM ($winDrive`:)"
        $scanResult = Invoke-LoggedCommand -Command $scanCmd -Description "DISM ScanHealth (Online)"
        if ($script:cancelRequested) { return }
        if (Test-DismBusy $scanResult) { return }

        if ($scanResult -and $scanResult -match '(?i)the component store is repairable') {
            Write-Log "CORRUPTION DETECTED — prompting for RestoreHealth."
            $repairConfirm = [System.Windows.MessageBox]::Show(
                "DISM ScanHealth found corruption.`n`nRun RestoreHealth to repair?`nCommand: Dism /Online /Cleanup-Image /RestoreHealth",
                "Corruption Found", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            if ($repairConfirm -eq "Yes") {
                Write-Log "=========================================="
                Write-Log "DISM RESTOREHEALTH (Online)"
                Write-Log "=========================================="
                $restoreResult = Invoke-LoggedCommand -Command 'Dism /Online /Cleanup-Image /RestoreHealth' -Description "DISM RestoreHealth (Online)"
                if (Test-DismBusy $restoreResult) { return }
                Write-Log "DISM RestoreHealth complete."
            }
        } else {
            Write-Log "No corruption detected by ScanHealth."
        }
        Write-Log "DISM online scan complete."

    } else {
        # ── ScanHealth + RestoreHealth (Offline) ──
        $scratchDir = Get-ScratchDir

        $scanCmd = 'Dism /Image:' + $winDrive + ':\ /Cleanup-Image /ScanHealth /ScratchDir:' + $scratchDir
        $confirm = [System.Windows.MessageBox]::Show(
            "The selected volume ($winDrive`:) is on the attached disk.`n`nThis will run DISM ScanHealth in OFFLINE mode:`n$scanCmd`n`nIf corruption is found, you will be prompted to run RestoreHealth.`nThis may take several minutes.",
            "Confirm DISM Scan (Offline)", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne "Yes") { return }

        Write-Log "=========================================="
        Write-Log "DISM SCANHEALTH (Offline - Attached Disk)"
        Write-Log "=========================================="
        Write-Log "Target: Attached disk ($winDrive`:)"
        $scanResult = Invoke-LoggedCommand -Command $scanCmd -Description ('DISM ScanHealth (Offline) on ' + $winDrive + ':')
        if ($script:cancelRequested) { return }
        if (Test-DismBusy $scanResult) { return }

        if ($scanResult -and $scanResult -match '(?i)the component store is repairable') {
            Write-Log "CORRUPTION DETECTED — prompting for RestoreHealth."
            $restoreCmd = 'Dism /Image:' + $winDrive + ':\ /Cleanup-Image /RestoreHealth /ScratchDir:' + $scratchDir
            $repairConfirm = [System.Windows.MessageBox]::Show(
                "DISM ScanHealth found corruption.`n`nRun RestoreHealth to repair?`nCommand: $restoreCmd",
                "Corruption Found", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            if ($repairConfirm -eq "Yes") {
                Write-Log "=========================================="
                Write-Log "DISM RESTOREHEALTH (Offline)"
                Write-Log "=========================================="
                $restoreResult = Invoke-LoggedCommand -Command $restoreCmd -Description ('DISM RestoreHealth (Offline) on ' + $winDrive + ':')
                if (Test-DismBusy $restoreResult) { return }
                Write-Log "DISM RestoreHealth complete."
            }
        } else {
            Write-Log "No corruption detected by ScanHealth."
        }
        Write-Log "DISM offline scan complete."
    }
    }
})

# ==================== SFC SCAN ====================
$btnSfc.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    $sysDrive = $sysPartCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    # Detect if targeting local rescue VM or attached disk
    $localDrive = $env:SystemDrive -replace ':', ''
    $isLocal = ($winDrive -eq $localDrive)

    if ($isLocal) {
        # Online SFC on the local rescue VM
        $sfcCmd = 'sfc /scannow'
        $confirm = [System.Windows.MessageBox]::Show(
            "The selected Windows Volume ($winDrive`:) is the local VM.`n`nThis will run SFC in ONLINE mode:`n$sfcCmd`n`nThis scans and repairs the local VM's system files.`nThis may take several minutes.",
            "Confirm SFC (Online)", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne "Yes") { return }

        Write-Log "=========================================="
        Write-Log "SFC ONLINE SCAN (Local VM)"
        Write-Log "=========================================="
        Write-Log "Target: Local VM ($winDrive`:)"
        Invoke-LoggedCommand -Command $sfcCmd -Description "SFC Online Scan (Local VM)"
        Write-Log "SFC online scan complete. Check output above for results."
    } else {
        # Offline SFC on the attached problematic disk
        if ([string]::IsNullOrWhiteSpace([string]$sysDrive)) {
            [System.Windows.MessageBox]::Show(
                "Offline SFC requires a System Partition.`n`nPlease select the System Partition (contains \boot or \EFI) from the dropdown before running SFC on an attached disk.",
                "System Partition Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }
        if (-not (Test-SystemPartition $sysDrive)) { return }
        $sfcCmd = 'sfc /scannow /offbootdir=' + $sysDrive + ':\ /offwindir=' + $winDrive + ':\Windows'
        $confirm = [System.Windows.MessageBox]::Show(
            "The selected Windows Volume ($winDrive`:) is on the attached disk.`n`nThis will run SFC in OFFLINE mode:`n$sfcCmd`n`nThis scans and repairs the attached OS disk's system files.`nThis may take several minutes.",
            "Confirm SFC (Offline)", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        if ($confirm -ne "Yes") { return }

        Write-Log "=========================================="
        Write-Log "SFC OFFLINE SCAN (Attached Disk)"
        Write-Log "=========================================="
        Write-Log "Target: Attached disk — Windows=$winDrive`: | System=$sysDrive`:"
        Invoke-LoggedCommand -Command $sfcCmd -Description "SFC Offline Scan"
        Write-Log "SFC offline scan complete. Check output above for results."
    }
    }
})

# ==================== CHKDSK ====================
$btnChkdsk.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }
    $chkCmd = "chkdsk ${winDrive}: /f /r"
    $confirm = [System.Windows.MessageBox]::Show(
        ('Run CHKDSK on drive ' + $winDrive + ':?' + "`n`nCommand:`n" + $chkCmd + "`n`nThis may take a long time depending on disk size."),
        "Confirm CHKDSK", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "CHKDSK"
    Write-Log "=========================================="
    Invoke-LoggedCommand -Command $chkCmd -Description ('CHKDSK on ' + $winDrive + ':')
    Write-Log "CHKDSK complete."
    }
})

# ==================== BCD REBUILD ====================
$btnBcd.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    $sysDrive = $sysPartCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }
    if (-not (Test-SystemPartition $sysDrive)) { return }
    $bcdbootCmd = 'bcdboot ' + $winDrive + ':\Windows /s ' + $sysDrive + ': /f ALL'
    $msgText = 'Rebuild BCD on System Partition ' + $sysDrive + ': using Windows from ' + $winDrive + ':?' + "`n`n"
    $msgText += "This will:`n1. Backup existing BCD to BCD.bak`n2. Rebuild BCD with bcdboot`n`n"
    $msgText += 'Commands:' + "`n" + 'ren <BCD store> BCD.bak' + "`n" + $bcdbootCmd
    $confirm = [System.Windows.MessageBox]::Show($msgText,
        "Confirm BCD Rebuild", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "BCD REBUILD"
    Write-Log "=========================================="

    # Backup existing BCD — check both BIOS (\boot\BCD) and UEFI (\EFI\Microsoft\Boot\BCD) locations
    $bcdCandidates = @(
        ($sysDrive + ':\boot\BCD'),
        ($sysDrive + ':\EFI\Microsoft\Boot\BCD')
    )
    $bcdPath = $bcdCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($bcdPath) {
        Write-Log "Backing up existing BCD at $bcdPath..."
        try {
            $bakPath = $bcdPath + '.bak'
            if (Test-Path $bakPath) {
                Remove-Item $bakPath -Force
                Write-Log "Removed old BCD.bak"
            }
            Rename-Item -Path $bcdPath -NewName "BCD.bak" -Force
            Write-Log "BCD backed up to $bakPath"
        }
        catch {
            Write-Log "WARNING: Could not backup BCD: $_"
            $proceed = [System.Windows.MessageBox]::Show(
                "Could not backup existing BCD. Continue anyway?",
                "BCD Backup Failed", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            if ($proceed -ne "Yes") { return }
        }
    }
    else {
        Write-Log ('No existing BCD found at ' + ($bcdCandidates -join ' or ') + ' - proceeding with rebuild.')
    }

    # Rebuild BCD
    Invoke-LoggedCommand -Command $bcdbootCmd -Description "BCD Rebuild"
    Write-Log "BCD rebuild complete."
    }
})

# ==================== SEARCH UPPER/LOWER FILTERS ====================
$btnSearchFilters.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    Write-Log "=========================================="
    Write-Log "SEARCHING UPPER/LOWER FILTERS"
    Write-Log "=========================================="

    $localDrv = $env:SystemDrive -replace ':', ''
    $isLocal = ($winDrive -eq $localDrv)

    $hiveName = "YOURRESCUE_FILTERS"
    $hiveLoaded = $false
    $classPath = $null

    if ($isLocal) {
        # Selected volume is THIS rescue VM's own system drive - query the live registry
        # directly. Do NOT load an offline hive (the SYSTEM hive is in use by the running OS).
        Write-Log "Selected volume $winDrive`: is this rescue VM's own system drive."
        Write-Log "Querying the LIVE registry directly (no offline hive load)."
        $controlSet = "CurrentControlSet"
        $classPath = "HKLM\SYSTEM\$controlSet\Control\Class"
    }
    else {
        $systemHive = $winDrive + ':\Windows\System32\config\SYSTEM'
        if (-not (Test-Path $systemHive)) {
            [System.Windows.MessageBox]::Show(
                "Cannot find SYSTEM registry hive at:`n$systemHive",
                "SYSTEM Hive Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }

        # Load the offline SYSTEM hive
        Write-Log "Loading SYSTEM hive from $systemHive..."
        $loadResult = Invoke-LoggedCommand -Command ('reg load "HKLM\' + $hiveName + '" "' + $systemHive + '"') -Description "Loading SYSTEM hive for filter search"
        if ($script:cancelRequested) { return }

        # Verify hive loaded by attempting a query on it
        $verifyResult = Invoke-LoggedCommand -Command ('reg query "HKLM\' + $hiveName + '\Select" /v Current') -Description "Reading current ControlSet"
        if ($script:cancelRequested) { return }

        # Check if we got a valid ControlSet response
        $csNum = 1
        $hiveValid = $false
        $csMatch = [regex]::Match([string]$verifyResult, 'Current\s+REG_DWORD\s+0x([0-9a-fA-F]+)')
        if ($csMatch.Success) {
            $csNum = [int]("0x" + $csMatch.Groups[1].Value)
            $hiveValid = $true
        }

        if (-not $hiveValid) {
            Write-Log "ERROR: Failed to load or read the SYSTEM registry hive."
            Write-Log "The hive may be in use or corrupted."
            # Try to unload in case it was partially loaded
            Invoke-LoggedCommand -Command ('reg unload "HKLM\' + $hiveName + '"') -Description "Cleanup: Unloading SYSTEM hive"
            Set-Status "Filter search failed - could not load registry hive"
            return
        }
        $hiveLoaded = $true
        $controlSet = ('ControlSet{0:D3}' -f $csNum)
        $classPath = "HKLM\$hiveName\$controlSet\Control\Class"
    }

    try {

    Write-Log "Using $controlSet"
    Write-Log "Scanning $classPath for UpperFilters and LowerFilters..."
    Write-Log ""

    # Enumerate all Class GUIDs
    $enumResult = Invoke-LoggedCommand -Command ('reg query "' + $classPath + '"') -Description "Enumerating device Class GUIDs"
    if ($script:cancelRequested) { return }

    $foundAny = $false
    $filterResults = @()

    if ($enumResult) {
        # Each line is a subkey path like HKLM\YOURRESCUE_FILTERS\ControlSet001\Control\Class\{GUID}
        $guidKeys = $enumResult -split "`r`n" | Where-Object { $_ -match '\{[0-9A-Fa-f\-]+\}' } | ForEach-Object { $_.Trim() }

        foreach ($guidKey in $guidKeys) {
            if ($script:cancelRequested) { break }

            # Extract the GUID for display
            $guidMatch = [regex]::Match($guidKey, '\{[0-9A-Fa-f\-]+\}')
            $guid = if ($guidMatch.Success) { $guidMatch.Value } else { $guidKey }

            # Check for UpperFilters
            $upperResult = Invoke-LoggedCommand -Command ('reg query "' + $guidKey + '" /v UpperFilters') -Description "Checking UpperFilters on $guid"
            if ($script:cancelRequested) { break }
            $upperMatch = [regex]::Match([string]$upperResult, 'UpperFilters\s+REG_MULTI_SZ\s+(.+)')
            if ($upperMatch.Success) {
                $filterValue = $upperMatch.Groups[1].Value.Trim()
                $foundAny = $true
                $filterResults += [PSCustomObject]@{
                    ClassGUID  = $guid
                    FilterType = "UpperFilters"
                    Values     = $filterValue
                }
                Write-Log "  FOUND: $guid → UpperFilters = $filterValue"
            }

            # Check for LowerFilters
            $lowerResult = Invoke-LoggedCommand -Command ('reg query "' + $guidKey + '" /v LowerFilters') -Description "Checking LowerFilters on $guid"
            if ($script:cancelRequested) { break }
            $lowerMatch = [regex]::Match([string]$lowerResult, 'LowerFilters\s+REG_MULTI_SZ\s+(.+)')
            if ($lowerMatch.Success) {
                $filterValue = $lowerMatch.Groups[1].Value.Trim()
                $foundAny = $true
                $filterResults += [PSCustomObject]@{
                    ClassGUID  = $guid
                    FilterType = "LowerFilters"
                    Values     = $filterValue
                }
                Write-Log "  FOUND: $guid → LowerFilters = $filterValue"
            }

            # Pump UI
            $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
    }

    # Unload hive
    } finally {
        if ($hiveLoaded) {
            Invoke-LoggedCommand -Command ('reg unload "HKLM\' + $hiveName + '"') -Description "Unloading SYSTEM hive"
        }
    }

    Write-Log ""
    Write-Log "=========================================="
    if ($foundAny) {
        Write-Log "FILTER SEARCH RESULTS:"
        Write-Log "=========================================="
        foreach ($f in $filterResults) {
            Write-Log ("  Class: " + $f.ClassGUID + " | " + $f.FilterType + " = " + $f.Values)
        }
        Write-Log ""
        Write-Log "Total entries found: $($filterResults.Count)"
        Write-Log "Review the filters above. Third-party filters can cause boot failures."
    } else {
        Write-Log "No UpperFilters or LowerFilters entries found in any device Class GUID."
        Write-Log "=========================================="
    }
    Set-Status "Filter search complete - $($filterResults.Count) entries found"
    }
})

# ==================== REMOVE FILTER ====================
# Removes the UpperFilters / LowerFilters value from a device Class GUID key.
# The Class GUID is taken from the shared text box. The Class key is exported to a
# .reg backup BEFORE any value is deleted.
$btnRemoveFilter.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    $guidInput = $txtPackageName.Text.Trim()
    if ([string]::IsNullOrEmpty($guidInput)) {
        [System.Windows.MessageBox]::Show(
            "Please enter a device Class GUID in the text box.`n`nTip: click 'Search Filters' first to list the Class GUIDs that have Upper/Lower filters, then copy one here.`n`nExample: {4D36E967-E325-11CE-BFC1-08002BE10318}",
            "No Class GUID Specified", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # Validate / normalize the GUID (accept with or without braces)
    if ($guidInput -notmatch '^\{?[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}?$') {
        [System.Windows.MessageBox]::Show(
            "Invalid Class GUID.`n`nExpected a GUID like {4D36E967-E325-11CE-BFC1-08002BE10318}.",
            "Invalid Class GUID", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    $guidClean = $guidInput.Trim('{','}').ToUpper()
    $guid = '{' + $guidClean + '}'

    Write-Log "=========================================="
    Write-Log "REMOVE FILTER"
    Write-Log "=========================================="
    Write-Log "Class GUID: $guid"

    $localDrv = $env:SystemDrive -replace ':', ''
    $isLocal = ($winDrive -eq $localDrv)

    $hiveName = "YOURRESCUE_RMFILTER"
    $hiveLoaded = $false
    $classKey = $null

    if ($isLocal) {
        Write-Log "Selected volume $winDrive`: is this rescue VM's own system drive - editing the LIVE registry directly."
        $classKey = "HKLM\SYSTEM\CurrentControlSet\Control\Class\$guid"
    }
    else {
        $systemHive = $winDrive + ':\Windows\System32\config\SYSTEM'
        if (-not (Test-Path $systemHive)) {
            [System.Windows.MessageBox]::Show(
                "Cannot find SYSTEM registry hive at:`n$systemHive",
                "SYSTEM Hive Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        Write-Log "Loading SYSTEM hive from $systemHive..."
        Invoke-LoggedCommand -Command ('reg load "HKLM\' + $hiveName + '" "' + $systemHive + '"') -Description "Loading SYSTEM hive for filter removal" | Out-Null
        if ($script:cancelRequested) { return }
        $verifyResult = Invoke-LoggedCommand -Command ('reg query "HKLM\' + $hiveName + '\Select" /v Current') -Description "Reading current ControlSet"
        if ($script:cancelRequested) { return }
        $csNum = 1
        $csMatch = [regex]::Match([string]$verifyResult, 'Current\s+REG_DWORD\s+0x([0-9a-fA-F]+)')
        if (-not $csMatch.Success) {
            Write-Log "ERROR: Failed to load or read the SYSTEM registry hive."
            Invoke-LoggedCommand -Command ('reg unload "HKLM\' + $hiveName + '"') -Description "Cleanup: Unloading SYSTEM hive" | Out-Null
            Set-Status "Remove Filter failed - could not load registry hive"
            return
        }
        $csNum = [int]("0x" + $csMatch.Groups[1].Value)
        $hiveLoaded = $true
        $controlSet = ('ControlSet{0:D3}' -f $csNum)
        $classKey = "HKLM\$hiveName\$controlSet\Control\Class\$guid"
    }

    try {
        # Confirm the Class key exists
        $keyResult = Invoke-LoggedCommand -Command ('reg query "' + $classKey + '"') -Description "Checking Class key $guid"
        if ($script:cancelRequested) { return }
        if (-not $keyResult -or $keyResult -match '(?i)unable to find|error') {
            Write-Log "Class GUID $guid was not found under Control\Class."
            [System.Windows.MessageBox]::Show(
                "The Class GUID $guid was not found under Control\Class on the selected Windows volume.",
                "Class GUID Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
            return
        }

        # Determine which filter values are present
        $upperRes = Invoke-LoggedCommand -Command ('reg query "' + $classKey + '" /v UpperFilters') -Description "Checking UpperFilters"
        if ($script:cancelRequested) { return }
        $lowerRes = Invoke-LoggedCommand -Command ('reg query "' + $classKey + '" /v LowerFilters') -Description "Checking LowerFilters"
        if ($script:cancelRequested) { return }
        $upperMatch = [regex]::Match([string]$upperRes, 'UpperFilters\s+REG_MULTI_SZ\s+(.+)')
        $lowerMatch = [regex]::Match([string]$lowerRes, 'LowerFilters\s+REG_MULTI_SZ\s+(.+)')
        $hasUpper = $upperMatch.Success
        $hasLower = $lowerMatch.Success

        if (-not $hasUpper -and -not $hasLower) {
            Write-Log "No UpperFilters or LowerFilters value present on $guid - nothing to remove."
            [System.Windows.MessageBox]::Show(
                "The Class GUID $guid has no UpperFilters or LowerFilters value, so there is nothing to remove.",
                "No Filters Present", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }

        $present = @()
        if ($hasUpper) { $present += "UpperFilters = " + $upperMatch.Groups[1].Value.Trim() }
        if ($hasLower) { $present += "LowerFilters = " + $lowerMatch.Groups[1].Value.Trim() }

        $confirm = [System.Windows.MessageBox]::Show(
            "Class GUID: $guid`n`nPresent filter value(s):`n" + ($present -join "`n") +
            "`n`nThe Class key will be backed up to a .reg file first, then you'll be asked which value(s) to delete.`n`nContinue?",
            "Remove Filter", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -ne "Yes") { return }

        # Back up the Class key BEFORE deleting anything
        $backupFile = Join-Path $script:scriptDir ("FilterBackup_" + $guidClean + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".reg")
        Write-Log "Backing up Class key to $backupFile ..."
        $exportRes = Invoke-LoggedCommand -Command ('reg export "' + $classKey + '" "' + $backupFile + '" /y') -Description "Backing up Class key"
        if ($script:cancelRequested) { return }
        if (-not (Test-Path $backupFile)) {
            Write-Log "ERROR: Registry backup failed - aborting removal (nothing was deleted)."
            [System.Windows.MessageBox]::Show(
                "The registry backup could not be created, so no filter was deleted.`n`nExpected backup file:`n$backupFile",
                "Backup Failed - Nothing Deleted", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        Write-Log "Backup created: $backupFile"

        $removedAny = $false

        if ($hasUpper) {
            $ans = [System.Windows.MessageBox]::Show(
                "Delete the UpperFilters value from $guid ?`n`nUpperFilters = " + $upperMatch.Groups[1].Value.Trim(),
                "Delete UpperFilters?", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            if ($ans -eq "Yes") {
                $delRes = Invoke-LoggedCommand -Command ('reg delete "' + $classKey + '" /v UpperFilters /f') -Description "Deleting UpperFilters"
                if ($delRes -match '(?i)success') { Write-Log "UpperFilters deleted."; $removedAny = $true }
                else { Write-Log "WARNING: UpperFilters deletion may have failed - check output above." }
            }
        }

        if ($hasLower) {
            $ans = [System.Windows.MessageBox]::Show(
                "Delete the LowerFilters value from $guid ?`n`nLowerFilters = " + $lowerMatch.Groups[1].Value.Trim(),
                "Delete LowerFilters?", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            if ($ans -eq "Yes") {
                $delRes = Invoke-LoggedCommand -Command ('reg delete "' + $classKey + '" /v LowerFilters /f') -Description "Deleting LowerFilters"
                if ($delRes -match '(?i)success') { Write-Log "LowerFilters deleted."; $removedAny = $true }
                else { Write-Log "WARNING: LowerFilters deletion may have failed - check output above." }
            }
        }

        if ($removedAny) {
            Write-Log ""
            Write-Log "Filter removal complete. Backup saved at: $backupFile"
            Write-Log "To restore, run:  reg import `"$backupFile`"  (after loading the offline hive if applicable)."
            $txtPackageName.Clear()
            Set-Status "Filter(s) removed from $guid"
        }
        else {
            Write-Log "No values were deleted. Backup file remains at: $backupFile"
            Set-Status "Remove Filter - no changes made"
        }
    }
    finally {
        if ($hiveLoaded) {
            Invoke-LoggedCommand -Command ('reg unload "HKLM\' + $hiveName + '"') -Description "Unloading SYSTEM hive" | Out-Null
        }
    }
    }
})

# ==================== CHECK PACKAGES ====================
$btnGetPackages.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    Write-Log "=========================================="
    Write-Log "CHECKING INSTALLED & STAGED PACKAGES"
    Write-Log "=========================================="

    # Get all packages (read-only enumeration - no /ScratchDir needed).
    # If the selected volume is this rescue VM's own system drive, /Image:C:\ is invalid
    # (DISM error 87) - use /Online to service the running OS instead.
    $localDrv = $env:SystemDrive -replace ':', ''
    if ($winDrive -eq $localDrv) {
        Write-Log "Selected volume $winDrive`: is this rescue VM's own system drive - using /Online."
        $dismCmd = 'Dism /Online /Get-Packages'
    }
    else {
        $dismCmd = 'Dism /Image:' + $winDrive + ':\ /Get-Packages'
    }
    Write-Log "Running: $dismCmd"
    $result = Invoke-LoggedCommand -Command $dismCmd -Description ('DISM Get-Packages on ' + $winDrive + ':')
    if ($script:cancelRequested) { return }

    if ($result) {
        # Parse and summarize packages by state
        $installed = ([regex]::Matches($result, '(?m)State\s*:\s*Installed')).Count
        $staged    = ([regex]::Matches($result, '(?m)State\s*:\s*Staged')).Count
        $pendingIR = ([regex]::Matches($result, '(?m)State\s*:\s*Install Pending')).Count
        $pendingUR = ([regex]::Matches($result, '(?m)State\s*:\s*Uninstall Pending')).Count
        $superseded = ([regex]::Matches($result, '(?m)State\s*:\s*Superseded')).Count

        Write-Log ""
        Write-Log "=========================================="
        Write-Log "PACKAGE SUMMARY"
        Write-Log "=========================================="
        Write-Log "  Installed          : $installed"
        Write-Log "  Staged             : $staged"
        Write-Log "  Install Pending    : $pendingIR"
        Write-Log "  Uninstall Pending  : $pendingUR"
        Write-Log "  Superseded         : $superseded"
        Write-Log "=========================================="

        if ($staged -gt 0 -or $pendingIR -gt 0 -or $pendingUR -gt 0) {
            Write-Log ""
            Write-Log "WARNING: Staged or Pending packages detected. These may be causing boot failures."
            Write-Log "Consider running DISM Revert Pending Actions to clear them."

            # List the problematic packages
            $lines = $result -split "`r?`n"
            $currentPkg = ""
            foreach ($line in $lines) {
                $pkgMatch = [regex]::Match($line, 'Package Identity\s*:\s*(.+)')
                if ($pkgMatch.Success) {
                    $currentPkg = $pkgMatch.Groups[1].Value.Trim()
                }
                $stateMatch = [regex]::Match($line, 'State\s*:\s*(Staged|Install Pending|Uninstall Pending)')
                if ($stateMatch.Success) {
                    $state = $stateMatch.Groups[1].Value
                    Write-Log "  [$state] $currentPkg"
                }
            }
        }
    } else {
        Write-Log "Could not retrieve package information."
    }
    Set-Status "Package check complete"
    }
})

# ==================== REMOVE PACKAGE ====================
$btnRemovePackage.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    $packageName = $txtPackageName.Text.Trim()
    if ([string]::IsNullOrEmpty($packageName)) {
        [System.Windows.MessageBox]::Show(
            "Please enter a package identity name in the text box.`n`nYou can find package names by clicking 'Check Packages' first.",
            "No Package Specified",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # Validate package name - only allow safe characters (alphanumeric, ~, ., _, -)
    if ($packageName -notmatch '^[A-Za-z0-9\.\-_~]+$') {
        [System.Windows.MessageBox]::Show(
            "Invalid package name. Package names should only contain letters, numbers, dots, hyphens, underscores, and tildes (~).`n`nExample: Package_for_KB5034441~31bf3856ad364e35~amd64~~10.0.1.1",
            "Invalid Package Name",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Are you sure you want to remove this package?`n`n$packageName`n`nThis action cannot be undone.",
        "Confirm Package Removal",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "REMOVING PACKAGE"
    Write-Log "=========================================="
    Write-Log "Package: $packageName"

    # If the selected volume is this rescue VM's own system drive, /Image:C:\ is invalid
    # (DISM error 87) - use /Online to service the running OS instead.
    $localDrv = $env:SystemDrive -replace ':', ''
    if ($winDrive -eq $localDrv) {
        Write-Log "Selected volume $winDrive`: is this rescue VM's own system drive - using /Online."
        $dismCmd = 'Dism /Online /Remove-Package /PackageName:' + $packageName
    }
    else {
        # Scratch directory on the rescue VM (not the customer disk)
        $scratchDir = Get-ScratchDir
        $dismCmd = 'Dism /Image:' + $winDrive + ':\ /Remove-Package /PackageName:' + $packageName + ' /ScratchDir:' + $scratchDir
    }
    Write-Log "Running: $dismCmd"
    $result = Invoke-LoggedCommand -Command $dismCmd -Description ('DISM Remove-Package: ' + $packageName)
    if ($script:cancelRequested) { return }

    if ($result -match 'successfully') {
        Write-Log ""
        Write-Log "SUCCESS: Package removed successfully."
        Write-Log "You may want to run 'Check Packages' again to verify."
        $txtPackageName.Clear()
    } elseif ($result -match '0x800f082f') {
        Write-Log ""
        Write-Log "ERROR 0x800f082f: The package could not be removed - no operation was performed."
        Write-Log "This almost always means the package is in a 'Staged' (pending) state, not 'Installed'."
        Write-Log "DISM /Remove-Package can only remove packages that are in the 'Installed' state."
        Write-Log "A staged package indicates the offline image has pending servicing operations"
        Write-Log "(e.g. a stuck / partially-applied update - a common no-boot cause)."
        Write-Log ""
        Write-Log "RECOMMENDED ACTION: Revert the pending actions instead of removing the package."
        Write-Log "  1. Tick the 'Revert Pending Actions (Offline only)' checkbox."
        Write-Log "  2. Click the DISM button to run: Dism /Image:$winDrive`:\ /Cleanup-Image /RevertPendingActions"
        Write-Log "  This discards the staged/pending changes and typically restores boot."
        [System.Windows.MessageBox]::Show(
            "DISM error 0x800f082f - no operation was performed.`n`n" +
            "The package '$packageName' is in a STAGED (pending) state, not 'Installed'. " +
            "DISM can only remove packages that are 'Installed', so nothing was removed.`n`n" +
            "A staged package means this offline image has pending servicing operations " +
            "(often a stuck update - a common no-boot cause).`n`n" +
            "RECOMMENDED: Tick 'Revert Pending Actions (Offline only)' and click the DISM button. " +
            "That runs DISM /Cleanup-Image /RevertPendingActions, which discards the staged/pending " +
            "changes and usually restores boot.",
            "Package Is Staged - Revert Pending Actions",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning)
    } elseif ($result -match '0x800f081f') {
        Write-Log ""
        Write-Log "ERROR 0x800f081f: Source files could not be found (CBS_E_SOURCE_MISSING)."
        Write-Log "The package name may be incorrect, or the component store is missing required files."
        Write-Log "Run 'Check Packages' to confirm the exact package identity and its state."
    } elseif ($result) {
        Write-Log ""
        Write-Log "DISM output received. Check above for details."
    } else {
        Write-Log "Package removal may have failed. Check output above."
    }
    Set-Status "Package removal complete"
    }
})

# ==================== DISK OFFLINE ====================
$btnOffline.Add_Click({
    Start-GuardedAction {
    $diskNum = $diskCombo.Text.Trim()
    if ([string]::IsNullOrEmpty($diskNum)) {
        [System.Windows.MessageBox]::Show("No disk selected.", "Error",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Take Disk $diskNum offline?`n`n" +
        "No data is erased or changed. Drive letters stay unless you 'Revert Drive Letters' first.`n`n" +
        "Continue?",
        "Take Disk Offline for Safe Detach", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "TAKING DISK $diskNum OFFLINE"
    Write-Log "=========================================="

    $offlineResult = Invoke-Diskpart -Commands @(
        "select disk $diskNum",
        "offline disk"
    ) -Description "Taking Disk $diskNum offline"

    # Check if diskpart reported an error
    if ($offlineResult -and $offlineResult -match '(?i)(error|cannot|failed|not supported)') {
        # Extract the error line (and the following detail line, e.g. after "Virtual Disk Service error:")
        $lines = $offlineResult -split "`r?`n"
        $errLine = "Unknown error"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '(?i)(error|cannot|failed|not supported)') {
                $errLine = $lines[$i].Trim()
                # Append the next non-empty line if the matched line has no detail of its own
                if ($errLine -match '(?i)error:\s*$') {
                    for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                        if ($lines[$j].Trim()) { $errLine = ($errLine + ' ' + $lines[$j].Trim()); break }
                    }
                }
                break
            }
        }

        if ($errLine -match '(?i)already offline') {
            # The disk is already offline - not a real failure, just tidy up the UI
            Write-Log "Disk $diskNum is already offline. Safe to detach from the rescue VM."
            Set-Status "Disk $diskNum already offline - safe to detach"
            $script:offlinedDisks[$diskNum] = $true
            $btnOffline.IsEnabled = $false
            $txtPackageName.Clear()
            [System.Windows.MessageBox]::Show(
                "Disk $diskNum is already offline.`n`nIt is safe to detach from the rescue VM.`n`n(Click 'Read Partitions' to bring it back online if you need to work on it again.)",
                "Disk Already Offline", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }

        Write-Log "ERROR: Could not take Disk $diskNum offline."
        Write-Log "Reason: $errLine"
        Set-Status "Disk $diskNum could not be taken offline"
        [System.Windows.MessageBox]::Show(
            "Could not take Disk $diskNum offline.`n`nReason: $errLine`n`nThis can happen if it is the rescue VM's own boot disk (which cannot be offlined).",
            "Disk Offline Failed", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    # Clear partition grid and combos — disable all repair/boot buttons
    $partitionGrid.ItemsSource = $null
    $winVolCombo.Items.Clear()
    $sysPartCombo.Items.Clear()
    $script:assignedLetters = @{}

    # Disable Offline so it can't be re-run, but KEEP the disk selected in the dropdown so
    # 'Read Partitions' can bring it back online if the user needs to work on it again.
    $script:offlinedDisks[$diskNum] = $true
    $btnOffline.IsEnabled = $false
    $txtPackageName.Clear()

    Write-Log "Disk $diskNum is now offline. Safe to detach from the rescue VM."
    Write-Log "(Click 'Read Partitions' to bring it back online if you need to work on it again.)"
    Set-Status "Disk $diskNum offline - safe to detach"
    }
})

# ==================== REVERT DRIVE LETTERS ====================
$btnRevertLetters.Add_Click({
    Start-GuardedAction {
    $diskNum = $diskCombo.Text.Trim()
    if ($script:assignedLetters.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No drive letters were assigned by this tool to revert.",
            "Nothing to Revert", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        return
    }

    $letterList = ($script:assignedLetters.GetEnumerator() | ForEach-Object { "Partition $($_.Key) = $($_.Value):" }) -join "`n"
    $confirm = [System.Windows.MessageBox]::Show(
        "Remove these drive letters that were assigned by this tool?`n`n$letterList`n`nDrive letters that existed before will NOT be touched.",
        "Confirm Revert Drive Letters", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "REVERTING ASSIGNED DRIVE LETTERS"
    Write-Log "=========================================="

    foreach ($entry in $script:assignedLetters.GetEnumerator()) {
        $partNum = $entry.Key
        $letter  = $entry.Value
        Invoke-Diskpart -Commands @(
            "select disk $diskNum",
            "select partition $partNum",
            "remove letter=$letter"
        ) -Description "Removing letter $letter from Partition $partNum"
    }

    $script:assignedLetters = @{}

    # Refresh the grid — clear combos so Restore-AllButtons disables everything
    $partitionGrid.ItemsSource = $null
    $winVolCombo.Items.Clear()
    $sysPartCombo.Items.Clear()

    Write-Log "All tool-assigned drive letters have been removed."
    Write-Log "Pre-existing drive letters were not modified."
    Set-Status "Drive letters reverted - click Read Partitions to rescan"
    }
})

# ==================== ADVANCED BOOT OPTIONS ====================
# These use bcdedit on the offline BCD to configure next-boot behavior

# Helper: run bcdedit against the offline BCD store
function Invoke-OfflineBcdedit {
    param([string]$WinDrive, [string[]]$Arguments, [string]$Description)
    $bcdStore = $WinDrive + ':\boot\BCD'
    $bcdStoreEfi = $WinDrive + ':\EFI\Microsoft\Boot\BCD'

    # Determine BCD path (use -Force to see hidden/system files)
    $storePath = $null
    if (Test-Path -LiteralPath $bcdStore) { $storePath = $bcdStore }
    elseif (Test-Path -LiteralPath $bcdStoreEfi) { $storePath = $bcdStoreEfi }

    if (-not $storePath) {
        # Try system partition if different
        $sysDrive = $sysPartCombo.SelectedItem
        if ($sysDrive) {
            $sysStore = $sysDrive + ':\boot\BCD'
            $sysStoreEfi = $sysDrive + ':\EFI\Microsoft\Boot\BCD'
            if (Test-Path -LiteralPath $sysStore) { $storePath = $sysStore }
            elseif (Test-Path -LiteralPath $sysStoreEfi) { $storePath = $sysStoreEfi }
        }
    }

    if (-not $storePath) {
        Write-Log "ERROR: Cannot find BCD store on selected drives."
        [System.Windows.MessageBox]::Show(
            "Cannot find BCD store on the selected drives.`nMake sure the System Partition is selected correctly.",
            "BCD Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return $null
    }

    $fullArgs = @("/store", $storePath) + $Arguments
    $cmd = 'bcdedit ' + ($fullArgs -join ' ')

    # First verify BCD is readable by enumerating it (skip if this IS an /enum call)
    $argsJoined = ($Arguments -join ' ').ToLower()
    if ($argsJoined -notmatch '/enum') {
        Write-Log "Verifying BCD store: $storePath"
        $enumCmd = 'bcdedit /store "' + $storePath + '" /enum {default}'
        $enumResult = Invoke-LoggedCommand -Command $enumCmd -Description "Checking BCD store"
        if ($script:cancelRequested) { return $null }

        if (-not $enumResult -or $enumResult -match '(?i)(error|not found|could not|cannot|invalid)') {
            Write-Log "ERROR: BCD store is not readable or corrupted."
            [System.Windows.MessageBox]::Show(
                "The BCD store could not be read.`n`nThe store may be corrupted or invalid.`nTry running BCD Rebuild first.",
                "BCD Store Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return $null
        }
        Write-Log "BCD store verified successfully."
    }

    return Invoke-LoggedCommand -Command $cmd -Description $Description
}

# Safe Mode
$btnSafeMode.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }
    $confirm = [System.Windows.MessageBox]::Show(
        "Configure BCD to boot into Safe Mode (minimal)?`n`nThe VM will boot with minimal drivers and no networking on next start.",
        "Confirm Safe Mode", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "SETTING SAFE MODE BOOT"
    Write-Log "=========================================="
    $bcdResult = Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/set", "{default}", "safeboot", "minimal") -Description "Set Safe Mode (Minimal)"
    if ($bcdResult) { Write-Log "Safe Mode configured. VM will boot into Safe Mode on next start." }
    }
})

# Safe Mode with Networking
$btnSafeModeNet.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }
    $confirm = [System.Windows.MessageBox]::Show(
        "Configure BCD to boot into Safe Mode with Networking?`n`nThe VM will boot with networking drivers enabled on next start.",
        "Confirm Safe Mode + Network", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "SETTING SAFE MODE WITH NETWORKING"
    Write-Log "=========================================="
    $bcdResult = Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/set", "{default}", "safeboot", "network") -Description "Set Safe Mode (Network)"
    if ($bcdResult) { Write-Log "Safe Mode with Networking configured." }
    }
})

# Safe Mode with Command Prompt
$btnSafeModeCmd.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }
    $confirm = [System.Windows.MessageBox]::Show(
        "Configure BCD to boot into Safe Mode with Command Prompt?`n`nThe VM will boot to CMD only (no Explorer shell) on next start.",
        "Confirm Safe Mode + CMD", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "SETTING SAFE MODE WITH COMMAND PROMPT"
    Write-Log "=========================================="
    $bcdResult = Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/set", "{default}", "safeboot", "minimal") -Description "Set Safe Mode (Minimal)"
    if ($bcdResult) {
        Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/set", "{default}", "safebootalternateshell", "yes") -Description "Set Alternate Shell (CMD)"
        Write-Log "Safe Mode with Command Prompt configured."
    }
    }
})

# Last Known Good Configuration (via offline registry)
$btnLKGC.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    $systemHive = $winDrive + ':\Windows\System32\config\SYSTEM'
    if (-not (Test-Path $systemHive)) {
        [System.Windows.MessageBox]::Show(
            "Cannot find SYSTEM registry hive at:`n$systemHive",
            "SYSTEM Hive Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Apply Last Known Good Configuration?`n`nThis will load the offline SYSTEM hive, read the LastKnownGood ControlSet, and set it as the Default ControlSet for next boot.",
        "Confirm LKGC", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "SETTING LAST KNOWN GOOD CONFIGURATION"
    Write-Log "=========================================="

    # Load the offline SYSTEM hive
    $hiveName = "YOURRESCUE_SYSTEM"
    $hiveLoaded = $false
    Write-Log "Loading SYSTEM hive from $systemHive..."
    $loadResult = Invoke-LoggedCommand -Command ('reg load "HKLM\' + $hiveName + '" "' + $systemHive + '"') -Description "Loading SYSTEM hive"
    if ($loadResult -match 'successfully|already in use') { $hiveLoaded = $true }

    try {
    # Read LastKnownGood value
    $selectResult = Invoke-LoggedCommand -Command ('reg query "HKLM\' + $hiveName + '\Select" /v LastKnownGood') -Description "Reading LastKnownGood ControlSet"

    $lkgValue = $null
    $lkgMatch = [regex]::Match([string]$selectResult, 'LastKnownGood\s+REG_DWORD\s+0x([0-9a-fA-F]+)')
    if ($lkgMatch.Success) {
        $lkgValue = [int]("0x" + $lkgMatch.Groups[1].Value)
    }

    if (-not $lkgValue) {
        Write-Log "ERROR: Could not read LastKnownGood value from Select key."
        return
    }

    Write-Log "LastKnownGood ControlSet: $lkgValue"

    # Set Default to LastKnownGood value
    Invoke-LoggedCommand -Command ('reg add "HKLM\' + $hiveName + '\Select" /v Default /t REG_DWORD /d ' + $lkgValue + ' /f') -Description "Setting Default ControlSet to $lkgValue"

    Write-Log ("Last Known Good Configuration applied ({0})." -f ('ControlSet{0:D3}' -f $lkgValue))
    } finally {
        if ($hiveLoaded) {
            Invoke-LoggedCommand -Command ('reg unload "HKLM\' + $hiveName + '"') -Description "Unloading SYSTEM hive"
        }
    }
    }
})

# DSRM Mode (Directory Services Restore Mode)
$btnDSRM.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }

    # Check if server is a Domain Controller by loading SYSTEM hive and checking for NTDS service
    Write-Log "Checking if server is a Domain Controller..."
    $systemHive = $winDrive + ':\Windows\System32\config\SYSTEM'
    if (-not (Test-Path $systemHive)) {
        [System.Windows.MessageBox]::Show(
            "Cannot find SYSTEM registry hive. Unable to verify if this is a DC.",
            "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    $hiveName = "YOURRESCUE_DCCHECK"
    $hiveLoaded = $false
    $loadResult = Invoke-LoggedCommand -Command ('reg load "HKLM\' + $hiveName + '" "' + $systemHive + '"') -Description "Loading SYSTEM hive for DC check"
    if ($loadResult -match 'successfully|already in use') { $hiveLoaded = $true }

    $isDC = $false
    try {
    # Find the current ControlSet
    $selectResult = Invoke-LoggedCommand -Command ('reg query "HKLM\' + $hiveName + '\Select" /v Current') -Description "Reading current ControlSet"
    $csNum = 1
    $csMatch2 = [regex]::Match([string]$selectResult, 'Current\s+REG_DWORD\s+0x([0-9a-fA-F]+)')
    if ($csMatch2.Success) {
        $csNum = [int]("0x" + $csMatch2.Groups[1].Value)
    }
    $controlSet = ('ControlSet{0:D3}' -f $csNum)

    # Determine role from ProductType (authoritative offline DC signal):
    #   LanmanNT = Domain Controller, ServerNT = member/standalone server, WinNT = client.
    # NOTE: the NTDS service key can exist on server SKUs without the AD DS role, so it is NOT
    # a reliable DC indicator - ProductType is.
    $ptResult = Invoke-LoggedCommand -Command ('reg query "HKLM\' + $hiveName + '\' + $controlSet + '\Control\ProductOptions" /v ProductType') -Description "Reading ProductType (DC check)"

    $productType = $null
    $ptMatch = [regex]::Match([string]$ptResult, 'ProductType\s+REG_SZ\s+(\w+)')
    if ($ptMatch.Success) {
        $productType = $ptMatch.Groups[1].Value
        Write-Log "ProductType = $productType"
    } else {
        Write-Log "WARNING: Could not read ProductType from the offline registry."
    }
    $isDC = ($productType -eq 'LanmanNT')
    } finally {
        if ($hiveLoaded) {
            Invoke-LoggedCommand -Command ('reg unload "HKLM\' + $hiveName + '"') -Description "Unloading SYSTEM hive"
        }
    }
    if (-not $isDC) {
        $roleDesc = if ($productType -eq 'ServerNT') { "a member/standalone server (ProductType=ServerNT)" }
                    elseif ($productType -eq 'WinNT') { "a client OS (ProductType=WinNT)" }
                    elseif ($productType) { "not a Domain Controller (ProductType=$productType)" }
                    else { "not a Domain Controller (ProductType could not be read)" }
        Write-Log "This server is NOT a Domain Controller - $roleDesc."
        [System.Windows.MessageBox]::Show(
            "This server is NOT a Domain Controller.`n`nDetected: $roleDesc.`n`nDSRM Mode only applies to Domain Controllers (ProductType=LanmanNT), so it will not be configured.",
            "Not a Domain Controller", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    Write-Log "Server confirmed as Domain Controller (ProductType=LanmanNT)."

    $confirm = [System.Windows.MessageBox]::Show(
        "This server IS a Domain Controller.`n`nConfigure BCD to boot into Directory Services Restore Mode?`nThis allows offline AD database repair.",
        "Confirm DSRM", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "SETTING DSRM MODE"
    Write-Log "=========================================="
    $bcdResult = Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/set", "{default}", "safeboot", "dsrepair") -Description "Set DSRM Mode"
    if ($bcdResult) { Write-Log "Directory Services Restore Mode configured." }
    }
})

# Disable Driver Signature Enforcement
$btnNoDriverSig.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }
    $confirm = [System.Windows.MessageBox]::Show(
        "Disable Driver Signature Enforcement for next boot?`n`nThis allows unsigned drivers to load. Use when a driver signature issue prevents boot.",
        "Confirm Disable Driver Sig", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "DISABLING DRIVER SIGNATURE ENFORCEMENT"
    Write-Log "=========================================="
    $bcdResult = Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/set", "{default}", "nointegritychecks", "yes") -Description "Disable Integrity Checks"
    if ($bcdResult) {
        Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/set", "{default}", "testsigning", "on") -Description "Enable Test Signing"
        Write-Log "Driver Signature Enforcement disabled for next boot."
    }
    }
})

# Start Windows Normally (remove all boot overrides)
$btnNormalBoot.Add_Click({
    Start-GuardedAction {
    $winDrive = $winVolCombo.SelectedItem
    if (-not (Test-WindowsVolume $winDrive)) { return }
    $confirm = [System.Windows.MessageBox]::Show(
        "Remove all boot overrides and set Windows to start normally?`n`nThis clears: Safe Mode, LKGC, DSRM, Driver Sig settings.",
        "Confirm Normal Boot", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -ne "Yes") { return }

    Write-Log "=========================================="
    Write-Log "RESETTING TO NORMAL BOOT"
    Write-Log "=========================================="
    $bcdResult = Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/deletevalue", "{default}", "safeboot") -Description "Remove Safe Mode"
    if ($bcdResult) {
        Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/deletevalue", "{default}", "safebootalternateshell") -Description "Remove Alternate Shell"
        Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/deletevalue", "{default}", "nointegritychecks") -Description "Remove Integrity Check Override"
        Invoke-OfflineBcdedit -WinDrive $winDrive -Arguments @("/deletevalue", "{default}", "testsigning") -Description "Remove Test Signing"
        Write-Log "All boot overrides removed. Windows will start normally."
    }
    }
})

# ==================== CANCEL BUTTON ====================
$btnCancel.Add_Click({
    if ($script:currentProcess -and -not $script:currentProcess.HasExited) {
        $confirm = [System.Windows.MessageBox]::Show(
            "Cancel the currently running command?`n`nThe command will be terminated immediately.",
            "Confirm Cancel",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -eq "Yes") {
            $script:cancelRequested = $true
            try {
                Stop-ProcessTree -Process $script:currentProcess
            } catch {
                Write-Log "Warning: Could not terminate process - it may have already completed."
            }
            Write-Log "Command cancelled by user."
            Set-Status "Command cancelled"
        }
    }
})

# Show window
$window.ShowDialog() | Out-Null

# Helper: write to log file only (used after window closes)
function Write-LogFile {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Add-Content -Path $script:logFilePath -Value $logLine -Encoding UTF8
}

# Auto-revert assigned drive letters after window closes
if ($script:assignedLetters.Count -gt 0) {
    $letterList = ($script:assignedLetters.GetEnumerator() | ForEach-Object { "Partition $($_.Key) = $($_.Value):" }) -join "`n"
    $confirm = [System.Windows.MessageBox]::Show(
        "The following drive letters were assigned by this tool:`n`n$letterList`n`nRemove them before exiting?`n(Recommended to keep the rescue VM clean)",
        "Remove Assigned Drive Letters?", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    if ($confirm -eq "Yes") {
        Write-LogFile "=========================================="
        Write-LogFile "CLEANUP: REMOVING TOOL-ASSIGNED DRIVE LETTERS"
        Write-LogFile "=========================================="
        $diskNum = $diskCombo.Text.Trim()
        if ($diskNum) {
            foreach ($entry in $script:assignedLetters.GetEnumerator()) {
                $partNum = $entry.Key
                $letter  = $entry.Value
                try {
                    $tempScript = [System.IO.Path]::GetTempFileName()
                    $outFile = [System.IO.Path]::GetTempFileName()
                    @("select disk $diskNum", "select partition $partNum", "remove letter=$letter") | Set-Content -Path $tempScript -Encoding ASCII
                    Write-LogFile "Removing letter $letter from Partition $partNum (Disk $diskNum)"
                    Start-Process -FilePath "diskpart" -ArgumentList "/s $tempScript" -RedirectStandardOutput $outFile -WindowStyle Hidden -Wait
                    $dpResult = Get-Content $outFile -Raw -ErrorAction SilentlyContinue
                    if ($dpResult) { Write-LogFile $dpResult }
                    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-LogFile "ERROR removing letter ${letter}: $_"
                }
            }
            Write-LogFile "Cleanup complete. All tool-assigned drive letters removed."
        } else {
            Write-LogFile "WARNING: No disk number available — could not remove letters."
        }
    } else {
        Write-LogFile "User chose to keep assigned drive letters on exit."
    }
}

# Clean up the DISM scratch directory on the rescue VM
if (Test-Path $script:scratchDir) {
    try {
        Remove-Item $script:scratchDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-LogFile "Removed scratch directory: $script:scratchDir"
    } catch {
        Write-LogFile "WARNING: Could not remove scratch directory $script:scratchDir - $_"
    }
}
