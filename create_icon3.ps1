Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 512, 512
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.ColorTranslator]::FromHtml("#388E3C"))
$fontFamily = New-Object System.Drawing.FontFamily "Arial"
$font = New-Object System.Drawing.Font $fontFamily, 180, "Bold", "Pixel"
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = "Center"
$format.LineAlignment = "Center"
$rect = New-Object System.Drawing.RectangleF 0, 0, 512, 512
$g.DrawString("FF", $font, $brush, $rect, $format)
New-Item -ItemType Directory -Force -Path "assets" | Out-Null
$bmp.Save("$(Get-Location)\assets\icon.png", "Png")
