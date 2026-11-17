# Read-only file server for Roblox Studio (localhost only).
# Studio loads generator scripts from 02_Scripts via HttpService during editing.
# Arbeitsordner seit 2026-11-17: GitHub-Repo Miami-State (z.B. ...\GitHub\Miami-State\02_Scripts).
# Der Pfad wird relativ zu diesem Skript bestimmt (MapBuild\.. = 02_Scripts), nicht mehr C:\Dev\MIAMI STATE.
param([int]$Port = 34872)
$root = Split-Path -Parent $PSScriptRoot  # 02_Scripts
if ((Split-Path -Leaf $root) -ne '02_Scripts' -or -not (Test-Path (Join-Path $root 'MapBuild\Runner.luau'))) {
    throw "Unerwarteter Pfad: $root (erwartet ...\Miami-State\02_Scripts)"
}
$root = $root.TrimEnd('\') + '\'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "Serving $root on http://localhost:$Port/"
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if ($ctx.Request.HttpMethod -eq 'GET' -and $path.StartsWith($root) -and (Test-Path $path -PathType Leaf)) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $ctx.Response.ContentType = 'text/plain; charset=utf-8'
        $ctx.Response.StatusCode = 200
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $ctx.Response.StatusCode = 404
    }
    $ctx.Response.Close()
}
