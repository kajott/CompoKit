cd (Split-Path -Parent (Split-Path -Parent $PSCommandPath))

if (-not (Test-Path bin)) { mkdir bin }
