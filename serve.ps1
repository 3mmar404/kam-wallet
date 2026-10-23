$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$server = [System.Net.HttpListener]::new()
$server.Prefixes.Add('http://localhost:8080/')
try { $server.Start() } catch { Write-Host 'Port 8080 is busy. Close the other server and try again.'; exit 1 }
Write-Host 'KAM is running at http://localhost:8080/ - keep this window open.'
$types = @{'.html'='text/html';'.js'='text/javascript';'.css'='text/css';'.json'='application/json';'.webmanifest'='application/manifest+json';'.svg'='image/svg+xml';'.png'='image/png';'.woff2'='font/woff2'}
try {
  while ($server.IsListening) {
    $ctx = $server.GetContext()
    try {
      $relative = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
      if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
      $file = [IO.Path]::GetFullPath((Join-Path $root $relative))
      if (-not $file.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { $ctx.Response.StatusCode=403 }
      elseif (-not [IO.File]::Exists($file)) { $ctx.Response.StatusCode=404 }
      else {
        $ext=[IO.Path]::GetExtension($file).ToLowerInvariant()
        $ctx.Response.ContentType= $(if($types.ContainsKey($ext)){$types[$ext]}else{'application/octet-stream'})
        $bytes=[IO.File]::ReadAllBytes($file)
        $ctx.Response.ContentLength64=$bytes.Length
        $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length)
      }
    } catch { $ctx.Response.StatusCode=500 } finally { $ctx.Response.Close() }
  }
} finally { $server.Stop();$server.Close() }
