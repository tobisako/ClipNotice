using System;
using System.Drawing;
using System.Windows.Forms;

namespace ClipNotice;

sealed class SettingsForm : Form
{
    public event Action? Changed;

    public SettingsForm()
    {
        Text = "ClipNotice 設定";
        Size = new Size(340, 266);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;

        const int lx = 20, cx = 110, ry = 20, rh = 36;

        // Font size
        var lblFont = new Label { Text = "文字サイズ", Location = new Point(lx, ry + 4), AutoSize = true };
        var slider = new TrackBar
        {
            Location = new Point(cx, ry), Size = new Size(150, 40),
            Minimum = 8, Maximum = 48, Value = (int)Settings.FontSize,
            TickFrequency = 8, SmallChange = 1
        };
        var lblVal = new Label
        {
            Text = $"{(int)Settings.FontSize}pt",
            Location = new Point(cx + 158, ry + 4), AutoSize = true
        };

        // Text color
        var lblTc = new Label { Text = "文字の色", Location = new Point(lx, ry + rh + 4), AutoSize = true };
        var btnTc = new Button
        {
            Location = new Point(cx, ry + rh), Size = new Size(44, 28),
            BackColor = Settings.TextColor, FlatStyle = FlatStyle.Flat
        };

        // BG color
        var lblBg = new Label { Text = "背景の色", Location = new Point(lx, ry + rh * 2 + 4), AutoSize = true };
        var btnBg = new Button
        {
            Location = new Point(cx, ry + rh * 2), Size = new Size(44, 28),
            BackColor = Settings.BgColor, FlatStyle = FlatStyle.Flat
        };

        // Word wrap
        var chkWrap = new CheckBox
        {
            Text = "改行する", Location = new Point(cx, ry + rh * 3 + 4),
            Checked = Settings.WordWrap, AutoSize = true
        };

        // Dismiss delay
        var lblDismiss = new Label { Text = "表示時間", Location = new Point(lx, ry + rh * 4 + 4), AutoSize = true };
        var sliderDismiss = new TrackBar
        {
            Location = new Point(cx, ry + rh * 4), Size = new Size(150, 40),
            Minimum = 1, Maximum = 5, Value = Settings.DismissMs / 1000,
            TickFrequency = 1, SmallChange = 1
        };
        var lblDismissVal = new Label
        {
            Text = $"{Settings.DismissMs / 1000}秒",
            Location = new Point(cx + 158, ry + rh * 4 + 4), AutoSize = true
        };

        slider.ValueChanged += (_, _) =>
        {
            Settings.FontSize = slider.Value;
            lblVal.Text = $"{slider.Value}pt";
            Changed?.Invoke();
        };

        btnTc.Click += (_, _) =>
        {
            using var dlg = new ColorDialog { Color = Settings.TextColor };
            if (dlg.ShowDialog() == DialogResult.OK)
            {
                Settings.TextColor = dlg.Color;
                btnTc.BackColor = dlg.Color;
                Changed?.Invoke();
            }
        };

        btnBg.Click += (_, _) =>
        {
            using var dlg = new ColorDialog { Color = Settings.BgColor };
            if (dlg.ShowDialog() == DialogResult.OK)
            {
                Settings.BgColor = dlg.Color;
                btnBg.BackColor = dlg.Color;
                Changed?.Invoke();
            }
        };

        chkWrap.CheckedChanged += (_, _) =>
        {
            Settings.WordWrap = chkWrap.Checked;
            Changed?.Invoke();
        };

        sliderDismiss.ValueChanged += (_, _) =>
        {
            Settings.DismissMs = sliderDismiss.Value * 1000;
            lblDismissVal.Text = $"{sliderDismiss.Value}秒";
        };

        Controls.AddRange(new Control[] { lblFont, slider, lblVal, lblTc, btnTc, lblBg, btnBg, chkWrap, lblDismiss, sliderDismiss, lblDismissVal });
    }
}
