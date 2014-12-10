###################################################################################################################################
<# Based on Allen White, Colleen Morrow and Erin Stellato's Scripts for SQL Inventory and Baselining
https://www.simple-talk.com/sql/database-administration/let-powershell-do-an-inventory-of-your-servers/
http://colleenmorrow.com/2012/04/23/the-importance-of-a-sql-server-inventory/
http://www.sqlservercentral.com/articles/baselines/94657/ #>
###################################################################################################################################
param(
	[string]$SQLInst="localhost",
	[string]$Centraldb="CentralDB"
	)
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ManagedDTS') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
#####################################################################################################################################
<#Author: Chad Miller http://Sev17.com
Write-DataTable Function: http://gallery.technet.microsoft.com/scriptcenter/2fdeaf8d-b164-411c-9483-99413d6053ae
Out-DataTable Function: http://gallery.technet.microsoft.com/scriptcenter/4208a159-a52e-4b99-83d4-8048468d29dd #>
#####################################################################################################################################
<# 
.SYNOPSIS 
Writes data only to SQL Server tables. 
.DESCRIPTION 
Writes data only to SQL Server tables. However, the data source is not limited to SQL Server; any data source can be used, as long as the data can be loaded to a DataTable instance or read with a IDataReader instance. 
.INPUTS 
None 
    You cannot pipe objects to Write-DataTable 
.OUTPUTS 
None 
    Produces no output 
.EXAMPLE 
$dt = Invoke-Sqlcmd2 -ServerInstance "Z003\R2" -Database pubs "select *  from authors" 
Write-DataTable -ServerInstance "Z003\R2" -Database pubscopy -TableName authors -Data $dt 
This example loads a variable dt of type DataTable from query and write the datatable to another database 
.NOTES 
Write-DataTable uses the SqlBulkCopy class see links for additional information on this class. 
Version History 
v1.0   - Chad Miller - Initial release 
v1.1   - Chad Miller - Fixed error message 
.LINK 
http://msdn.microsoft.com/en-us/library/30c3y597%28v=VS.90%29.aspx 
#> 
function Write-DataTable 
{ 
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance, 
    [Parameter(Position=1, Mandatory=$true)] [string]$Database, 
    [Parameter(Position=2, Mandatory=$true)] [string]$TableName, 
    [Parameter(Position=3, Mandatory=$true)] $Data, 
    [Parameter(Position=4, Mandatory=$false)] [string]$Username, 
    [Parameter(Position=5, Mandatory=$false)] [string]$Password, 
    [Parameter(Position=6, Mandatory=$false)] [Int32]$BatchSize=50000, 
    [Parameter(Position=7, Mandatory=$false)] [Int32]$QueryTimeout=0, 
    [Parameter(Position=8, Mandatory=$false)] [Int32]$ConnectionTimeout=15 
    ) 
     $conn=new-object System.Data.SqlClient.SQLConnection  
    if ($Username) 
    { $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerInstance,$Database,$Username,$Password,$ConnectionTimeout } 
    else 
    { $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerInstance,$Database,$ConnectionTimeout } 
    $conn.ConnectionString=$ConnectionString 
   try 
    { 
        $conn.Open() 
        $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $connectionString 
        $bulkCopy.DestinationTableName = $tableName 
        $bulkCopy.BatchSize = $BatchSize 
        $bulkCopy.BulkCopyTimeout = $QueryTimeOut 
        $bulkCopy.WriteToServer($Data) 
        $conn.Close() 
    } 
    Catch [System.Management.Automation.MethodInvocationException]
    {
	$ex = $_.Exception 
	write-log -Message "$ex.Message on $svr" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
    }
    catch 
    { 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr"  -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
    } 
} #Write-DataTable
###########################################################################################################################
function Get-Type 
{ 
    param($type) 
 $types = @( 
'System.Boolean', 
'System.Byte[]', 
'System.Byte', 
'System.Char', 
'System.Datetime', 
'System.Decimal', 
'System.Double', 
'System.Guid', 
'System.Int16', 
'System.Int32', 
'System.Int64', 
'System.Single', 
'System.UInt16', 
'System.UInt32', 
'System.UInt64') 
 if ( $types -contains $type ) { 
        Write-Output "$type" 
    } 
    else { 
        Write-Output 'System.String'      
    } 
} #Get-Type 
<# 
.SYNOPSIS 
Creates a DataTable for an object 
.DESCRIPTION 
Creates a DataTable based on an objects properties. 
.INPUTS 
Object 
    Any object can be piped to Out-DataTable 
.OUTPUTS 
   System.Data.DataTable 
.EXAMPLE 
$dt = Get-psdrive| Out-DataTable 
This example creates a DataTable from the properties of Get-psdrive and assigns output to $dt variable 
.NOTES 
Adapted from script by Marc van Orsouw see link 
Version History 
v1.0  - Chad Miller - Initial Release 
v1.1  - Chad Miller - Fixed Issue with Properties 
v1.2  - Chad Miller - Added setting column datatype by property as suggested by emp0 
v1.3  - Chad Miller - Corrected issue with setting datatype on empty properties 
v1.4  - Chad Miller - Corrected issue with DBNull 
v1.5  - Chad Miller - Updated example 
v1.6  - Chad Miller - Added column datatype logic with default to string 
v1.7 - Chad Miller - Fixed issue with IsArray 
.LINK 
http://thepowershellguy.com/blogs/posh/archive/2007/01/21/powershell-gui-scripblock-monitor-script.aspx 
#> 
function Out-DataTable 
{ 
    [CmdletBinding()] 
    param([Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [PSObject[]]$InputObject) 
    Begin 
    { 
        $dt = new-object Data.datatable   
        $First = $true  
    } 
    Process 
    { 
        foreach ($object in $InputObject) 
        { 
            $DR = $DT.NewRow()   
            foreach($property in $object.PsObject.get_properties()) 
            {   
                if ($first) 
                {   
                    $Col =  new-object Data.DataColumn   
                    $Col.ColumnName = $property.Name.ToString()   
                    if ($property.value) 
                    { 
                        if ($property.value -isnot [System.DBNull]) { $Col.DataType = [System.Type]::GetType("$(Get-Type $property.TypeNameOfValue)")} 
                    } 
                    $DT.Columns.Add($Col) 
                }   
                if ($property.Gettype().IsArray) { 
                    $DR.Item($property.Name) =$property.value | ConvertTo-XML -AS String -NoTypeInformation -Depth 1 
                }   
               else { 
                    $DR.Item($property.Name) = $property.value 
                } 
            }   
            $DT.Rows.Add($DR)   
            $First = $false 
        } 
    }      
    End 
    {     
        Write-Output @(,($dt)) 
    } 
} #Out-DataTable
##########################################logging####################################################################################
#http://poshcode.org/2813
function Write-Log {   
            #region Parameters
                    [cmdletbinding()]
                    Param(
                            [Parameter(ValueFromPipeline=$true,Mandatory=$true)] [ValidateNotNullOrEmpty()]
                            [string] $Message,
                            [Parameter()] [ValidateSet(“Error”, “Warn”, “Info”)]
                            [string] $Level = “Info”,
                            [Parameter()]
                            [Switch] $NoConsoleOut,
                            [Parameter()]
                            [String] $ConsoleForeground = 'White',
                            [Parameter()] [ValidateRange(1,30)]
                            [Int16] $Indent = 0,     
                            [Parameter()]
                            [IO.FileInfo] $Path = ”$env:temp\PowerShellLog.txt”,                           
                            [Parameter()]
                            [Switch] $Clobber,                          
                            [Parameter()]
                            [String] $EventLogName,                          
                            [Parameter()]
                            [String] $EventSource,                         
                            [Parameter()]
                            [Int32] $EventID = 1,
                            [Parameter()]
                            [String] $LogEncoding = "ASCII"                         
                    )                   
            #endregion
            Begin {}
            Process {
                    try {                  
                            $msg = '{0}{1} : {2} : {3}' -f (" " * $Indent), (Get-Date -Format “yyyy-MM-dd HH:mm:ss”), $Level.ToUpper(), $Message                           
                            if ($NoConsoleOut -eq $false) {
                                    switch ($Level) {
                                            'Error' { Write-Error $Message }
                                            'Warn' { Write-Warning $Message }
                                            'Info' { Write-Host ('{0}{1}' -f (" " * $Indent), $Message) -ForegroundColor $ConsoleForeground}
                                    }
                            }
                            if ($Clobber) {
                                    $msg | Out-File -FilePath $Path -Encoding $LogEncoding -Force
                            } else {
                                    $msg | Out-File -FilePath $Path -Encoding $LogEncoding -Append
                            }
                            if ($EventLogName) {
                           
                                    if (-not $EventSource) {
                                            $EventSource = ([IO.FileInfo] $MyInvocation.ScriptName).Name
                                    }
                           
                                    if(-not [Diagnostics.EventLog]::SourceExists($EventSource)) {
                                            [Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
                            }
                                $log = New-Object System.Diagnostics.EventLog  
                                $log.set_log($EventLogName)  
                                $log.set_source($EventSource)                       
                                    switch ($Level) {
                                            “Error” { $log.WriteEntry($Message, 'Error', $EventID) }
                                            “Warn”  { $log.WriteEntry($Message, 'Warning', $EventID) }
                                            “Info”  { $log.WriteEntry($Message, 'Information', $EventID) }
                                    }
                            }
                    } catch {
                            throw “Failed to create log entry in: ‘$Path’. The error was: ‘$_’.”
                    }
            }    
            End {}    
            <#
                    .SYNOPSIS
                            Writes logging information to screen and log file simultaneously.    
                    .DESCRIPTION
                            Writes logging information to screen and log file simultaneously. Supports multiple log levels.     
                    .PARAMETER Message
                            The message to be logged.     
                    .PARAMETER Level
                            The type of message to be logged.                         
                    .PARAMETER NoConsoleOut
                            Specifies to not display the message to the console.                        
                    .PARAMETER ConsoleForeground
                            Specifies what color the text should be be displayed on the console. Ignored when switch 'NoConsoleOut' is specified.                  
                    .PARAMETER Indent
                            The number of spaces to indent the line in the log file.     
                    .PARAMETER Path
                            The log file path.                  
                    .PARAMETER Clobber
                            Existing log file is deleted when this is specified.                   
                    .PARAMETER EventLogName
                            The name of the system event log, e.g. 'Application'.                   
                    .PARAMETER EventSource
                            The name to appear as the source attribute for the system event log entry. This is ignored unless 'EventLogName' is specified.                   
                    .PARAMETER EventID
                            The ID to appear as the event ID attribute for the system event log entry. This is ignored unless 'EventLogName' is specified.     
                    .EXAMPLE
                            PS C:\> Write-Log -Message "It's all good!" -Path C:\MyLog.log -Clobber -EventLogName 'Application'     
                    .EXAMPLE
                            PS C:\> Write-Log -Message "Oops, not so good!" -Level Error -EventID 3 -Indent 2 -EventLogName 'Application' -EventSource "My Script"     
                    .INPUTS
                            System.String     
                    .OUTPUTS
                            No output.                           
                    .NOTES
                            Revision History:
                                    2011-03-10 : Andy Arismendi - Created.
                                    2011-07-23 : Will Steele - Updated.
            #>
    }
##########################################Port Number####################################################################################
#http://www.databasejournal.com/features/mssql/article.php/3764516/Discover-SQL-Server-TCP-Port.htm
function getTcpPort([String] $pHostName, [String] $pInstanceName)
{
	$strTcpPort=""
	$reg = [WMIClass]"\\$pHostName\root\default:stdRegProv"
	$HKEY_LOCAL_MACHINE = 2147483650
	#SQL Server 2000 or SQL Server 2005/2008 resides on the same host as SQL Server 2000
	# Default instance
	if ($pInstanceName -eq 'MSSQLSERVER') {
		$strKeyPath = "SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\SuperSocketNetLib\Tcp"
		$strTcpPort=$reg.GetStringValue($HKEY_LOCAL_MACHINE,$strKeyPath,"TcpPort").svalue
		if ($strTcpPort) {
			return $strTcpPort
		}		
	}
	# Named instance
	else {
		$strKeyPath = "SOFTWARE\Microsoft\Microsoft SQL Server\$pInstanceName\MSSQLServer\SuperSocketNetLib\Tcp"
		$strTcpPort=$reg.GetStringValue($HKEY_LOCAL_MACHINE,$strKeyPath,"TcpPort").svalue
		if ($strTcpPort) {
			return $strTcpPort
		}
	}
	#SQL Server 2005
	for ($i=1; $i -le 50; $i++) {
		$strKeyPath = "SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL.$i"
		$strInstanceName=$reg.GetStringValue($HKEY_LOCAL_MACHINE,$strKeyPath,"").svalue			
		if ($strInstanceName -eq $pInstanceName) {
			$strKeyPath = "SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL.$i\MSSQLServer\SuperSocketNetLib\tcp\IPAll"
			$strTcpPort=$reg.GetStringValue($HKEY_LOCAL_MACHINE,$strKeyPath,"TcpPort").svalue
			return $strTcpPort	
		}
	}
	#SQL Server 2008
	$strKeyPath = "SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL10.$pInstanceName\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
	$strTcpPort=$reg.GetStringValue($HKEY_LOCAL_MACHINE,$strKeyPath,"TcpPort").svalue
	if ($strTcpPort) {
		return $strTcpPort
	}
	#SQL Server 2008 R2
	$strKeyPath = "SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL10_50.$pInstanceName\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
	$strTcpPort=$reg.GetStringValue($HKEY_LOCAL_MACHINE,$strKeyPath,"TcpPort").svalue
	if ($strTcpPort) {
		return $strTcpPort
	}
	#SQL Server 2012
	$strKeyPath = "SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL11.$pInstanceName\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
	$strTcpPort=$reg.GetStringValue($HKEY_LOCAL_MACHINE,$strKeyPath,"TcpPort").svalue
	if ($strTcpPort) {
		return $strTcpPort
	}	
	return ""
}
#http://poshtips.com/measuring-elapsed-time-in-powershell/
$ElapsedTime = [System.Diagnostics.Stopwatch]::StartNew()
write-log -Message "Script Started at $(get-date)" -NoConsoleOut -Clobber -Path C:\CentralDB\Errorlog\CentralInventorylog.log
######################################################################################################################################
#Fucntion to get Server list info
try 
{ 
function GetServerListInfo($svr, $inst) {
# Create an ADO.Net connection to the instance
$cn = new-object system.data.SqlClient.SqlConnection("Data Source=$inst;Integrated Security=SSPI;Initial Catalog=master");
$s = new-object (‘Microsoft.SqlServer.Management.Smo.Server’) $cn
$RunDt = Get-Date -format G

############################################## Operating System Info #################################################################
#http://stackoverflow.com/questions/1142211/try-catch-does-not-seem-to-have-an-effect
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl="[Svr].[OSInfo]"
#Convert InstallDate, LastBootTime: http://www.petri.co.il/top-10-server-2008-tasks-done-with-powershell-part-2.htm#get-a-servers-uptime
#Uptime: http://prashant1987.wordpress.com/2012/11/16/windows-server-uptime-report-using-powershell/
#http://blogs.technet.com/b/heyscriptingguy/archive/2012/12/15/powertip-use-the-powershell-3-0-get-ciminstance-cmdlet.aspx
$a=Get-WmiObject -ComputerName $svr -Class Win32_OperatingSystem
$b = $a.convertToDateTime($a.Lastbootuptime)
[TimeSpan]$LastBoot = New-TimeSpan $b $(Get-Date)
$OSUpTime = (‘{0} Days, {1} Hrs’ -f $LastBoot.Days,$lastboot.Hours) 
if($a.Caption -Like '*XP*'){$OSName = 'Windows XP'} elseif($a.Caption -Like '*2003*'){$OSName = 'Windows Server 2003'} elseif($a.Caption -Like '*2008 R2*'){$OSName = 'Windows Server 2008 R2'}
elseif($a.Caption  -Like '*2008*'){$OSName = 'Windows Server 2008'} elseif($a.Caption -Like '*2012 R2*'){$OSName = 'Windows Server 2012 R2'} elseif($a.Caption -Like '*2012*'){$OSName = 'Windows Server 2012'} 
elseif($a.Caption -Like '*Windows 8.1*'){$OSName = 'Windows 8.1'} elseif($a.Caption -Like '*Windows 8*'){$OSName = 'Windows 8'} elseif($a.Caption -Like '*Windows 10*'){$OSName = 'Windows 10'} 
elseif($a.Caption -Like '*Windows 7*'){$OSName = 'Windows 7'} elseif($a.Caption -Like '*Vista*'){$OSName = 'Windows Vista'} elseif($a.Caption -Like '*2000*'){$OSName = 'Windows Server 2000'} else{$OSName = 'Unknown'}
$dt=Get-WMIObject Win32_OperatingSystem -computername $svr | select @{n="ServerName";e={$svr}}, @{n="OSName";e={$OSName}},
	#@{n="OSName";e={(($_.Caption).TrimStart("Microsoft®(R) ")).TrimEnd(", Enterprise Edition, Standard Edition Enterprise x64")}}, 
	OSArchitecture, Version, @{n="OSServicePack";e={$_.CSDVersion}}, @{n="OSInstallDate";e={$_.ConvertToDateTime($_.InstallDate)}}, 
	@{n="OSLastRestart";e={$_.ConvertToDateTime($_.LastBootUpTime)}}, @{n="OSUpTime";e={$OSUpTime}},
	@{Name="OSTotalVisibleMemorySizeInGB";Expression={[math]::round(($_.TotalVisibleMemorySize / 1024 / 1024), 2)}}, 
        @{Name="OSFreePhysicalMemoryInGB";Expression={[math]::round(($_.FreePhysicalMemory / 1024 / 1024), 2)}}, 
	@{Name="OSTotalVirtualMemorySizeInGB";Expression={[math]::round(($_.TotalVirtualMemorySize / 1024 / 1024), 2)}},
	@{Name="OSFreeVirtualMemoryInGB";Expression={[math]::round(($_.FreeVirtualMemory / 1024 / 1024), 2)}}, 
	@{Name="OSFreeSpaceInPagingFilesInGB";Expression={[math]::round(($_.FreeSpaceInPagingFiles / 1024 / 1024), 2)}}, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr while collecting Operating System Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
#################################################### Page File Usage Info  ############################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl="[Svr].[PgFileUsage]"
$dt= Get-WMIObject -query "select * from Win32_PageFileUsage" -computername $svr | select @{n="ServerName";e={$svr}}, Name, 
	 @{n="PgAllocBaseSzInGB";e={[math]::round(($_.AllocatedBaseSize / 1024), 2)}},
	 @{n="PgCurrUsageInGB";e={[math]::round(($_.CurrentUsage / 1024), 2)}},
	 @{n="PgPeakUsageInGB";e={[math]::round(($_.PeakUsage / 1024), 2)}}, @{n="DateAdded";e={$RunDt}}  | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr while collecting Page File Usage Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
############################################## Server Info ###########################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl ="[Svr].[ServerInfo]"
#Physical CPU Count: http://www.sql-server-pro.com/physical-cpu-count.html
#http://www.sqlservercentral.com/scripts/CPU/72156/
#http://www.brentozar.com/archive/2010/10/sql-server-on-powersaving-cpus-not-so-fast/
$processors = get-wmiobject -computername $svr win32_processor
	if (@($processors)[0].NumberOfCores)
        {
            $cores = @($processors).count * @($processors)[0].NumberOfCores
	    $Logical = @($processors).count * @($processors)[0].NumberOfLogicalProcessors
        }
        else
        {
            $cores = @($processors).count
        }
        #$sockets = @($processors).count;
	$sockets = @(@($processors) | % {$_.SocketDesignation} |select-object -unique).count;
$CurrentCPUSpeed = ($Processors | Measure-Object CurrentClockSpeed -max).Maximum
$MaxCPUSpeed  =  ($Processors | Measure-Object MaxClockSpeed -max).Maximum
$z = Get-WmiObject -Class Win32_SystemServices -ComputerName $svr
#http://social.technet.microsoft.com/Forums/windowsserver/en-US/40a85c85-1274-4f59-9e54-ad67c4f844f6/trying-to-get-the-ip-address-out-of-a-ping-command-using-regex
$ip = (Test-Connection $svr -count 1).IPV4Address.ToString()
#Hyper Threading: http://social.msdn.microsoft.com/Forums/en-US/csharplanguage/thread/f1ed7b15-485c-4c97-9cd1-f7104c369c0d/
#http://support.microsoft.com/kb/932370
#MemberRole: http://itknowledgeexchange.techtarget.com/powershell/computer-roles/
$domrole = DATA {
ConvertFrom-StringData -StringData @’
0 = Standalone Workstation 
1 = Member Workstation 
2 = Standalone Server 
3 = Member Server 
4 = Backup Domain Controller 
5 = Primary Domain Controller
‘@
}
$dt=Get-WMIObject -query "select * from Win32_ComputerSystem" -computername $svr | select @{n="ServerName";e={$svr}}, @{n="IPAddress";e={$ip}}, Model, Manufacturer, Description, 
	SystemType, @{n="ActiveNodeName";e={$_.DNSHostName.ToUpper()}}, Domain, @{n="DomainRole"; e={$domrole["$($_.DomainRole)"]}}, PartOfDomain, @{n="NumberofProcessors";e={$sockets}},
	@{n="NumberofLogicalProcessors";e={$Logical}}, @{n="NumberofCores";e={$cores}}, @{n="IsHyperThreaded";e={if($cores -le $Logical) {'True'} Else {'False'}}}, 
	@{n="CurrentCPUSpeed";e={$CurrentCPUSpeed}}, @{n="MaxCPUSpeed";e={$MaxCPUSpeed}}, @{n="IsPowerSavingModeON";e={if($CurrentCPUSpeed -ne $MaxCPUSpeed) {'True'} Else {'False'}}},
	@{Expression={$_.TotalPhysicalMemory / 1GB};Label=”TotalPhysicalMemoryInGB”}, AutomaticManagedPagefile, @{n="IsVM";e={if($_.Model -Like '*Virtual*') {'True'} else {'False'}}},
	@{n="IsClu";e={if ($Z | select PartComponent | where {$_ -like "*ClusSvc*"}) {'True'} else {'False'}}}, @{n="DateAdded";e={$RunDt}} | out-datatable
 Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr while collecting Server Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

############################################## Disk and MountPoint Info  #############################################################
#Convert Size in GB: http://learn-powershell.net/2010/08/29/convert-bytes-to-highest-available-unit/
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl="[Svr].[DiskInfo]"
$dt=Get-WMIObject -query "select * from Win32_Volume where DriveType=3 and not name like '%?%'" -computername $svr |select @{n="ServerName";e={$svr}},
	Name, Label, FileSystem, @{e={($_.BlockSize /1KB) -as [int]};n=”DskClusterSizeInKB”},  @{e={"{0:N2}" -f ($_.Capacity / 1GB)};n=”DskTotalSizeInGB”},  
	@{e={"{0:N2}" -f ($_.Freespace /1GB)};n=”DskFreeSpaceInGB”}, @{e={"{0:N2}" -f (($_.Capacity-$_.Freespace) /1GB)};n=”DskUsedSpaceInGB”}, 
	@{e={"{0:P2}" -f ($_.Freespace/$_.Capacity)};n=”DskPctFreeSpace”}, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr while collecting Disk and Mountpoint Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
#################################################### SQL Services Info  ############################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
#http://msdn.microsoft.com/en-us/library/windows/desktop/aa394418%28v=vs.85%29.aspx
#http://www.sqlmusings.com/2009/05/23/how-to-list-sql-server-services-using-powershell/
$CITbl="[Svr].[SQLServices]"
$dt= Get-WMIObject -query "select * from win32_service where name like 'SQLSERVERAGENT' or name like 'MSSQL%' or name like 'MsDts%' or name like 'ReportServer%' or name like 'SQLBrowser'" `
	-computername $svr  | select @{n="ServerName";e={$svr}}, Name, DisplayName, Started, StartMode, State, PathName, StartName, ProcessId, @{n="DateAdded";e={$RunDt}}  | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr while collecting SQL Services Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

##################################################SQL Server DB Engine Info ############################################################
#http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.database.isaccessible.aspx
$result = new-object Microsoft.SqlServer.Management.Common.ServerConnection($inst)
$responds = $false
if ($result.ProcessID -ne $null) {
    $responds = $true
    }  
If ($responds) {

################################################## Instance Info #########################################################################
#http://msdn.microsoft.com/en-us/library/ms220267.aspx
#http://www.youdidwhatwithtsql.com/auditing-your-sql-server-with-powershell/133/
#http://www.mikefal.net/2013/04/17/server-inventories/
#Chris Stewart and Jeremiah Nellis
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[Inst].[InstanceInfo]”
$s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $inst
$name = $inst.Split("\")
if ($name.Length -eq 1) { $instname = "MSSQLSERVER" } else { $instname = $name[1]}
$port = getTcpPort $svr $instname
$ip = (Test-Connection $svr -count 1).IPV4Address.ToString()
if($s.Version -Like '8.*'){ $SQLVersion = 'SQL Server 2000' } elseif($s.Version -Like '9.*'){ $SQLVersion = 'SQL Server 2005'} elseif($s.Version -Like '10.5*'){ $SQLVersion = 'SQL Server 2008 R2' } 
elseif($s.Version -Like '10.*'){ $SQLVersion = 'SQL Server 2008' } elseif($s.Version -Like '11.0*'){ $SQLVersion = 'SQL Server 2012'} 
elseif($s.Version -Like '12.0*'){ $SQLVersion = 'SQL Server 2014'} else { $SQLVersion ='Unknown'}

if(($s.Version -Like '8.*') -and ($s.ProductLevel -eq 'SP4')){ $IsSPUpToDate = 'True'} elseif(($s.Version -Like '9.*') -and ($s.ProductLevel -eq 'SP4')){ $IsSPUpToDate = 'True'} elseif(($s.Version -Like '10.5*') -and ($s.ProductLevel -eq 'SP3')){ $IsSPUpToDate = 'True' } 
elseif(($s.Version -Like '10.*') -and ($s.ProductLevel -eq 'SP4')){  $IsSPUpToDate = 'True' } elseif(($s.Version -Like '11.0*') -and ($s.ProductLevel -eq 'SP2')){ $IsSPUpToDate = 'True'} 
elseif(($s.Version -Like '12.0*') -and ($s.ProductLevel -eq 'RTM')){ $IsSPUpToDate = 'True'} else { $IsSPUpToDate = 'False'}

if($s.edition -Like'*Developer*'){ $SQLEdition = 'Developer Edition'} elseif($s.edition -Like'*Enterprise*'){ $SQLEdition = 'Enterprise Edition'} 
elseif($s.edition -Like'*Standard*'){ $SQLEdition = 'Standard Edition'} elseif($s.edition -Like'*Express*'){ $SQLEdition = 'Express Edition'} 
elseif($s.edition -Like'*Web*'){ $SQLEdition = 'Web Edition'} elseif($s.edition -Like'*Business*'){ $SQLEdition = 'BI Edition'} 
elseif($s.edition -Like'*Workgroup*'){ $SQLEdition = 'Workgroup Edition'} elseif($s.edition -Like'*Evaluation*'){ $SQLEdition = 'Evaluation Edition'} 
elseif($s.edition -Like'*Desktop*'){ $SQLEdition = 'Desktop Edition'} else{ $SQLEdition = 'Unknown'} 

$dt= $s | Select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}},  @{n="IPAddress";e={$ip}}, @{n="Port";e={$port}}, @{n="SQLVersion";e={$SQLVersion}},
	ProductLevel,@{n="IsSPUpToDate";e={$IsSPUpToDate}}, @{n="SQLEdition";e={$SQLEdition}}, Version, Collation, RootDirectory, 
	@{n="DefaultFile";e={if(!$s.DefaultFile){ 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA' }  else { $s.DefaultFile} }}, 
	@{n="DefaultLog";e={if(!$s.DefaultLog){ 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA' }  else { $s.DefaultLog} }},
	ErrorLogPath, IsCaseSensitive, IsClustered, IsFullTextInstalled, IsSingleUser, IsHadrEnabled, TcpEnabled, NamedPipesEnabled, ClusterName, ClusterQuorumState, 
	ClusterQuorumType, HadrManagerStatus,@{n="MaxMemory";e={$_.Configuration.MaxServerMemory.ConfigValue}}, @{n="MinMemory";e={$_.Configuration.MinServerMemory.ConfigValue}}, 
	@{n="MaxDOP";e={$_.Configuration.MaxDegreeOfParallelism.ConfigValue}}, @{n="NoOfUsrDBs";e={($_.Databases.Count)-4}}, @{n="NoOfJobs";e={$_.JobServer.Jobs.Count}}, 
	@{n="NoOfLnkSvrs";e={$_.LinkedServers.Count}}, @{n="NoOfLogins";e={$_.Logins.Count}}, @{n="NoOfRoles";e={$_.Roles.Count}}, @{n="NoOfTriggers";e={$_.Triggers.Count}},
	@{n="NoOfAvailGroups";e={$_.AvailabilityGroups.Count}}, @{n="AvailGrps"; e={if($_.IsHadrEnabled){($_| select -expand AvailabilityGroups) -join ', '}}},  
	IsXTPSupported, @{n="FilFactor";e={$_.Configuration.FillFactor.ConfigValue}}, ProcessorUsage, @{n="ActiveNode"; e={if($_.IsClustered){$_.ComputerNamePhysicalNetBIOS}}},
	@{n="ClusterNodeNames"; e={if($_.IsClustered){($_.Databases["master"].ExecuteWithResults("select NodeName from sys.dm_os_cluster_nodes").Tables[0] | select -expand NodeName) -Join ', '}}},
	@{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr while collecting Instance Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
################################################## Job Info #################################################################
#http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.agent.job%28v=sql.110%29.aspx
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[Inst].[Jobs]”
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
$dbs=$s.jobserver.jobs
$dt= $dbs | select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, name, Description, OwnerLoginName, IsEnabled, 
	category, DateCreated, DateLastModified,  LastRunDate, NextRunDate, LastRunOutcome, CurrentRunRetryAttempt,  
	OperatorToEmail, OperatorToPage, HasSchedule, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Job Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

################################################## Job Failure Info #################################################################
#http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.agent.jobhistoryfilter_properties%28v=sql.110%29.aspx

try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[Inst].[JobsFailed]”
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
$jobserver = $s.JobServer
$jobHistoryFilter = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobHistoryFilter
$jobHistoryFilter.OutComeTypes = 'Failed'
$dt= $jobserver.EnumJobHistory($jobHistoryFilter) | Where {$_.RunDate -gt ((Get-Date).AddDays(-1)) -and $_.SqlMessageID -ne 0} | select @{n="ServerName";e={$svr}},
	 @{n="InstanceName";e={$inst}}, JobName,StepID,StepName,Message, RunDate, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Failed Jobs  Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

####################################################  Login Info #################################################################
#http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.login.aspx
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[Inst].[Logins]”
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
$dbs=$s.Logins
$dt= $dbs | SELECT @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, Name, LoginType, CreateDate, DateLastModified, 
	IsDisabled, IsLocked, @{n="DateAdded";e={$RunDt}} |out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Login Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
####################################################  Instance Roles #################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[Inst].[InstanceRoles]”
$query =“select ('$Svr') as ServerName, ('$inst') as InstanceName, m.name as LoginName, r.name as RoleName, ('$RunDt') as DateAdded 
	from sys.server_principals r
	join sys.server_role_members rm on r.principal_id = rm.role_principal_id
	join sys.server_principals m on m.principal_id = rm.member_principal_id”
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Instance Roles Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
####################################################  Linked Servers Info #################################################################
#http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.login.aspx
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[Inst].[LinkedServers]”
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
$dbs=$s.linkedservers
$dt= $dbs | SELECT @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, Name, ProviderName, ProductName, ProviderString, 
	DateLastModified, DataAccess, @{n="DateAdded";e={$RunDt}} |out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Linked Servers Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
################################################## Instance Level Triggers#################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[Inst].[InsTriggers]”
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
	$dt = $s.Triggers | select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, Name, createdate, datelastmodified, IsEnabled, @{n="DateAdded";e={$RunDt}} |out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Instance Level Triggers Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

################################################## Replication Publisher Info #################################################################
#http://msdn.microsoft.com/en-us/library/ms146869.aspx
#http://stackoverflow.com/questions/27092339/how-to-join-the-output-of-object-array-to-a-string-in-powershell?answertab=votes#tab-top

try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[Inst].[Replication]”
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
$repsvr=New-Object "Microsoft.SqlServer.Replication.ReplicationServer" $inst

if($repsvr.IsPublisher -eq $true){
$dt = $repsvr | select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, IsPublisher, IsDistributor, DistributorAvailable, @{n="Publisher"; e={$_.SQLServerName}}, 
@{n="Distributor";e={$_.DistributionServer}}, @{n="Subscriber"; e={($_| select -expand RegisteredSubscribers | %{$_.Name}) -join ', '}}, 
@{n="ReplPubDBs";e={($_| select -expand ReplicationDatabases | where {$_.HasPublications -eq 1} | %{$_.Name}) -join ', '}},
@{n="DistDB";e={$_.DistributionDatabase}}, @{n="DateAdded";e={$RunDt}} | out-datatable
}

Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Replication Publisher  Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

################################################## Database Info #################################################################
#http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.database.aspx
#http://stackoverflow.com/questions/17807932/expandproperty-not-showing-other-properties-with-select-object

try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[DB].[DatabaseInfo]”
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
#$dbs=$s.Databases
foreach ($db in $s.Databases) {
if ($db.IsAccessible -eq $True) {
$dt= $db | Select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, Name, Status, Owner, CreateDate, Size, 
	@{n="DBSpaceAvailableInMB";e={[math]::round(($_.SpaceAvailable / 1024), 2)}},
	@{e={"{0:N2}" -f ($_.Size-($_.SpaceAvailable / 1024))};n=”DBUsedSpaceInMB”}, 
	@{e={"{0:P2}" -f (($_.SpaceAvailable / 1024)/$_.Size)};n=”DBPctFreeSpace”},
	@{n="DBDataSpaceUsageInMB";e={[math]::round(($_.DataSpaceUsage / 1024), 2)}},
	@{n="DBIndexSpaceUsageInMB";e={[math]::round(($_.IndexSpaceUsage / 1024), 2)}},
	ActiveConnections, Collation, RecoveryModel, CompatibilityLevel, PrimaryFilePath,
	LastBackupDate, LastDifferentialBackupDate, LastLogBackupDate, AutoShrink, AutoUpdateStatisticsEnabled,IsReadCommittedSnapshotOn,
	IsFullTextEnabled, BrokerEnabled, ReadOnly, EncryptionEnabled, IsDatabaseSnapshot, ChangeTrackingEnabled, 
	IsMirroringEnabled, MirroringPartnerInstance, MirroringStatus, MirroringSafetyLevel, ReplicationOptions,  AvailabilityGroupName,
	@{n="NoOfTbls";e={$_.Tables.Count}}, @{n="NoOfViews";e={$_.Views.Count}}, @{n="NoOfStoredProcs";e={$_.StoredProcedures.Count}}, 
	@{n="NoOfUDFs";e={$_.UserDefinedFunctions.Count}}, @{n="NoOfLogFiles";e={$_.LogFiles.Count}}, @{n="NoOfFileGroups";e={$_.FileGroups.Count}}, 
	@{n="NoOfUsers";e={$_.Users.Count}}, @{n="NoOfDBTriggers";e={$_.Triggers.Count}}, 
	@{n="LastGoodDBCCChecKDB"; e={$($_.ExecuteWithResults("dbcc dbinfo() with tableresults").Tables[0] | where {$_.Field -eq "dbi_dbccLastKnownGood"}|  Select Value).Value}},
	AutoClose,  HasFileInCloud, HasMemoryOptimizedObjects, MemoryAllocatedToMemoryOptimizedObjectsInKB, MemoryUsedByMemoryOptimizedObjectsInKB, 
	@{n="DateAdded";e={$RunDt}}  | out-datatable	
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}}#end For Each
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Database Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

#################################################### Availability Groups Info #################################################################
#http://msdn.microsoft.com/en-us/library/ff878305%28SQL.110%29.aspx


try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[DB].[AvailGroups]”
$query= "IF SERVERPROPERTY ('IsHadrEnabled') = 1
	BEGIN
	Select ('$Svr') as ServerName, ('$inst') as InstanceName, Ag.name as AGName, AGS.Primary_Replica as PrimaryReplica, AGS.Synchronization_Health_desc as SyncHealth, 
	AG.automated_backup_preference_desc as BackupPreference, AG.failure_condition_level as Failoverlevel, 
	AG.Health_check_timeout as HealthChkTimeout, AGL.dns_name as ListenerName, AGLIP.ip_address as ListenerIP,
	AGL.Port as ListenerPort, ('$RunDt') as DateAdded from sys.availability_groups AG 
	Inner Join sys.dm_hadr_availability_group_states AGS on ag.group_id = ags.group_id 
	Inner Join sys.dm_hadr_availability_replica_states ARS on ARS.Group_id = Ag.Group_id 
	Inner Join sys.availability_group_listeners AGL on AGL.Group_id = AG.Group_id
	Inner Join sys.availability_group_listener_ip_addresses AGLIP on AGL.listener_id = AGLIP.listener_id
	Where ARS.Role_Desc ='Primary'
	END"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Availability Groups Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
#################################################### Availability Databases Info #################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[DB].[AvailDatabases]”
$query= "IF SERVERPROPERTY ('IsHadrEnabled') = 1
		BEGIN
		Select ('$Svr') as ServerName, ('$inst') as InstanceName, SD.name as AGDBName, AG.Name as AGName, AGS.Primary_Replica as PrimaryReplica, 
		DRS.Synchronization_state_desc as SyncState, DRS.Synchronization_health_desc as SyncHealth, 
		DRS.database_state_desc as DBState,DRS.is_suspended as IsSuspended, DRS.suspend_reason_desc as SuspendReason,
		SD.create_Date as AGDBCreateDate, ('$RunDt') as DateAdded from sys.dm_hadr_database_replica_states DRS
		Inner Join Sys.databases as SD on SD.database_id= DRS.database_id
		Inner Join sys.dm_hadr_availability_group_states AGS on DRS.group_id = ags.group_id 
		Inner Join sys.availability_groups AG on DRS.group_id = ag.group_id 
		Inner Join sys.dm_hadr_availability_replica_states ARS on ARS.Group_id = Ag.Group_id 
		where ARS.Role_Desc ='Primary' and DRS.database_state_desc = 'Online'
		END"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Availability Databases Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
#################################################### Availability Replicas Info #################################################################

try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[DB].[AvailReplicas]”
$query= "IF SERVERPROPERTY ('IsHadrEnabled') = 1
		BEGIN
		Select  ('$Svr') as ServerName, ('$inst') as InstanceName, Ar.replica_server_name as ReplicaName, AG.name as AGName, ARS.Role_desc as Role,
		AR.Availability_mode_desc as AvailabilityMode, AR.Failover_mode_desc as FailoverMode, AR.session_timeout as SessionTimeout, 
		AR.Primary_role_allow_connections_desc as ConnectionsInPrimaryRole, AR.Secondary_role_allow_connections_desc as ReadableSecondary, 
		AR.endpoint_url as EndpointUrl, AR.Backup_priority as BackupPriority, AR.create_date as AGCreateDate, AR.Modify_date as AGModifyDate, 
		('$RunDt') as DateAdded from Sys.availability_replicas AR 
		Inner Join sys.availability_groups AG on AR.group_id=AG.Group_id
		Inner Join sys.dm_hadr_availability_replica_states ARS on ARS.replica_id = AR.replica_id
		Where Ar.Replica_server_name = @@ServerName
		End"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Availability Replicas Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

#################################################### DB Level Triggers Info #################################################################
#http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.databaseddltrigger.aspx
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = "[DB].[Triggers]”
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
foreach ($db in $s.Databases) {
if ($db.IsAccessible -eq $True) {
	[string]$nm = $db.Name
	$dt = $db.Triggers | select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, @{Name="Database"; Expression = {$nm}}, Name, 
	createdate, datelastmodified, IsEnabled, @{n="DateAdded";e={$RunDt}} |out-datatable
	Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
	}}#end For Each
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting DB Level Trigger Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
################################################## Database User Roles #################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[DB].[DBUserRoles]”
$query= "declare @db varchar(200), @sqlstmt nvarchar(4000)
    	SET NOCOUNT ON   
    	create table ##dbroles(
    	DBName    varchar(100) default db_name(), DBUser    varchar(200), DBRole    varchar(100));
	DECLARE dbs CURSOR FOR
	SELECT name FROM sys.databases WHERE database_id > 4 and state = 0
	OPEN dbs
	FETCH dbs INTO @db
	WHILE @@FETCH_STATUS = 0
	BEGIN
       	set @sqlstmt = N'USE ['+ @db +']; ' + ' insert into ##dbroles
                select DB_NAME() as DBname, m.name as DBuser, r.name as DBRole 
                from sys.database_principals r join sys.database_role_members rm on r.principal_id = rm.role_principal_id
                join sys.database_principals m on m.principal_id = rm.member_principal_id'
	exec sp_executesql @sqlstmt
	FETCH dbs INTO @db
   	END
	CLOSE dbs
	DEALLOCATE dbs
	SELECT ('$Svr') as ServerName, ('$inst') as InstanceName, DBname, DBuser,  DBRole, ('$RunDt') as DateAdded FROM ##dbroles
	DROP TABLE ##dbroles"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting DB user roles Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
################################################## Database Files #################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[DB].[DatabaseFiles]”
$query= "select ('$Svr') as ServerName, ('$inst') as InstanceName, DB_Name(database_id) as DBName, file_id, type_desc, name as LogicalName, physical_name, (size)*8/1024 as SizeInMB
        ,case (is_percent_growth) WHEN 1 THEN growth ELSE 0 END  as GrowthPct
        ,case (is_percent_growth) WHEN 0 THEN growth*8/1024 ELSE 0 END  as GrowthInMB, ('$RunDt') as DateAdded
        from sys.master_files
        WHERE type in (0, 1);"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
#@{n="";e={$_.}}
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting DB Files Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
################################################## Database Growth #################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[DB].[DBFileGrowth]”
$query= "select ('$Svr') as ServerName, ('$inst') as InstanceName, DB_Name(database_id) as DBName, SUM(case when type_desc = 'ROWS' then ((size)*8/1024) else 0 end) as DataFileInMB
    , SUM(case when type_desc = 'LOG' then ((size)*8/1024) else 0 end) as LogFileInMB, ('$RunDt') as DateAdded
        from sys.master_files
        WHERE type in (0, 1)
	Group By DB_Name(database_id);"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting DBGrwoth Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
################################################## Table Permissions info #################################################################
#Ivan NG http://crazydba.com/forums/topic/improvements-you-would-like-to-see-in-future-release-of-centraldb/
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[Tbl].[TblPermissions]”
$query= "declare @db varchar(200), @sqlstmt nvarchar(4000)
    		SET NOCOUNT ON   
    		create table #tmpuserperm(DBName SYSNAME, UserName nvarchar(128), ClassDesc nvarchar(60),
		ObjName sysname, PermName nvarchar(128), PermStat nvarchar(60));
		DECLARE dbs CURSOR FOR
		SELECT name FROM sys.databases WHERE name not in('msdb','tempdb', 'model')
		OPEN dbs
		FETCH dbs INTO @db
		WHILE @@FETCH_STATUS = 0
		BEGIN
       		set @sqlstmt = N'USE ['+ @db +']; ' + ' insert into #tmpuserperm
					select DB_NAME() as DBname, USER_NAME(p.grantee_principal_id) AS principal_name, p.class_desc,ObjectName = case p.class
					when 1 then case when p.minor_id=0 then object_name(p.major_id) else object_name(p.major_id)+''->''+ col_name(p.major_id,p.minor_id) end
					else ''N/A'' end, p.permission_name, p.state_desc AS permission_state from sys.database_permissions p 
					inner JOIN sys.database_principals dp on p.grantee_principal_id = dp.principal_id where dp.type in (''U'',''S'',''G'')'
		exec sp_executesql @sqlstmt
		FETCH dbs INTO @db
   		END
		CLOSE dbs
		DEALLOCATE dbs
		SELECT ('$Svr') as ServerName, ('$inst') as InstanceName, *, ('$RunDt') as DateAdded FROM #tmpuserperm ORDER BY dbname
		DROP TABLE #tmpuserperm"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Table Permissions Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
################################################## Hekaton Table info #################################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[Tbl].[HekatonTbls]”
$query= "IF SERVERPROPERTY ('IsXTPSupported') = 1
	BEGIN
	declare @db varchar(200), @sqlstmt nvarchar(4000)
    	SET NOCOUNT ON   
    	create table ##tmpHekaton(DBName SYSNAME, tblName SYSNAME, IsMemOptimized bit, Durability tinyint, 
		DurabilityDesc nvarchar(60), MemAllocForIdxInKB bigint, MemAllocForTblInKB bigint, MemUsdByIdxInKB bigint,
		MemUsdByTblInKB bigint);
	DECLARE dbs CURSOR FOR
	SELECT name FROM sys.databases --WHERE database_id > 4 and state = 0
	OPEN dbs
	FETCH dbs INTO @db
	WHILE @@FETCH_STATUS = 0
	BEGIN
       	set @sqlstmt = N'USE ['+ @db +']; ' + ' insert into ##tmpHekaton
                select DB_NAME() as DBname, t.name as HekatonTblName, t.Is_memory_optimized as IsMemOptimized, t.durability as Durability, t.durability_desc as DurabilityDesc,
				x.memory_allocated_for_indexes_kb as MemAllocForIdxInKB, x.memory_allocated_for_table_kb as MemAllocForTblInKB,
				x.memory_used_by_indexes_kb as MemUsdByIdxInKB, x.memory_used_by_table_KB as MemUsdByTblInKB from Sys.tables t 
				inner join sys.dm_db_xtp_table_memory_stats x on t.object_id= x.object_id and is_memory_optimized =1'
	exec sp_executesql @sqlstmt
	FETCH dbs INTO @db
   	END
	CLOSE dbs
	DEALLOCATE dbs
	SELECT ('$Svr') as ServerName, ('$inst') as InstanceName, *, ('$RunDt') as DateAdded FROM ##tmpHekaton ORDER BY dbname
	DROP TABLE ##tmpHekaton
	END"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting Hekaton Tables Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}


}
else {
             
              write-log -Message "SQL Server DB Engine is not Installed or Started or inaccessible on $inst"  -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
     }
#################################################### Reporting Services Info  ############################################################
#http://msdn.microsoft.com/en-us/library/ms152836.aspx
#http://serverfault.com/questions/28857/how-to-use-powershell-2-get-wmiobject-to-find-an-instance-of-sql-server-reportin
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$results = gwmi -query "select * from win32_service where name like 'ReportServer%' and started = 1" -computername $svr 
$responds = $false
if ($results.ProcessID -ne $null) { $responds = $true }
if ($responds) {
$name = $inst.Split("\")
if ($name.Length -eq 1) { $instname = "MSSQLSERVER" } else { $instname = $name[1]}
$CITbl="[RS].[SSRSInfo]"
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
if($s.Version -Like '9.*'){ $rs_namespace = 'root\Microsoft\SqlServer\ReportServer\v9' } 
elseif ($s.Version -Like '10.*') { $rs_namespace = "root\Microsoft\SqlServer\ReportServer\RS_" + $instname + "\v10" }
elseif ($s.Version -Like '11.0*') { $rs_namespace = "root\Microsoft\SqlServer\ReportServer\RS_" + $instname + "\v11" }
elseif ($s.Version -Like '12.0*') { $rs_namespace = "root\Microsoft\SqlServer\ReportServer\RS_" + $instname + "\v12" }

$dt = Get-WmiObject -class MSReportServer_Instance -namespace $rs_namespace   -computername $svr  | select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, 
	@{n="RSVersion";e={if($_.Version -eq $null) {'SQL Server 2005'} elseif($_.Version -Like '10.5*') { 'SQL Server 2008 R2'} elseif($_.Version -Like '10.*'){'SQL Server 2008'} 
	elseif($_.Version -Like '11.0*'){'SQL Server 2012'} elseif($_.Version -Like '12.0*'){'SQL Server 2014'} else{'Unknown'}}}, 
	@{n="RSEdition";e={if($_.EditionName -Like'*Developer*'){ 'Developer Edition'} 
	elseif($_.EditionName -Like'*Enterprise*'){ 'Enterprise Edition'} elseif($_.EditionName -Like'*Standard*'){ 'Standard Edition'} 
	elseif($_.EditionName -Like'*Express*'){ 'Express Edition'} elseif($_.EditionName -Like'*Web*'){ 'Web Edition'} 
	elseif($_.EditionName -Like'*Business*'){ 'BI Edition'} elseif($_.EditionName -Like'*Workgroup*'){ 'Workgroup Edition'} 
	elseif($_.EditionName -Like'*Evaluation*'){ 'Evaluation Edition'} else{ $_.EditionName = 'Unknown'} }},
	@{n="RSVersionNo";e={if($_.Version -eq $null) {'9.0'} else { $_.Version }}}, IsSharePointIntegrated, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt

$CITbl="[RS].[SSRSConfig]"
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $inst
if($s.Version -Like '9.*'){ $rs_namespace = 'root\Microsoft\SqlServer\ReportServer\v9\Admin' } 
elseif ($s.Version -Like '10.*') { $rs_namespace = "root\Microsoft\SqlServer\ReportServer\RS_" + $instname + "\v10\Admin" }
elseif ($s.Version -Like '11.0*') { $rs_namespace = "root\Microsoft\SqlServer\ReportServer\RS_" + $instname + "\v11\Admin" }
elseif ($s.Version -Like '12.0*') { $rs_namespace = "root\Microsoft\SqlServer\ReportServer\RS_" + $instname + "\v12\Admin" }

$dt = Get-WmiObject -class MSReportServer_ConfigurationSetting -namespace $rs_namespace   -computername $svr  | select @{n="ServerName";e={$svr}}, @{n="InstanceName1";e={$inst}}, 
	DatabaseServerName, InstanceName, PathName, DatabaseName, DatabaseLogonAccount, DatabaseLogonTimeout,
	DatabaseQueryTimeout, ConnectionPoolSize,  IsInitialized, IsReportManagerEnabled, IsSharePointIntegrated, 
	IsWebServiceEnabled, IsWindowsServiceEnabled, SecureConnectionLevel, SendUsingSMTPServer,SMTPServer, 
	SenderEmailAddress, UnattendedExecutionAccount, ServiceName, WindowsServiceIdentityActual, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}
else
{
	Write-log -Message "Reporting Services is not Installed or Started or inaccessible on $inst"  -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}

}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting RS Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}
#################################################### Analysis Services Info  ############################################################
try 
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$results = gwmi -query "select * from win32_service where name like 'MSSQLServerOLAPService%' and started = 1" -computername $svr 
$responds = $false
if ($results.ProcessID -ne $null) { $responds = $true }
if ($responds) {
$S = New-Object ('Microsoft.AnalysisServices.Server')
$s.connect("$inst")

$CITbl="[AS].[SSASInfo]"

if($s.Version -Like '8.*'){ $SQLASVersion = 'SQL Server 2000'} elseif($s.Version -Like '9.*'){ $SQLASVersion = 'SQL Server 2005'} elseif($s.Version -Like '10.5*'){ $SQLASVersion = 'SQL Server 2008 R2' } 
elseif($s.Version -Like '10.*'){ $SQLASVersion = 'SQL Server 2008' } elseif($s.Version -Like '11.0*'){ $SQLASVersion = 'SQL Server 2012'} 
elseif($s.Version -Like '12.0*'){ $SQLASVersion = 'SQL Server 2014'} else { $SQLASVersion ='Unknown'}

if(($s.Version -Like '8.*') -and ($s.ProductLevel -eq 'SP4')){ $IsSPUpToDateOnAS = 'True'} elseif(($s.Version -Like '9.*') -and ($s.ProductLevel -eq 'SP4')){ $IsSPUpToDateOnAS = 'True'} elseif(($s.Version -Like '10.5*') -and ($s.ProductLevel -eq 'SP3')){ $IsSPUpToDateOnAS = 'True' } 
elseif(($s.Version -Like '10.*') -and ($s.ProductLevel -eq 'SP4')){  $IsSPUpToDateOnAS = 'True' } elseif(($s.Version -Like '11.0*') -and ($s.ProductLevel -eq 'SP2')){ $IsSPUpToDateOnAS = 'True'} 
elseif(($s.Version -Like '12.0*') -and ($s.ProductLevel -eq 'RTM')){ $IsSPUpToDateOnAS = 'True'} else { $IsSPUpToDateOnAS = 'False'}

if($s.edition -Like'*Developer*'){ $SQLASEdition = 'Developer Edition'} elseif($s.edition -Like'*Enterprise*'){ $SQLASEdition = 'Enterprise Edition'} 
elseif($s.edition -Like'*Standard*'){ $SQLASEdition = 'Standard Edition'} elseif($s.edition -Like'*Express*'){ $SQLASEdition = 'Express Edition'} 
elseif($s.edition -Like'*Web*'){ $SQLASEdition = 'Web Edition'} elseif($s.edition -Like'*Business*'){ $SQLASEdition = 'BI Edition'} 
elseif($s.edition -Like'*Workgroup*'){ $SQLASEdition = 'Workgroup Edition'} elseif($s.edition -Like'*Evaluation*'){ $SQASLEdition = 'Evaluation Edition'} 
elseif($s.edition -Like'*Desktop*'){ $SQASLEdition = 'Desktop Edition'} else{ $SQLASEdition = 'Unknown'} 

$dt =  $s | Select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, ProductName, @{n="SQLASVersion";e={$SQLASVersion}}, ProductLevel, @{n="IsSPUpToDateOnAS";e={$IsSPUpToDateOnAS}},
	@{n="SQLASEdition";e={$SQLASEdition}}, Version, @{n="NoOfDBs";e={($_.Databases.Count)}}, LastSchemaUpdate, Connected, IsLoaded, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt

$CITbl="[AS].[SSASDBInfo]"
  $dt =  $s.Databases | Select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}},  Name, @{Expression={$_.EstimatedSize / 1MB};Label="DBSizeInMB"}, Collation, CompatibilityLevel, CreatedTimestamp, 
  LastProcessed, LastUpdate, DBStorageLocation, @{n="NoOfCubes";e={($_.Cubes.Count)}},  @{n="NoOfDimensions";e={($_.Dimensions.Count)}}, ReadWriteMode, StorageEngineUsed, Visible, @{n="DateAdded";e={$RunDt}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt

}
else
{
	Write-log -Message "Analysis Services is not Installed or Started or inaccessible on $svr" -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr While Collecting AS Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
}

} 
}
catch 
{ 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr while collecting Server and SQL Info" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
}  
#GetServerListInfo -ErrorAction "SilentlyContinue" 
######################################################################################################################################
$cn = new-object system.data.sqlclient.sqlconnection(“server=$SQLInst;database=$CentralDB;Integrated Security=true;”);
$cn.Open()
$cmd = $cn.CreateCommand()
$query = "Select Distinct ServerName, InstanceName from [Svr].[ServerList] where Inventory='True';"
$cmd.CommandText = $query
#$null = $cmd.ExecuteNonQuery()
$reader = $cmd.ExecuteReader()
while($reader.Read()) {
 
   	# Get ServerName and InstanceName from CentralDB
	$server = $reader['ServerName']
	$instance = $reader['InstanceName']
    	$result = gwmi -query "select StatusCode from Win32_PingStatus where Address = '$server'"
       	$responds = $false
	# If the machine responds break out of the result loop and indicate success
    	if ($result.statuscode -eq 0) {
        	$responds = $true
    	}
    	If ($responds) {
        # Calling funtion and passing server and instance parameters
		GetServerListInfo $server $instance
 
    	}
    	else {
 	# Let the user know we couldn't connect to the server
		write-log -Message "$server Server did not respond" -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
       	}
 
}
###################################################################Delete old data#################################################################
$cn = new-object system.data.SqlClient.SqlConnection(“server=$SQLInst;database=$CentralDB;Integrated Security=true;”);
$cn.Open()
$cmd = $cn.CreateCommand()
$q = "exec [dbo].[usp_DelData] 14, 365, 180, 365"
$cmd.CommandText = $q
$null = $cmd.ExecuteNonQuery()
$cn.Close()
write-log -Message "Script Ended at $(get-date)" -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
write-log -Message "Total Elapsed Time: $($ElapsedTime.Elapsed.ToString())" -NoConsoleOut -Path C:\CentralDB\Errorlog\CentralInventorylog.log
