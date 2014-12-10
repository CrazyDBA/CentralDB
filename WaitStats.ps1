###################################################################################################################################
<# Based on Allen White, Collen Morrow, Erin Stellato's and Jonathan Kehayias Scripts for SQL Inventory and Baselining
https://www.simple-talk.com/sql/database-administration/let-powershell-do-an-inventory-of-your-servers/
http://colleenmorrow.com/2012/04/23/the-importance-of-a-sql-server-inventory/
http://www.sqlservercentral.com/articles/baselines/94657/ 
https://www.simple-talk.com/sql/performance/a-performance-troubleshooting-methodology-for-sql-server/#>
###################################################################################################################################
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
	write-log -Message "$ex.Message on $svr" -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\WaitStatslog.log
    }
    catch 
    { 
        $ex = $_.Exception 
        write-log -Message "$ex.Message on $svr"  -Level Error -NoConsoleOut -Path C:\CentralDB\Errorlog\WaitStatslog.log
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
write-log -Message "Script Started at $(get-date)" -NoConsoleOut -Clobber -Path C:\CentralDB\Errorlog\WaitStatslog.log
######################################################################################################################################
#Fucntion to get Server list info
function GetServerListInfo($svr, $inst) {
# Create an ADO.Net connection to the instance
$cn = new-object system.data.SqlClient.SqlConnection("Data Source=$inst;Integrated Security=SSPI;Initial Catalog=master");
$s = new-object (‘Microsoft.SqlServer.Management.Smo.Server’) $cn
$RunDt = Get-Date -format G
################################################## Missing Indexes #################################################################
try 
{ 
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[Inst].[MissingIndexes]”
$query= "Select ('$Svr') as ServerName, ('$inst') as InstanceName, DB_Name(mid.database_id) as DBName, OBJECT_SCHEMA_NAME(mid.[object_id], mid.database_id) as SchemaName, 
	mid.statement as MITable,migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure, 
  'CREATE INDEX [IDX'
  + '_' + LEFT (PARSENAME(mid.statement, 1), 32) + ']'
  + ' ON ' + mid.statement 
  + ' (' + ISNULL (mid.equality_columns,'') 
    + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END 
    + ISNULL (mid.inequality_columns, '')
  + ')' 
  + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement,
  migs.group_handle, migs.unique_compiles, migs.user_seeks, migs.last_user_seek, migs.avg_total_user_cost, migs.avg_user_impact, ('$RunDt') as DateAdded
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 100000
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC"

$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}    
catch 
	{ 
        $ex = $_.Exception 
	write-log -Message "$ex.Message on $Svr While collecting Missing Indexes "  -NoConsoleOut -Path C:\CentralDB\Errorlog\WaitStatslog.log 
	} finally{
   		$ErrorActionPreference = "Continue"; #Reset the error action pref to default
	}
################################################## Wait Stats #################################################################
try
{
$ErrorActionPreference = "Stop"; #Make all errors terminating
$CITbl = “[Inst].[WaitStats]”
$query= ";WITH [Waits] AS
         (SELECT [wait_type], [wait_time_ms] / 1000.0 AS [WaitS],
            ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
            [signal_wait_time_ms] / 1000.0 AS [SignalS],
            [waiting_tasks_count] AS [WaitCount],
            100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
            ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
         FROM sys.dm_os_wait_stats
         WHERE [wait_type] NOT IN ('CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK',
        'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'LOGMGR_QUEUE',
        'CHECKPOINT_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT', 'BROKER_TO_FLUSH',
        'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT', 'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE',
        'FT_IFTS_SCHEDULER_IDLE_WAIT', 'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN', 'BROKER_EVENTHANDLER',
        'TRACEWRITE', 'FT_IFTSHC_MUTEX', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP', 'DIRTY_PAGE_POLL', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION')
         )
 SELECT ('$Svr') as ServerName, ('$inst') as InstanceName, 
         [W1].[wait_type] AS [WaitType], 
         CAST ([W1].[WaitS] AS DECIMAL(14, 2)) AS [Wait_S],
         CAST ([W1].[ResourceS] AS DECIMAL(14, 2)) AS [Resource_S],
         CAST ([W1].[SignalS] AS DECIMAL(14, 2)) AS [Signal_S],
         [W1].[WaitCount] AS [WaitCount],
         CAST ([W1].[Percentage] AS DECIMAL(4, 2)) AS [Percentage],
         CAST (([W1].[WaitS] / [W1].[WaitCount]) AS DECIMAL (14, 4)) AS [AvgWait_S],
         CAST (([W1].[ResourceS] / [W1].[WaitCount]) AS DECIMAL (14, 4)) AS [AvgRes_S],
         CAST (([W1].[SignalS] / [W1].[WaitCount]) AS DECIMAL (14, 4)) AS [AvgSig_S], ('$RunDt') as DateAdded
      FROM [Waits] AS [W1]
      INNER JOIN [Waits] AS [W2]
         ON [W2].[RowNum] <= [W1].[RowNum]
      GROUP BY [W1].[RowNum], [W1].[wait_type], [W1].[WaitS], 
         [W1].[ResourceS], [W1].[SignalS], [W1].[WaitCount], [W1].[Percentage]
      HAVING SUM ([W2].[Percentage]) - [W1].[Percentage] < 95"
$da = new-object System.Data.SqlClient.SqlDataAdapter ($query, $cn)
$dt = new-object System.Data.DataTable
$da.fill($dt) | out-null
#$cn.Close()
Write-DataTable -ServerInstance $SQLInst -Database $Centraldb -TableName $CITbl -Data $dt
}    
catch 
	{ 
        $ex = $_.Exception 
	write-log -Message "$ex.Message on $Svr While collecting Wait Stats "  -NoConsoleOut -Path C:\CentralDB\Errorlog\WaitStatslog.log 
	} finally{
   		$ErrorActionPreference = "Continue"; #Reset the error action pref to default
	}
}
######################################################################################################################################
$cn = new-object system.data.sqlclient.sqlconnection(“server=$SQLInst;database=$CentralDB;Integrated Security=true;”);
$cn.Open()
$cmd = $cn.CreateCommand()
$query = " Select Distinct ServerName, InstanceName from [Svr].[ServerList] where Baseline = 'True';"
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
write-log -Message "Script Ended at $(get-date)" -NoConsoleOut -Path C:\CentralDB\Errorlog\WaitStatslog.log
write-log -Message "Total Elapsed Time: $($ElapsedTime.Elapsed.ToString())" -NoConsoleOut -Path C:\CentralDB\Errorlog\WaitStatslog.log
