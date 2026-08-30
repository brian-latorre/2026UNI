Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Configurador Gráfico 2026UNI" Height="450" Width="600"
        WindowStartupLocation="CenterScreen" Background="#0B0B0B" Foreground="#FFFFFF"
        FontFamily="Segoe UI" ResizeMode="NoResize">
    
    <!-- Definición de estilos para efecto Hover en botones (opcional pero elegante) -->
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                CornerRadius="4" 
                                BorderThickness="0">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Opacity" Value="0.8"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Grid>
        <StackPanel Margin="40" VerticalAlignment="Center">
            
            <TextBlock Text="CONFIGURADOR DE RENDIMIENTO" FontSize="26" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,10" Foreground="#FFFFFF"/>
            <TextBlock Text="Selecciona el perfil que mejor se adapte a tu PC" FontSize="14" HorizontalAlignment="Center" Margin="0,0,0,40" Foreground="#CCCCCC"/>
            
            <!-- Botones Principales -->
            <Button Name="btnNormal" Content="🎮 APLICAR PERFIL NORMAL" FontSize="18" FontWeight="Bold" 
                    Background="#BF1515" Foreground="White" Height="55" Margin="0,0,0,15"/>
                    
            <Button Name="btnLite" Content="⚡ APLICAR PERFIL LITE" FontSize="18" FontWeight="Bold" 
                    Background="#222222" Foreground="#CCCCCC" Height="55" Margin="0,0,0,40"/>
            
            <Separator Background="#333333" Margin="0,0,0,25" Height="1"/>
            
            <!-- Sección Avanzada -->
            <TextBlock Text="Opciones Avanzadas (Reparación)" FontSize="13" FontWeight="SemiBold" Foreground="#888888" Margin="0,0,0,15" HorizontalAlignment="Center"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <Button Name="btnResetControles" Content="Restablecer Controles" Background="#151515" Foreground="#AAAAAA" Padding="20,10" Margin="0,0,15,0"/>
                <Button Name="btnResetShaders" Content="Reparar Shaders" Background="#151515" Foreground="#AAAAAA" Padding="20,10"/>
            </StackPanel>
            
        </StackPanel>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Mostrar la ventana en pantalla
$window.ShowDialog() | Out-Null
                                