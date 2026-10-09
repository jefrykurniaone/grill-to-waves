# PSScriptAnalyzer settings for install.ps1:
#   Invoke-ScriptAnalyzer -Path install.ps1 -Settings tests/PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # The installer is an interactive script: its progress lines are for the person at the
        # console, not for a pipeline, and Write-Host is how both of its message helpers print.
        'PSAvoidUsingWriteHost',
        # Its functions are helpers private to one script, named for what they act on
        # (Remove-RetiredAgents, Install-MattPocockSkills), not cmdlets exported from a module.
        'PSUseSingularNouns',
        # The same helpers change state without -WhatIf support; the script's own -Status is its
        # read-only mode.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
