function Move-MouseSmoothly {
    param(
        [int]$TargetX,
        [int]$TargetY,
        [int]$Steps = 20,
        [int]$MinDelay = 10,
        [int]$MaxDelay = 30
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    $CurrentPosition = [System.Windows.Forms.Cursor]::Position
    
    for ($i = 1; $i -le $Steps; $i++) {
        $X = $CurrentPosition.X + (($TargetX - $CurrentPosition.X) * $i / $Steps)
        $Y = $CurrentPosition.Y + (($TargetY - $CurrentPosition.Y) * $i / $Steps)
        
        # Add slight randomness to mimic human imperfection
        $X += Get-Random -Minimum -2 -Maximum 3
        $Y += Get-Random -Minimum -2 -Maximum 3
        
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point([math]::Round($X), [math]::Round($Y))
        
        # Random delay between steps for natural feel
        Start-Sleep -Milliseconds (Get-Random -Minimum $MinDelay -Maximum $MaxDelay)
    }
}
