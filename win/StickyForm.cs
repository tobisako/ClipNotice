using System;
using System.Drawing;
using System.Windows.Forms;

namespace ClipNotice;

sealed class StickyForm : Form
{
    const int MaxTextLength = 300;
    const int Pad = 12;
    const int Mar = 20;
    const int MaxWidth = 320;

    readonly Label _label;
    System.Windows.Forms.Timer? _timer;
    Point _screenDragStart;
    Point _formOriginAtDragStart;
    bool _dragging;
    Point? _savedLocation;

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

        MouseDown += OnStickyMouseDown;
        MouseMove += OnStickyMouseMove;
        MouseUp += OnStickyMouseUp;
        _label.MouseDown += OnStickyMouseDown;
        _label.MouseMove += OnStickyMouseMove;
        _label.MouseUp += OnStickyMouseUp;

        var menu = new ContextMenuStrip();
        menu.Items.Add("設定...", null, (_, _) =>
        {
            using var form = new SettingsForm();
            form.Changed += () => ShowText("プレビュー Preview\nABC abc 123 あいう");
            form.ShowDialog(this);
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit ClipNotice", null, (_, _) => Application.Exit());
        menu.Opened += (_, _) => _timer?.Stop();
        menu.Closed += (_, _) =>
        {
            _timer?.Dispose();
            _timer = new System.Windows.Forms.Timer { Interval = 2000 };
            _timer.Tick += (_, _) => { _timer.Stop(); Hide(); };
            _timer.Start();
        };
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
            : TextFormatFlags.NoPrefix;
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

        Location = _savedLocation ?? new Point(
            Screen.PrimaryScreen!.WorkingArea.Left + Mar,
            Screen.PrimaryScreen!.WorkingArea.Top + Mar);

        _timer?.Stop();
        _timer?.Dispose();
        _timer = new System.Windows.Forms.Timer { Interval = Settings.DismissMs };
        _timer.Tick += (_, _) => { _timer.Stop(); Hide(); };
        _timer.Start();

        Show();
        BringToFront();
    }

    void OnStickyMouseDown(object? s, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        _timer?.Stop();
        _screenDragStart = Cursor.Position;
        _formOriginAtDragStart = Location;
        _dragging = false;
    }

    void OnStickyMouseMove(object? s, MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        var dx = Cursor.Position.X - _screenDragStart.X;
        var dy = Cursor.Position.Y - _screenDragStart.Y;
        if (!_dragging && (Math.Abs(dx) > 4 || Math.Abs(dy) > 4))
            _dragging = true;
        if (_dragging)
            Location = new Point(_formOriginAtDragStart.X + dx, _formOriginAtDragStart.Y + dy);
    }

    void OnStickyMouseUp(object? s, MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left)
        {
            if (!_dragging)
            {
                Hide();
            }
            else
            {
                _savedLocation = Location;
                _timer?.Dispose();
                _timer = new System.Windows.Forms.Timer { Interval = Settings.DismissMs };
                _timer.Tick += (_, _) => { _timer.Stop(); Hide(); };
                _timer.Start();
            }
        }
        _dragging = false;
    }
}
