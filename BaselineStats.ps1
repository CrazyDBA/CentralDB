############################################################################################################################################################
<# CrazyDBA.COM (CentralDB) - Based on Allen White, Colleen Morrow, Erin Stellato, Jonathan Kehayias and Ed Wilsons Scripts for SQL Inventory and Baselining
https://www.simple-talk.com/sql/database-administration/let-powershell-do-an-inventory-of-your-servers/
http://colleenmorrow.com/2012/04/23/the-importance-of-a-sql-server-inventory/
http://www.sqlservercentral.com/articles/baselines/94657/ 
https://www.simple-talk.com/sql/performance/a-performance-troubleshooting-methodology-for-sql-server/
http://blogs.technet.com/b/heyscriptingguy/archive/2011/07/28/use-performance-counter-sets-and-powershell-to-ease-baselining.aspx
http://www.youtube.com/watch?v=Y8IbadEHoPg #>
############################################################################################################################################################
param(
	[string]$SQLInst="localhost",
	[string]$Centraldb="CentralDB"
	)
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement') | out-null
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
	write-log -Message "$ex.Message on $svr" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\BaselineStatslog.log
    }
    catch 
    { 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr"  -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\BaselineStatslog.log
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
#http://poshtips.com/measuring-elapsed-time-in-powershell/
$ElapsedTime = [System.Diagnostics.Stopwatch]::StartNew()
write-log -Message "Script Started at $(get-date)" -NoConsoleOut -Clobber -Path C:\CentralDB\Errorlog\BaselineStatslog.log
######################################################################################################################################
#Fucntion to get Server list info
function GetServerListInfo($svr, $inst) {
# Create an ADO.Net connection to the instance
$cn = new-object system.data.SqlClient.SqlConnection("Data Source=$inst;Integrated Security=SSPI;Initial Catalog=master");
$s = new-object (‘Microsoft.SqlServer.Management.Smo.Server’) $cn
################################################## Instance Baseline Stats #################################################################
$result = new-object Microsoft.SqlServer.Management.Common.ServerConnection($inst)
$responds = $false
if ($result.ProcessID -ne $null) {
    $responds = $true
    }  
If ($responds) {
try
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[Inst].[InsBaselineStats]”
$query= "DECLARE @CounterPrefix NVARCHAR(30)
SET @CounterPrefix = CASE
    WHEN @@SERVICENAME = 'MSSQLSERVER'
    THEN 'SQLServer:'
    ELSE 'MSSQL$'+@@SERVICENAME+':'
    END;
-- Capture the first counter set
SELECT CAST(1 AS INT) AS collection_instance ,
      [OBJECT_NAME] ,
      counter_name ,
      instance_name ,
      cntr_value ,
      cntr_type ,
      CURRENT_TIMESTAMP AS collection_time
INTO #perf_counters_init
FROM sys.dm_os_performance_counters
WHERE (( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Page life expectancy') 
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Lazy Writes/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Page reads/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Page writes/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Databases' AND counter_name = 'Log Growths')
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Free list stalls/sec')							 
	OR ( OBJECT_NAME = @CounterPrefix+'General Statistics' AND counter_name = 'User Connections')
	OR ( OBJECT_NAME = @CounterPrefix+'Locks' AND counter_name = 'Lock Waits/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Locks' AND counter_name = 'Number of Deadlocks/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Databases' AND counter_name = 'Transactions/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods' AND counter_name = 'Forwarded Records/sec')  
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods' AND counter_name = 'Index Searches/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods' AND counter_name = 'Full Scans/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics' AND counter_name = 'Batch Requests/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics' AND counter_name = 'SQL Compilations/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics' AND counter_name = 'SQL Re-Compilations/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Latches' AND counter_name = 'Latch Waits/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'General Statistics' AND counter_name = 'Processes Blocked')
	OR ( OBJECT_NAME = @CounterPrefix+'Locks' AND counter_name = 'Lock Wait Time (ms)')
	OR ( OBJECT_NAME = @CounterPrefix+'Memory Manager' AND counter_name = 'Memory Grants Pending')
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods'AND counter_name = 'Page Splits/sec') ) 
	AND (instance_name = '' or instance_name = '_Total') 
-- Wait on Second between data collection
WAITFOR DELAY '00:00:01'
-- Capture the second counter set
SELECT CAST(2 AS INT) AS collection_instance ,
       OBJECT_NAME ,
       counter_name ,
       instance_name ,
       cntr_value ,
       cntr_type ,
       CURRENT_TIMESTAMP AS collection_time
INTO #perf_counters_second
FROM sys.dm_os_performance_counters
WHERE (( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Page life expectancy') 
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Lazy Writes/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Page reads/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Page writes/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Databases' AND counter_name = 'Log Growths')
	OR ( OBJECT_NAME = @CounterPrefix+'Buffer Manager' AND counter_name = 'Free list stalls/sec')							 
	OR ( OBJECT_NAME = @CounterPrefix+'General Statistics' AND counter_name = 'User Connections')
	OR ( OBJECT_NAME = @CounterPrefix+'Locks' AND counter_name = 'Lock Waits/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Locks' AND counter_name = 'Number of Deadlocks/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Databases' AND counter_name = 'Transactions/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods' AND counter_name = 'Forwarded Records/sec')  
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods' AND counter_name = 'Index Searches/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods' AND counter_name = 'Full Scans/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics' AND counter_name = 'Batch Requests/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics' AND counter_name = 'SQL Compilations/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'SQL Statistics' AND counter_name = 'SQL Re-Compilations/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'Latches' AND counter_name = 'Latch Waits/sec')
	OR ( OBJECT_NAME = @CounterPrefix+'General Statistics' AND counter_name = 'Processes Blocked')
	OR ( OBJECT_NAME = @CounterPrefix+'Locks' AND counter_name = 'Lock Wait Time (ms)')
	OR ( OBJECT_NAME = @CounterPrefix+'Memory Manager' AND counter_name = 'Memory Grants Pending')
	OR ( OBJECT_NAME = @CounterPrefix+'Access Methods'AND counter_name = 'Page Splits/sec') ) 
	AND (instance_name = '' or instance_name = '_Total') 
--Jeremiah Nellis
select 
	('$Svr') as ServerName, ('$inst') as InstanceName,  --getdate() as RunDate,
	[Forwarded Records/sec] as FwdRecSec,
	[Full Scans/sec] as FlScansSec,
	[Index Searches/sec] as IdxSrchsSec,
    	[Page Splits/sec] as PgSpltSec,
	[Free list stalls/sec] as FreeLstStallsSec,
	[Lazy writes/sec] as LzyWrtsSec,
	[Page life expectancy] as PgLifeExp,
	[Page reads/sec] as PgRdSec,
	[Page writes/sec] as PgWtSec,
	[Log Growths] LogGrwths,
	[Transactions/sec] as TranSec,
	[Processes blocked] as BlkProcs,
	[User Connections] as UsrConns,
	[Latch Waits/sec] as LatchWtsSec,
	[Lock Wait Time (ms)] as LckWtTime,
	[Lock Waits/sec] as LckWtsSec,
	[Number of Deadlocks/sec] as DeadLockSec,
	[Memory Grants Pending] as MemGrnts,
	[Batch Requests/sec] as BatReqSec,
	[SQL Compilations/sec] as SQLCompSec,
	[SQL Re-Compilations/sec] as SQLReCompSec
   -- add your additional counters here
From (SELECT  s.counter_name ,
        CASE WHEN i.cntr_type = 272696576
          THEN s.cntr_value - i.cntr_value
          WHEN i.cntr_type = 65792 THEN s.cntr_value
        END AS cntr_value
FROM #perf_counters_init AS i
  JOIN  #perf_counters_second AS s
    ON i.collection_instance + 1 = s.collection_instance
      AND i.OBJECT_NAME = s.OBJECT_NAME
      AND i.counter_name = s.counter_name
      AND i.instance_name = s.instance_name) as SourceTable
Pivot
(
Max(cntr_value)
For [counter_name] in (
		[Forwarded Records/sec],
		[Full Scans/sec],
		[Index Searches/sec],
		[Page Splits/sec],
		[Free list stalls/sec],
		[Lazy writes/sec],
		[Page life expectancy],
		[Page reads/sec],
		[Page writes/sec],
		[Log Growths],
		[Transactions/sec],
		[Processes blocked],
		[User Connections],
		[Latch Waits/sec],
		[Lock Wait Time (ms)],
		[Lock Waits/sec],
		[Number of Deadlocks/sec],
		[Memory Grants Pending],
		[Batch Requests/sec],
		[SQL Compilations/sec],
		[SQL Re-Compilations/sec]
		 -- add the same additional counters here
    ) 
) as PivotTable
-- Cleanup tables
DROP TABLE #perf_counters_init
DROP TABLE #perf_counters_second"

$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()

Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
} 
catch 
	{ 
        $ex = $_.Exception 
	write-log -Message "$ex.Message on $inst While collecting Instance Baseline Stats "  -NoConsoleOut -Path C:\CentralDB\Errorlog\BaselineStatslog.log
	} finally{
   		$ErrorActionPreference = "Continue"; #Reset the error action pref to default
	}
}
else {
             
              write-log -Message "SQL Server DB Engine is not Installed or Started or inaccessible on $inst"  -NoConsoleOut -Path C:\CentralDB\Errorlog\BaselineStatslog.log
     }
################################################## Server Baseline Stats ################################################################# 
try
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$Date= Get-Date -format G
$CITbl = “[Svr].[SvrBaselineStats]”

#Processor Counters

$Proc = get-Counter -Counter '\Processor(_total)\% Processor Time'-computername $svr
$PctProcTm=$proc.counterSamples[0].CookedValue

$ProcQ = get-Counter -Counter '\System\Processor Queue Length' -computername $svr
$ProcQLen = $ProcQ.counterSamples[0].CookedValue

#Disk Counters

$dskRd = get-Counter -Counter '\PhysicalDisk(_total)\Avg. Disk sec/Read' -computername $svr
$AvDskRd = $dskRd.counterSamples[0].CookedValue

$dskWt = get-Counter -Counter '\PhysicalDisk(_total)\Avg. Disk sec/Write' -computername $svr
$AvDskWt = $dskWt.counterSamples[0].CookedValue

$dskQ = get-Counter -Counter '\PhysicalDisk(_total)\Avg. Disk Queue Length' -computername $svr
$AvDskQLen = $dskQ.counterSamples[0].CookedValue

#Memory Counters

$AvlMB = get-Counter -Counter '\Memory\Available MBytes' -computername $svr
$AvailMB = $AvlMB.counterSamples[0].CookedValue

$PgFl = get-Counter -Counter '\Paging File(_total)\% Usage' -computername $svr
$PgFlUsg = $PgFl.counterSamples[0].CookedValue

$dt = get-Counter -computername $svr | select @{n="ServerName";e={$svr}}, @{n="InstanceName";e={$inst}}, @{Name="RunDate"; Expression = {$Date}}, 
	@{Name="PctProcTm"; Expression = {$PctProcTm}}, @{Name="ProcQLen"; Expression = {$ProcQLen}},@{Name="AvDskRd"; Expression = {$AvDskRd}},
	@{Name="AvDskWt"; Expression = {$AvDskWt}},@{Name="AvDskQLen"; Expression = {$AvDskQLen}}, @{Name="AvailMB"; Expression = {$AvailMB}},
 	 @{Name="PgFlUsg"; Expression = {$PgFlUsg}} | out-datatable
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}    
catch 
	{ 
        $ex = $_.Exception 
	write-log -Message "$ex.Message on $Svr While collecting Server Baseline Stats "  -NoConsoleOut -Path C:\CentralDB\Errorlog\BaselineStatslog.log
	} finally{
   		$ErrorActionPreference = "Continue"; #Reset the error action pref to default
	}
}#EndFunction
######################################################################################################################################
$cn = new-object system.data.sqlclient.sqlconnection(“server=$SQLInst;database=$CentralDB;Integrated Security=true;”);
$cn.Open()
$cmd = $cn.CreateCommand()
$query = " Select Distinct ServerName, InstanceName from [Svr].[ServerList] where Baseline='True';"
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
write-log -Message "Script Ended at $(get-date)" -NoConsoleOut -Path C:\CentralDB\Errorlog\BaselineStatslog.log
write-log -Message "Total Elapsed Time: $($ElapsedTime.Elapsed.ToString())" -NoConsoleOut -Path C:\CentralDB\Errorlog\BaselineStatslog.log
