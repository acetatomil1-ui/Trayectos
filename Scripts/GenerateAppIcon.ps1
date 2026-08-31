Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $projectRoot 'Trayectos\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon.png'

$bitmap = [System.Drawing.Bitmap]::new(
    1024,
    1024,
    [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$bounds = [System.Drawing.Rectangle]::new(0, 0, 1024, 1024)
$top = [System.Drawing.Color]::FromArgb(255, 91, 92, 226)
$bottom = [System.Drawing.Color]::FromArgb(255, 65, 184, 166)
$background = [System.Drawing.Drawing2D.LinearGradientBrush]::new($bounds, $top, $bottom, 45)
$graphics.FillRectangle($background, $bounds)

$soft = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(38, 255, 255, 255))
$graphics.FillEllipse($soft, -120, -100, 650, 650)
$graphics.FillEllipse($soft, 560, 540, 620, 620)

$routePath = [System.Drawing.Drawing2D.GraphicsPath]::new()
$routePath.AddBezier(230, 725, 250, 520, 425, 570, 462, 408)
$routePath.AddBezier(462, 408, 505, 224, 750, 300, 772, 165)

$routeShadow = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(70, 20, 30, 70), 96)
$routeShadow.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$routeShadow.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$routeShadow.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$graphics.DrawPath($routeShadow, $routePath)

$route = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 72)
$route.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$route.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$route.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$graphics.DrawPath($route, $routePath)

$pinOuter = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$pinInner = [System.Drawing.SolidBrush]::new($top)
$graphics.FillEllipse($pinOuter, 672, 86, 200, 200)
$graphics.FillEllipse($pinInner, 730, 144, 84, 84)

$startOuter = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$startInner = [System.Drawing.SolidBrush]::new($bottom)
$graphics.FillEllipse($startOuter, 154, 650, 152, 152)
$graphics.FillEllipse($startInner, 196, 692, 68, 68)

$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$startInner.Dispose()
$startOuter.Dispose()
$pinInner.Dispose()
$pinOuter.Dispose()
$route.Dispose()
$routeShadow.Dispose()
$routePath.Dispose()
$soft.Dispose()
$background.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "App icon generated at $outputPath"
