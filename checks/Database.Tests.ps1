$filename = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Describe 'Testing Database Collation' -Tags Database, Collation, $filename {
	(Get-SqlInstance).ForEach{
		$results = Test-DbaDatabaseCollation -SqlInstance $psitem
		foreach ($result in $results) {
			It "database collation ($($result.DatabaseCollation)) on $psitem should match server collation ($($result.ServerCollation)) for $($result.Database) on $psitem" {
				$result.ServerCollation -eq $result.DatabaseCollation | Should be $true
			}
		}
	}
}

if (-not (Get-DbcConfigValue skip.backuptesting)) {
	$destserver = Get-DbcConfigValue setup.backuptestserver
	$destdata = Get-DbcConfigValue setup.backupdatadir
	$destlog = Get-DbcConfigValue setup.backuplogdir
	Describe 'Testing backups' -Tags Backup, Database, $filename {
		(Get-SqlInstance).ForEach{
			foreach ($result in (Test-DbaLastBackup -SqlInstance $psitem -Destination $destserver -LogDirectory $destlog -DataDirectory $destdata )) {
				if ($result.DBCCResult -notmatch 'skipped for restored master') {
					It "DBCC for $($result.Database) on $psitem should be success" {
						$result.DBCCResult | Should Be 'Success'
					}
					It "restore for $($result.Database) on $psitem should be success" {
						$result.RestoreResult | Should Be 'Success'
					}
					
				}
			}
		}
	}
}

$targetowner = Get-DbcConfigValue policy.dbownershould
Describe 'Testing Database Owners' -Tags Database, Owner, $filename {
    (Get-SqlInstance).ForEach{
        Context "Testing $psitem for Database Owners" {
            $results = Test-DbaDatabaseOwner -SqlInstance $psitem -TargetLogin $targetowner
            $results.ForEach{
                It "$($psitem.Database) Owner should be $targetowner" {
                    $psitem.CurrentOwner | Should Be $psitem.TargetOwner
                }
            }
        }
    }
}

$targetowner = Get-DbcConfigValue policy.dbownershouldnot
Describe 'Testing Database Owners' -Tags Database, Owner, $filename {
    (Get-SqlInstance).ForEach{
        Context "Testing $psitem for Database Owners" {
            $results = Test-DbaDatabaseOwner -SqlInstance $psitem -TargetLogin $targetowner
            $results.ForEach{
                It "$($psitem.Database) Owner should Not be $targetowner" {
                    $psitem.CurrentOwner | Should Not Be $psitem.TargetOwner
                }
            }
        }
    }
}

$maxdays = Get-DbcConfigValue policy.integritycheckmaxdays
$datapurity = Get-DbcConfigValue skip.datapuritycheck

Describe 'Testing last good DBCC CHECKDB' -Tags Database, Corruption, Integrity, DBCC, $filename {
    (Get-SqlInstance).ForEach{
        Context "Testing $psitem " {
            $results = Get-DbaLastGoodCheckDb -SqlInstance $psitem
            foreach ($result in $results) {
                if ($result.Database -ne 'tempdb') {
                    It "last good integrity check for $($result.Database) on $psitem should be less than $maxdays" {
                        $result.LastGoodCheckDb | Should BeGreaterThan (Get-Date).AddDays( - ($maxdays))
                    }
				
                    It -Skip:$datapurity "last good integrity check for $($result.Database) on $psitem has Data Purity Enabled" {
                        $result.DataPurityEnabled | Should Be $true
                    }
                }
            }
        }
    }
}
$maxpercentage = Get-DbcConfigValue policy.identityusagepercent

Describe 'Testing Column Identity Usage' -Tags Database, Identity ,$filename {
	(Get-SqlInstance).ForEach{
		$results = Test-DbaIdentityUsage -SqlInstance $psitem
		foreach ($result in $results) {
			if ($result.Database -ne 'tempdb') {
				$columnfqdn = "$($result.Database).$($result.Schema).$($result.Table).$($result.Column)" 
				It "usage for $columnfqdn on $psitem should be less than $maxpercentage percent" {
					$result.PercentUsed -lt $maxpercentage | Should be $true
				}
			}
		}
	}
}