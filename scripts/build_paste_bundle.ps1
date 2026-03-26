param(
  [string]$SourceDir = (Join-Path $PSScriptRoot '..\\src'),
  [string]$OutputFile = (Join-Path $PSScriptRoot '..\\dist\\zhr_export_senior_bundle.txt')
)

$ErrorActionPreference = 'Stop'

$sourcePath = (Resolve-Path $SourceDir).Path
$outputDir = Split-Path $OutputFile -Parent

if (-not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$files = Get-ChildItem -Path $sourcePath -Filter 'zhr_senior_exp_*.prog.abap' |
  Sort-Object Name

$mainProgram = Join-Path $sourcePath 'zhr_export_senior.prog.abap'
if (Test-Path $mainProgram) {
  $files = @(Get-Item $mainProgram) + @($files)
}

if (-not $files) {
  throw 'Nenhum arquivo zhr_senior_exp_*.prog.abap encontrado.'
}

$builder = New-Object System.Text.StringBuilder

foreach ($file in $files) {
  [void]$builder.AppendLine("###FILE: $($file.Name)")
  $content = Get-Content -Path $file.FullName -Raw
  [void]$builder.Append($content)
  if (-not $content.EndsWith("`r`n") -and -not $content.EndsWith("`n")) {
    [void]$builder.AppendLine()
  }
  [void]$builder.AppendLine()
}

[System.IO.File]::WriteAllText($OutputFile, $builder.ToString(), [System.Text.Encoding]::ASCII)

Write-Host "Bundle gerado em: $OutputFile"
Write-Host "Arquivos incluidos: $($files.Count)"
