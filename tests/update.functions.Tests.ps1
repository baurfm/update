#Requires -Modules Pester

# Dot-sources ONLY update.functions.ps1 — never update.ps1 itself, which would trigger the
# lock/network/self-update/elevation machinery and the actual update run.
BeforeAll {
    . (Join-Path $PSScriptRoot '..\update.functions.ps1')
}

Describe 'Build-PendingGitUpdateRecord' {
    It 'starts skipCount at 1 and sets firstDetected on the first detection' {
        $record = Build-PendingGitUpdateRecord -Existing $null -Blockers @('bash.exe') -Now '2026-01-01T00:00:00'
        $record.skipCount     | Should -Be 1
        $record.firstDetected | Should -Be '2026-01-01T00:00:00'
        $record.lastDetected  | Should -Be '2026-01-01T00:00:00'
        $record.blockers      | Should -Be @('bash.exe')
    }
    It 'increments skipCount and preserves the original firstDetected on repeat detections' {
        $existing = [PSCustomObject]@{ firstDetected = '2026-01-01T00:00:00'; skipCount = 2 }
        $record = Build-PendingGitUpdateRecord -Existing $existing -Blockers @('git.exe') -Now '2026-01-03T00:00:00'
        $record.skipCount     | Should -Be 3
        $record.firstDetected | Should -Be '2026-01-01T00:00:00'
        $record.lastDetected  | Should -Be '2026-01-03T00:00:00'
    }
}

Describe 'Format-Elapsed' {
    It 'formats seconds only' {
        Format-Elapsed -ts ([TimeSpan]::FromSeconds(38)) | Should -Be '38s'
    }
    It 'formats minutes and seconds' {
        Format-Elapsed -ts ([TimeSpan]::FromSeconds(252)) | Should -Be '4m 12s'
    }
    It 'formats hours and minutes' {
        Format-Elapsed -ts ([TimeSpan]::FromMinutes(62)) | Should -Be '1h 2m'
    }
}

Describe 'Format-SummaryLine' {
    It 'joins items without truncation when at or under MaxShown' {
        $items = 1..8 | ForEach-Object { "item$_" }
        $result = Format-SummaryLine -Items $items -MaxShown 8
        $result | Should -Not -Match 'more'
        ($result -split ', ').Count | Should -Be 8
    }
    It 'truncates with a "+N more" suffix beyond MaxShown' {
        $items = 1..10 | ForEach-Object { "item$_" }
        $result = Format-SummaryLine -Items $items -MaxShown 8
        $result | Should -Match '\(\+2 more\)$'
    }
    It 'handles an empty collection' {
        Format-SummaryLine -Items @() | Should -Be ''
    }
}

Describe 'Test-SectionWanted / Test-GroupWanted' {
    AfterEach { $script:OnlyFilter = $null }

    It 'wants everything when no -Only filter is set' {
        $script:OnlyFilter = $null
        Test-SectionWanted -Name 'Winget & Microsoft Store apps' | Should -BeTrue
    }
    It 'matches a section name by substring' {
        $script:OnlyFilter = @('npm')
        Test-SectionWanted -Name 'npm (Node Package Manager) Packages' | Should -BeTrue
        Test-SectionWanted -Name 'Scoop and its packages' | Should -BeFalse
    }
    It 'matches any of several patterns' {
        $script:OnlyFilter = @('Azure', 'uv')
        Test-SectionWanted -Name 'Azure CLI' | Should -BeTrue
        Test-SectionWanted -Name 'uv' | Should -BeTrue
        Test-SectionWanted -Name 'Scoop and its packages' | Should -BeFalse
    }
    It 'group is wanted if any of its section names match' {
        $script:OnlyFilter = @('Azure')
        Test-GroupWanted -SectionNames @('Google Cloud SDK', 'Azure CLI', 'Android SDK') | Should -BeTrue
        Test-GroupWanted -SectionNames @('Scoop and its packages', 'Winget & Microsoft Store apps') | Should -BeFalse
    }
}

Describe 'Winget output parsing' {
    Context 'the original v12.10 garbage-entry bug scenario' {
        BeforeAll {
            $script:sample = @(
                'Name             Id              Version Available Source',
                '---------------------------------------------------------',
                'Google Cloud SDK Google.CloudSDK Unknown 583.0.0   winget',
                '2 upgrades available.',
                '',
                'The following packages have an upgrade available, but require explicit targeting for upgrade:',
                'Name           Id                   Version Available  Source',
                '-------------------------------------------------------------',
                'Android Studio Google.AndroidStudio 2026.1  2026.1.4.7 winget',
                '1 package(s) are pinned and need to be explicitly upgraded.'
            )
        }
        It 'returns only the real upgradable package, no garbage fragments' {
            Get-WingetUpgradableIds -WingetOutput $sample | Should -Be @('Google.CloudSDK')
        }
        It 'extracts the explicit-targeting package separately' {
            Get-WingetExplicitTargetIds -WingetOutput $sample | Should -Be @('Google.AndroidStudio')
        }
    }

    Context 'a digit-led package name ("7-Zip")' {
        It 'is not mistaken for a summary line' {
            $sample = @(
                'Name             Id              Version Available Source',
                '---------------------------------------------------------',
                '7-Zip            7zip.7zip       23.01   24.05     winget',
                'Google Cloud SDK Google.CloudSDK Unknown 583.0.0   winget',
                '2 upgrades available.'
            )
            Get-WingetUpgradableIds -WingetOutput $sample | Should -Be @('7zip.7zip', 'Google.CloudSDK')
        }
    }

    Context 'no updates available' {
        It 'returns an empty array for the standard "no applicable upgrades" message' {
            $result = @(Get-WingetUpgradableIds -WingetOutput @('No applicable upgrades were found.'))
            $result.Count | Should -Be 0
        }
        It 'returns an empty array for null/empty input' {
            @(Get-WingetUpgradableIds -WingetOutput $null).Count | Should -Be 0
            @(Get-WingetUpgradableIds -WingetOutput @()).Count | Should -Be 0
        }
    }

    Context 'multiple packages plus multiple explicit-targeting entries' {
        BeforeAll {
            $script:sample = @(
                'Name             Id              Version Available Source',
                '---------------------------------------------------------',
                'Google Cloud SDK Google.CloudSDK Unknown 583.0.0   winget',
                'Git              Git.Git         2.44.0  2.45.0    winget',
                '2 upgrades available.',
                '',
                'The following packages have an upgrade available, but require explicit targeting for upgrade:',
                'Name           Id                   Version Available  Source',
                '-------------------------------------------------------------',
                'Android Studio Google.AndroidStudio 2026.1  2026.1.4.7 winget',
                'Another Thing  Another.Thing        1.0     2.0        winget',
                '2 package(s) are pinned and need to be explicitly upgraded.'
            )
        }
        It 'returns both upgradable packages' {
            Get-WingetUpgradableIds -WingetOutput $sample | Should -Be @('Google.CloudSDK', 'Git.Git')
        }
        It 'returns both explicit-targeting packages' {
            Get-WingetExplicitTargetIds -WingetOutput $sample | Should -Be @('Google.AndroidStudio', 'Another.Thing')
        }
    }

    Context 'a user-pinned package in the main table' {
        It 'excludes rows marked Pinned' {
            $sample = @(
                'Name    Id        Version Available Source',
                '-------------------------------------',
                'MyApp   my.app    1.0     2.0  Pinned winget',
                'Other   other.app 1.0     2.0         winget',
                '1 upgrades available.'
            )
            Get-WingetUpgradableIds -WingetOutput $sample | Should -Be @('other.app')
        }
    }
}
