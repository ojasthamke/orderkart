Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 512, 512
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.ColorTranslator]::FromHtml("#388E3C"))
$font = New-Object System.Drawing.Font "Arial", 120, [System.Drawing.FontStyle]::Bold
$brush = New-Object System.Drawing.SolidBrush [System.Drawing.Color]::White
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$g.DrawString("FF", $font, $brush, (New-Object System.Drawing.RectangleF 0, 0, 512, 512), $format)
New-Item -ItemType Directory -Force -Path "assets" | Out-Null
$bmp.Save("assets\icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
