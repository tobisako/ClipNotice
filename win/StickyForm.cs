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

        var flags = Settings.WordWrap
            ? TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix
            : TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix;
        var proposed = Settings.WordWrap
            ? new Size(MaxWidth - Pad * 2, int.MaxValue)
            : new Size(int.MaxValue, int.MaxValue);
        var measured = TextRenderer.MeasureText(display, _label.Font, proposed, flags);

        var w = Settings.WordWrap
            ? MaxWidth
            : Math.Min(measured.Width + Pad * 2 + 12,
                       Screen.PrimaryScreen!.WorkingArea.Width - Mar * 2);
        var h = measured.Height + Pad * 2 + 8;

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
