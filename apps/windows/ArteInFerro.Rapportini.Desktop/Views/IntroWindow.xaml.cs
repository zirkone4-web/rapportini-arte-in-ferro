using System.Media;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class IntroWindow : Window
{
    public IntroWindow()
    {
        InitializeComponent();
        Loaded += (_, _) => PlayIntro();
    }

    private void PlayIntro()
    {
        var duration = TimeSpan.FromSeconds(4);
        if (IntroBackground.RenderTransform is ScaleTransform backgroundScale)
        {
            var zoom = new DoubleAnimation(1.2, 1.55, duration)
            {
                EasingFunction = new CubicEase { EasingMode = EasingMode.EaseIn }
            };
            backgroundScale.BeginAnimation(ScaleTransform.ScaleXProperty, zoom);
            backgroundScale.BeginAnimation(ScaleTransform.ScaleYProperty, zoom);
        }

        IntroLogo.BeginAnimation(
            OpacityProperty,
            new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(850))
            {
                BeginTime = TimeSpan.FromMilliseconds(2100)
            });

        if (IntroLogo.RenderTransform is ScaleTransform logoScale)
        {
            var arrival = new DoubleAnimation(.25, 1, TimeSpan.FromMilliseconds(900))
            {
                BeginTime = TimeSpan.FromMilliseconds(2050),
                EasingFunction = new BackEase
                {
                    EasingMode = EasingMode.EaseOut,
                    Amplitude = .25
                }
            };
            logoScale.BeginAnimation(ScaleTransform.ScaleXProperty, arrival);
            logoScale.BeginAnimation(ScaleTransform.ScaleYProperty, arrival);
        }

        _ = Task.Delay(2350).ContinueWith(
            _ => Dispatcher.Invoke(() => SystemSounds.Asterisk.Play()));

        var close = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(500))
        {
            BeginTime = TimeSpan.FromMilliseconds(4000)
        };
        close.Completed += (_, _) => Close();
        BeginAnimation(OpacityProperty, close);
    }

    private void SkipIntroClick(object sender, MouseButtonEventArgs e) => Close();
}
