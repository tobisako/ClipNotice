using System;
using System.Drawing;
using System.Windows.Forms;

namespace ClipNotice;

sealed class StickyForm : Form
{
    const int MaxTextLength = 300;
    const int DismissMs = 3000;
    const int Pad = 12;
    const int Mar = 20;
    const int MaxWidth = 320;

    readonly Label _label;
    System.Windows.Forms.Timer? _timer;

    public StickyForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        Opacity = 0.95;

        _label = new Label
        {
            AutoSize = false,
            Dock = DockStyle.Fill,
            Padding = new Padding(Pad),
        };
        Controls.Add(_label);

        MouseClick += (_, _) => Hide();
        _label.MouseClick += (_, _) => Hide();

        var menu = new ContextMenuStrip();
        menu.Items.Add("設定...", null, (_, _) =>
        {
            using var form = new SettingsForm();
            form.Changed += () => ShowText("プレビュー Preview\nABC abc 123 あいう");
            form.ShowDialog(this);
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit ClipNotice", null, (_, _) => Application.Exit());
        ContextMenuStrip = menu;
        _label.ContextMenuStrip = menu;
    }

    public void ShowText(string text)
    {
        var display = text.Length > MaxTextLength
            ? text[..MaxTextLength] + "…"
            : text;

        _label.Text = display;
        _label.Font = new Font("Segoe UI", Settings.FontSize);
        _label.ForeColor = Settings.TextColor;
        BackColor = Settings.BgColor;

        SizeF measured;
        using (var g = CreateGraphics())
        {
            var fmt = Settings.WordWrap
                ? new StringFormat { Trimming = StringTrimming.Word }
                : new StringFormat { FormatFlags = StringFormatFlags.NoWrap };
            measured = g.MeasureString(display, _label.Font,
                Settings.WordWrap ? MaxWidth - Pad * 2 : int.MaxValue, fmt);
        }

        var w = Settings.WordWrap
            ? MaxWidth
            : Math.Min((int)measured.Width + Pad * 2 + 4,
                       Screen.PrimaryScreen!.WorkingArea.Width - Mar * 2);
        var h = (int)measured.Height + Pad * 2 + 4;

        Size = new Size(Math.Max(w, 80), Math.Max(h, 40));

        var area = Screen.PrimaryScreen!.WorkingArea;
        Location = new Point(area.Left + Mar, area.Top + Mar);

        _timer?.Stop();
        _timer?.Dispose();
        _timer = new System.Windows.Forms.Timer { Interval = DismissMs };
        _timer.Tick += (_, _) => { _timer.Stop(); Hide(); };
        _timer.Start();

        Show();
        BringToFront();
    }
}
