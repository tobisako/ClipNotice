using System;
using System.Drawing;
using System.Globalization;
using System.Windows.Forms;

namespace ClipNotice;

// Mirrors mac/Sources/ClipNotice/ColorPickerPopover.swift.
// Z-order: Owner = SettingsForm + TopMost = always above settings (and sticky).
sealed class ColorPickerForm : Form, IMessageFilter
{
    const int SwatchSize = 24;
    const int Gap = 4;
    const int Inset = 8;
    const int TitleH = 18;
    const int TitleGap = 6;
    const int HexRowH = 24;
    const int Cols = 8;
    const int Rows = 4;

    static readonly int[][] Palette = new[]
    {
        // Grays
        new[] { 0xFFFFFF, 0xE5E5E5, 0xBFBFBF, 0x8C8C8C, 0x595959, 0x262626, 0x000000, 0x594D73 },
        // Reds / Oranges / Browns
        new[] { 0xFFCCCC, 0xFF8080, 0xFF0000, 0xBF0000, 0xFFB266, 0xFF8000, 0xA65900, 0x996633 },
        // Yellows / Greens
        new[] { 0xFFFA99, 0xFFFF00, 0xB3E64D, 0x4DBF4D, 0x00FF00, 0x008000, 0x40CCB3, 0x008080 },
        // Blues / Purples / Pinks
        new[] { 0xB3D9FF, 0x4D99FF, 0x0000FF, 0x0000BF, 0x994DE6, 0x800080, 0xFF66B3, 0xFFBFDE },
    };

    public Action<Color>? OnChange;
    public Action? OnClose;

    readonly Label _titleLabel;
    readonly TextBox _hexField;
    bool _filterInstalled;

    protected override bool ShowWithoutActivation => true;

    public ColorPickerForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        BackColor = SystemColors.Control;
        KeyPreview = true;

        var width = Inset + Cols * SwatchSize + (Cols - 1) * Gap + Inset;
        var swatchH = Rows * SwatchSize + (Rows - 1) * Gap;
        var height = Inset + TitleH + TitleGap + swatchH + Gap + HexRowH + Inset;
        ClientSize = new Size(width, height);

        _titleLabel = new Label
        {
            Location = new Point(Inset, Inset),
            Size = new Size(width - Inset * 2, TitleH),
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Segoe UI", 9f, FontStyle.Bold),
        };
        Controls.Add(_titleLabel);

        var swatchTop = Inset + TitleH + TitleGap;
        for (var ri = 0; ri < Rows; ri++)
        {
            for (var ci = 0; ci < Cols; ci++)
            {
                var rgb = Palette[ri][ci];
                var color = Color.FromArgb((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
                var btn = new Button
                {
                    Location = new Point(Inset + ci * (SwatchSize + Gap),
                                         swatchTop + ri * (SwatchSize + Gap)),
                    Size = new Size(SwatchSize, SwatchSize),
                    BackColor = color,
                    FlatStyle = FlatStyle.Flat,
                    TabStop = false,
                    Tag = color,
                };
                btn.FlatAppearance.BorderColor = Color.FromArgb(64, 0, 0, 0);
                btn.FlatAppearance.BorderSize = 1;
                btn.Click += (s, _) =>
                {
                    var c = (Color)((Button)s!).Tag!;
                    _hexField.Text = HexOf(c);
                    OnChange?.Invoke(c);
                };
                Controls.Add(btn);
            }
        }

        var hexY = height - HexRowH - Inset;
        _hexField = new TextBox
        {
            Location = new Point(Inset, hexY),
            Size = new Size(100, HexRowH),
            Font = new Font("Consolas", 9f),
            PlaceholderText = "#RRGGBB",
            MaxLength = 7,
        };
        _hexField.KeyDown += (_, e) =>
        {
            if (e.KeyCode == Keys.Enter) { ApplyHex(); e.SuppressKeyPress = true; }
        };
        Controls.Add(_hexField);

        var applyBtn = new Button
        {
            Location = new Point(Inset + 108, hexY),
            Size = new Size(50, HexRowH),
            Text = "適用",
            FlatStyle = FlatStyle.Standard,
            TabStop = false,
        };
        applyBtn.Click += (_, _) => ApplyHex();
        Controls.Add(applyBtn);
    }

    public void ShowPicker(Form anchor, Color current, string title)
    {
        if (Visible) return;
        _titleLabel.Text = title;
        _hexField.Text = HexOf(current);

        var x = anchor.Right + 8;
        var y = anchor.Top + (anchor.Height - Height) / 2;
        var screen = Screen.FromControl(anchor).WorkingArea;
        if (x + Width > screen.Right) x = anchor.Left - Width - 8;
        if (y + Height > screen.Bottom) y = screen.Bottom - Height;
        if (y < screen.Top) y = screen.Top;
        Location = new Point(x, y);

        Owner = anchor;
        Show();
        InstallFilter();
    }

    public new void Hide()
    {
        if (!Visible) return;
        RemoveFilter();
        base.Hide();
        OnClose?.Invoke();
    }

    void ApplyHex()
    {
        if (TryParseHex(_hexField.Text, out var c)) OnChange?.Invoke(c);
    }

    static string HexOf(Color c) => $"#{c.R:X2}{c.G:X2}{c.B:X2}";

    static bool TryParseHex(string s, out Color color)
    {
        color = Color.Black;
        s = s.Trim();
        if (s.StartsWith('#')) s = s[1..];
        if (s.Length != 6) return false;
        if (!int.TryParse(s, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var v)) return false;
        color = Color.FromArgb((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
        return true;
    }

    void InstallFilter()
    {
        if (_filterInstalled) return;
        Application.AddMessageFilter(this);
        _filterInstalled = true;
    }

    void RemoveFilter()
    {
        if (!_filterInstalled) return;
        Application.RemoveMessageFilter(this);
        _filterInstalled = false;
    }

    public bool PreFilterMessage(ref Message m)
    {
        const int WM_LBUTTONDOWN = 0x0201;
        const int WM_RBUTTONDOWN = 0x0204;
        const int WM_NCLBUTTONDOWN = 0x00A1;
        const int WM_NCRBUTTONDOWN = 0x00A4;

        if (m.Msg is WM_LBUTTONDOWN or WM_RBUTTONDOWN or WM_NCLBUTTONDOWN or WM_NCRBUTTONDOWN)
        {
            var p = Cursor.Position;
            var rect = new Rectangle(Location, Size);
            if (!rect.Contains(p)) Hide();
        }
        return false;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) RemoveFilter();
        base.Dispose(disposing);
    }
}
