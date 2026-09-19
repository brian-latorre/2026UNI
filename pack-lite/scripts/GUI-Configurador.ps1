# --- Módulos ---
. "$PSScriptRoot\modules\Utils.Logging.ps1"
. "$PSScriptRoot\modules\UI.Theme.ps1"
. "$PSScriptRoot\modules\Perfil.Manager.ps1"
. "$PSScriptRoot\modules\JVM.Manager.ps1"
. "$PSScriptRoot\modules\Graficos.Restaurador.ps1"

# --- Validación de WPF ---
if (-not (Test-WPFRuntime)) { exit 1 }

# --- Mutex de instancia única ---
$mutexName = "Global\Configurador2026UNI"
$mutex = [System.Threading.Mutex]::new($false, $mutexName)
if (-not $mutex.WaitOne(0)) {
    [System.Windows.MessageBox]::Show(
        "El Configurador ya esta abierto.",
        "Configurador 2026UNI",
        'OK', 'Information'
    )
    exit 0
}

try {
    [xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Configurador 2026UNI" Height="680" Width="420" MinHeight="580"
    SizeToContent="Height"
    WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
    Background="#0B0B0B" FontFamily="Segoe UI">
    
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Opacity" Value="0.8" />
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" BorderThickness="0">
        <StackPanel Margin="20">
            <TextBlock Text="CONFIGURADOR 2026UNI" FontSize="22" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" />
            <TextBlock Text="Selecciona el perfil grafico para tu PC" FontSize="13" Foreground="#CCCCCC" HorizontalAlignment="Center" Margin="0,5,0,20" />
            
            <Button x:Name="BtnNormal" Content=" PERFIL NORMAL" Background="#BF1515" Foreground="White" Height="50" FontSize="16" FontWeight="Bold" Margin="0,0,0,10" />
            <Button x:Name="BtnLite" Content=" PERFIL LITE" Background="#222222" Foreground="#CCCCCC" Height="50" FontSize="16" FontWeight="Bold" Margin="0,0,0,20" />
            
            <Rectangle Height="1" Fill="#333333" Margin="0,0,0,20" />
            
            <CheckBox x:Name="ChkZGC" Content="Usar ZGC (recolector de basura de baja latencia)" Foreground="#CCCCCC" Cursor="Hand" IsChecked="True" Margin="0,0,0,15" />
            
            <StackPanel Margin="0,0,0,15">
                <Slider x:Name="SliderRAM" Minimum="4" Maximum="10" Value="7" IsSnapToTickEnabled="True" TickFrequency="1" TickPlacement="BottomRight" Cursor="Hand" Margin="0,0,0,5"/>
                <TextBlock x:Name="TxtRAMInfo" Text="Calculando..." Foreground="#888888" FontSize="12" HorizontalAlignment="Center" />
            </StackPanel>
            
            <Button x:Name="BtnAplicarRAM" Content="Aplicar RAM" Background="#222222" Foreground="#CCCCCC" Height="38" Margin="0,0,0,20" />
            
            <Rectangle Height="1" Fill="#333333" Margin="0,0,0,20" />
            
            <Expander x:Name="ExpanderAvanzado" Header="Herramientas avanzadas" Foreground="#888888" Cursor="Hand" Margin="0,0,0,20">
                <StackPanel Margin="0,10,0,0">
                    <Button x:Name="BtnRestoreAll" Content="Restaurador General" Background="#1A1A1A" Foreground="#AAAAAA" Height="30" Margin="0,0,0,5" />
                    <Button x:Name="BtnFixEmbeddium" Content="Reparar Embeddium" Background="#1A1A1A" Foreground="#AAAAAA" Height="30" Margin="0,0,0,5" />
                    <Button x:Name="BtnFixOculus" Content="Reparar Oculus/Shaders" Background="#1A1A1A" Foreground="#AAAAAA" Height="30" Margin="0,0,0,5" />
                    <Button x:Name="BtnFixOptionsTxt" Content="Reparar options.txt" Background="#1A1A1A" Foreground="#AAAAAA" Height="30" />
                </StackPanel>
            </Expander>
            
            <Button x:Name="BtnSalir" Content="Cerrar" Background="#151515" Foreground="#888888" Height="35" Margin="0,20,0,0" />
        </StackPanel>
    </ScrollViewer>
</Window>
"@
    
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Ícono de la ventana (ruta dinámica, no se puede poner en el XAML)
    $iconPath = Join-Path $PSScriptRoot "assets\icon.ico"
    if (Test-Path $iconPath) {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create(
            [System.Uri]::new($iconPath, [System.UriKind]::Absolute)
        )
    }

    # Buscar controles
    $btnNormal = $window.FindName("BtnNormal")
    $btnLite = $window.FindName("BtnLite")
    $chkZGC = $window.FindName("ChkZGC")
    $sliderRAM = $window.FindName("SliderRAM")
    $txtRAMInfo = $window.FindName("TxtRAMInfo")
    $btnAplicarRAM = $window.FindName("BtnAplicarRAM")
    $expanderAvanzado = $window.FindName("ExpanderAvanzado")
    $btnRestoreAll = $window.FindName("BtnRestoreAll")
    $btnFixEmbeddium = $window.FindName("BtnFixEmbeddium")
    $btnFixOculus = $window.FindName("BtnFixOculus")
    $btnFixOptionsTxt = $window.FindName("BtnFixOptionsTxt")
    $btnSalir = $window.FindName("BtnSalir")

    # Inicialización de estado de RAM y GC
    $cfgFile = Find-InstanceCfg
    if ($cfgFile -and (Test-Path $cfgFile)) {
        $content = Get-Content $cfgFile
        $hasZGC = $false
        $hasG1GC = $false
        $maxMem = $null
        foreach ($line in $content) {
            if ($line -match "MaxMemAlloc=(\d+)") {
                $maxMem = [int]$matches[1]
            }
            if ($line -match "^JvmArgs=.*-XX:\+UseZGC") {
                $hasZGC = $true
            }
            if ($line -match "^JvmArgs=.*-XX:\+UseG1GC") {
                $hasG1GC = $true
            }
        }
        if ($hasZGC) { $chkZGC.IsChecked = $true }
        elseif ($hasG1GC) { $chkZGC.IsChecked = $false }

        if ($maxMem) {
            $sliderRAM.Value = [math]::Round($maxMem / 1024)
        }
    }

    $ramRec = Get-RAMRecomendada
    
    function Update-TxtRAMInfo {
        $val = $sliderRAM.Value
        $msg = "$val GB seleccionados"
        if ($chkZGC.IsChecked -eq $true -and $val -lt 6) {
            $txtRAMInfo.Foreground = "#FFAA00" # Warning color
            $txtRAMInfo.Text = " $msg (ZGC recomienda 6+ GB)"
        } else {
            $txtRAMInfo.Foreground = "#888888"
            $txtRAMInfo.Text = $msg
        }
    }
    
    Update-TxtRAMInfo

    # Función para actualizar colores de los botones
    function Update-ProfileButtons {
        $perfilActivo = Get-PerfilActivo
        $bc = New-Object System.Windows.Media.BrushConverter
        if ($perfilActivo -eq "Normal") {
            $btnNormal.Background = $bc.ConvertFromString("#BF1515")
            $btnNormal.Foreground = $bc.ConvertFromString("White")
            $btnLite.Background = $bc.ConvertFromString("#222222")
            $btnLite.Foreground = $bc.ConvertFromString("#CCCCCC")
        } else {
            $btnNormal.Background = $bc.ConvertFromString("#222222")
            $btnNormal.Foreground = $bc.ConvertFromString("#CCCCCC")
            $btnLite.Background = $bc.ConvertFromString("#BF1515")
            $btnLite.Foreground = $bc.ConvertFromString("White")
        }
    }

    # Inicialización visual de perfiles
    Update-ProfileButtons

    # Wiring de eventos
    $btnNormal.Add_Click({
        if (Set-Perfil -Nombre "Normal") {
            Update-ProfileButtons
            [System.Windows.MessageBox]::Show("Perfil Normal aplicado.", "Exito", 'OK', 'Information')
        } else {
            [System.Windows.MessageBox]::Show("Error al aplicar perfil Normal.", "Error", 'OK', 'Error')
        }
    })

    $btnLite.Add_Click({
        if (Set-Perfil -Nombre "Lite") {
            Update-ProfileButtons
            [System.Windows.MessageBox]::Show("Perfil Lite aplicado.", "Exito", 'OK', 'Information')
        } else {
            [System.Windows.MessageBox]::Show("Error al aplicar perfil Lite.", "Error", 'OK', 'Error')
        }
    })

    $chkZGC.Add_Checked({
        Set-MotorGC -Motor "ZGC"
        Update-TxtRAMInfo
    })
    $chkZGC.Add_Unchecked({
        Set-MotorGC -Motor "G1GC"
        Update-TxtRAMInfo
    })

    $sliderRAM.Add_ValueChanged({
        Update-TxtRAMInfo
    })

    $btnAplicarRAM.Add_Click({
        if (Set-RAM -GB $sliderRAM.Value) {
            [System.Windows.MessageBox]::Show("RAM aplicada correctamente.", "Exito", 'OK', 'Information')
        } else {
            [System.Windows.MessageBox]::Show("Error al aplicar RAM.", "Error", 'OK', 'Error')
        }
    })

    $btnRestoreAll.Add_Click({
        $msg = "Esta herramienta realizara una restauracion general de las configuraciones del modpack.`n`n" +
               "Se restableceran a su estado oficial del servidor:`n" +
               "- config (configuraciones de mods)`n" +
               "- mods (limpieza automatica de mods no oficiales o conflictivos)`n" +
               "- options.txt (volumen, FOV, brillo, graficos basicos y orden de texturas)`n" +
               "- emojiful (restablecer emojis)`n`n" +
               "Garantias de seguridad:`n" +
               "* NO se eliminaran tus mundos ni capturas de pantalla.`n" +
               "* NO se eliminaran tus paquetes de recursos (.zip) descargados.`n" +
               "* SmartKeySync: Se conservaran intactos tus atajos de teclado y candados (client.json).`n`n" +
               "Deseas continuar con la restauracion general?"

        $result = [System.Windows.MessageBox]::Show(
            $msg,
            "Confirmacion - Restaurador General",
            'YesNo', 'Warning'
        )
        if ($result -eq 'Yes') {
            if (Restore-TodosLosGraficos) {
                [System.Windows.MessageBox]::Show("Todas las configuraciones fueron restauradas exitosamente.", "Exito", 'OK', 'Information')
            } else {
                [System.Windows.MessageBox]::Show("La restauracion finalizo con advertencias. Revisa los registros.", "Advertencia", 'OK', 'Warning')
            }
        }
    })
    $btnFixEmbeddium.Add_Click({
        if (Restore-Embeddium) { [System.Windows.MessageBox]::Show("Embeddium restaurado.", "Exito", 'OK', 'Information') }
    })
    $btnFixOculus.Add_Click({
        if (Restore-Oculus) { [System.Windows.MessageBox]::Show("Oculus restaurado.", "Exito", 'OK', 'Information') }
    })
    $btnFixOptionsTxt.Add_Click({
        $msg = "Esta herramienta restaurara el archivo options.txt a la plantilla oficial del perfil activo.`n`n" +
               "Elementos que se restableceran:`n" +
               "- Volumen maestro, musica, criaturas, bloques, clima y categorias de audio`n" +
               "- Campo de vision (FOV) y nivel de brillo (gamma)`n" +
               "- Sensibilidad del mouse y opciones de accesibilidad (distorsion de efectos, subtitulos)`n" +
               "- Graficos basicos (distancia de renderizado, nubes, balanceo de camara, limite de FPS)`n" +
               "- Asignacion y jerarquia de paquetes de recursos predeterminados del servidor`n`n" +
               "Garantias de seguridad:`n" +
               "* NO se borrara ningun archivo de paquetes de recursos (.zip) en la carpeta resourcepacks.`n" +
               "* NO se perderan tus atajos de teclado: SmartKeySync restaura el mapeo oficial y protege las teclas aseguradas con candado.`n`n" +
               "Deseas restaurar options.txt ahora?"

        $result = [System.Windows.MessageBox]::Show(
            $msg,
            "Confirmacion - Reparar options.txt",
            'YesNo', 'Question'
        )
        if ($result -eq 'Yes') {
            if (Restore-OptionsTxt) {
                [System.Windows.MessageBox]::Show("El archivo options.txt ha sido restaurado exitosamente.", "Exito", 'OK', 'Information')
            } else {
                [System.Windows.MessageBox]::Show("No se pudo restaurar options.txt. Verifica que exista la plantilla en presets_graficos.", "Error", 'OK', 'Error')
            }
        }
    })

    $btnSalir.Add_Click({
        $window.Close()
    })

    $window.ShowDialog() | Out-Null
} catch {
    Write-Log -Mensaje "Error critico: $($_.Exception.Message)" -Nivel ERROR
    [System.Windows.MessageBox]::Show(
        "Ocurrio un error inesperado. Revisa logs/ para mas detalles.",
        "Error - Configurador 2026UNI",
        'OK', 'Error'
    )
} finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
}