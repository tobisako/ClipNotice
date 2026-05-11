using System;
using System.Drawing;
using System.Windows.Forms;

namespace ClipNotice;

sealed class SettingsForm : Form
{
    public event Action? Changed;

    readonly Button _btnTc;
    readonly Button _btnBg;
    readonly ColorPickerForm _picker;
    readonly System.Windows.Forms.Timer _autoClose;
    bool _isPerformingClose;

    public SettingsForm()
    {
        Text = "ClipNotice 設定";
        Size = new Size(360, 360);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        TopMost = true;
        ShowInTaskbar = false;

        _picker = new ColorPickerForm();
        _picker.OnClose = () =>
        {
            if (_isPerformingClose) return;
            Activate();
            ResetAutoClose();
        };

        const int lx = 20, cx = 110, ry = 20, rh = 36;

        // Font size
        var lblFont = new Label { Text = "文字サイズ", Location = new Point(lx, ry + 4), AutoSize = true };
        var slider = new TrackBar
        {
            Location = new Point(cx, ry), Size = new Size(170, 40),
            Minimum = 8, Maximum = 48, Value = (int)Settings.FontSize,
            TickFrequency = 8, SmallChange = 1
        };
        var lblVal = new Label
        {
            Text = $"{(int)Settings.FontSize}pt",
            Location = new Point(cx + 178, ry + 4), AutoSize = true
        };

        // Text color
        var lblTc = new Label { Text = "文字の色", Location = new Point(lx, ry + rh + 4), AutoSize = true };
        _btnTc = new Button
        {
            Location = new Point(cx, ry + rh), Size = new Size(44, 28),
            BackColor = Settings.TextColor, FlatStyle = FlatStyle.Flat,
            TabStop = false,
        };
        _btnTc.FlatAppearance.BorderColor = Color.FromArgb(80, 0, 0, 0);

        // BG color
        var lblBg = new Label { Text = "背景の色", Location = new Point(lx, ry + rh * 2 + 4), AutoSize = true };
        _btnBg = new Button
        {
            Location = new Point(cx, ry + rh * 2), Size = new Size(44, 28),
            BackColor = Settings.BgColor, FlatStyle = FlatStyle.Flat,
            TabStop = false,
        };
        _btnBg.FlatAppearance.BorderColor = Color.FromArgb(80, 0, 0, 0);

        // Word wrap
        var chkWrap = new CheckBox
        {
            Text = "改行する", Location = new Point(cx, ry + rh * 3 + 4),
            Checked = Settings.WordWrap, AutoSize = true
        };

        // Section header: 表示時間
        var lblTimerSection = new Label
        {
            Text = "表示時間",
            Location = new Point(lx, ry + rh * 4 + 4),
            AutoSize = true,
            ForeColor = SystemColors.GrayText,
            Font = new Font("Segoe UI", 8.25f),
        };

        // Sticky dismiss delay (付箋)
        var lblDismiss = new Label { Text = "付箋", Location = new Point(lx, ry + rh * 5 + 4), AutoSize = true };
        var sliderDismiss = new TrackBar
        {
            Location = new Point(cx, ry + rh * 5), Size = new Size(170, 40),
            Minimum = 1, Maximum = 10, Value = Settings.DismissMs / 500,
            TickFrequency = 1, SmallChange = 1
        };
        var lblDismissVal = new Label
        {
            Text = FormatDelay(Settings.DismissMs),
            Location = new Point(cx + 178, ry + rh * 5 + 4), AutoSize = true
        };

        // Settings auto-close (設定)
        var lblAutoClose = new Label { Text = "設定", Location = new Point(lx, ry + rh * 6 + 4), AutoSize = true };
        var sliderAutoClose = new TrackBar
        {
            Location = new Point(cx, ry + rh * 6), Size = new Size(170, 40),
            Minimum = 1, Maximum = 5, Value = Settings.SettingsAutoCloseSecs / 2,
            TickFrequency = 1, SmallChange = 1
        };
        var lblAutoCloseVal = new Label
        {
            Text = $"{Settings.SettingsAutoCloseSecs}秒",
            Location = new Point(cx + 178, ry + rh * 6 + 4), AutoSize = true
        };

        slider.ValueChanged += (_, _) =>
        {
            Settings.FontSize = slider.Value;
            lblVal.Text = $"{slider.Value}pt";
            Changed?.Invoke();
            ResetAutoClose();
        };

        _btnTc.MouseDown += (_, _) => OpenPicker(_btnTc, "文字の色", Settings.TextColor, c =>
        {
            Settings.TextColor = c;
            _btnTc.BackColor = c;
            Changed?.Invoke();
        });

        _btnBg.MouseDown += (_, _) => OpenPicker(_btnBg, "背景の色", Settings.BgColor, c =>
        {
            Settings.BgColor = c;
            _btnBg.BackColor = c;
            Changed?.Invoke();
        });

        chkWrap.CheckedChanged += (_, _) =>
        {
            Settings.WordWrap = chkWrap.Checked;
            Changed?.Invoke();
            ResetAutoClose();
        };

        sliderDismiss.ValueChanged += (_, _) =>
        {
            Settings.DismissMs = sliderDismiss.Value * 500;
            lblDismissVal.Text = FormatDelay(Settings.DismissMs);
            ResetAutoClose();
        };

        sliderAutoClose.ValueChanged += (_, _) =>
        {
            var secs = sliderAutoClose.Value * 2;
            Settings.SettingsAutoCloseSecs = secs;
            lblAutoCloseVal.Text = $"{secs}秒";
            ResetAutoClose();
        };

        Controls.AddRange(new Control[]
        {
            lblFont, slider, lblVal,
            lblTc, _btnTc,
            lblBg, _btnBg,
            chkWrap,
            lblTimerSection,
            lblDismiss, sliderDismiss, lblDismissVal,
            lblAutoClose, sliderAutoClose, lblAutoCloseVal,
        });

        _autoClose = new System.Windows.Forms.Timer();
        _autoClose.Tick += (_, _) =>
        {
            _autoClose.Stop();
            if (_picker.Visible) return;  // ピッカー表示中はスキップ
            Close();
        };
    }

    void OpenPicker(Button anchorBtn, string title, Color current, Action<Color> onChange)
    {
        if (_picker.Visible) { _picker.Hide(); return; }
        _autoClose.Stop();
        _picker.OnChange = onChange;
        _picker.ShowPicker(this, current, title);
        BringToFront();  // 設定をピッカーの直下に保つため再前面化(ピッカーは Owner=this+TopMost で上)
    }

    void ResetAutoClose()
    {
        _autoClose.Stop();
        _autoClose.Interval = Settings.SettingsAutoCloseSecs * 1000;
        _autoClose.Start();
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        ResetAutoClose();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        _isPerformingClose = true;
        if (_picker.Visible) _picker.Hide();
        _isPerformingClose = false;
        _autoClose.Stop();
        base.OnFormClosing(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _autoClose.Dispose();
            _picker.Dispose();
        }
        base.Dispose(disposing);
    }

    static string FormatDelay(int ms) =>
        ms % 1000 == 0 ? $"{ms / 1000}秒" : $"{ms / 1000.0:0.#}秒";
}
