@{
    # Rules excluded on purpose - each one fires dozens of times on deliberate design choices and
    # would otherwise bury the warnings that actually matter.
    ExcludeRules = @(
        # Colored interactive terminal output is the whole UI of this script.
        'PSAvoidUsingWriteHost'
        # Internal helpers, not exported cmdlets - -WhatIf/-Confirm support would be dead weight.
        'PSUseShouldProcessForStateChangingFunctions'
        # Test-WingetHasUpdates etc. read better plural; nothing is exported.
        'PSUseSingularNouns'
        # Write-Log only exists as a built-in on PS 6.1+ Linux/macOS hosts; the script is Windows-only.
        'PSAvoidOverwritingBuiltInCmdlets'
    )
}
