using System;
using System.Drawing;
using System.Windows.Forms;

namespace ClipNotice;

sealed class ClipboardMonitor : ApplicationContext
{
    readonly StickyForm _sticky;
    readonly System.Windows.Forms.Timer _pollTimer;
    readonly NotifyIcon _tray;
    string _lastText = string.Empty;

    public ClipboardMonitor()
    {
        Settings.Load();
        _sticky = new StickyForm();

        var menu = new ContextMenuStrip();
        menu.Items.Add("設定...", null, (_, _) =>
        {
            using var form = new SettingsForm();
            form.Changed += () => _sticky.ShowText(Settings.WordWrap
                ? "プレビュー Preview\nABC abc 123 あいう"
                : "プレビュー Preview  ABC abc 123 あいう");
            form.ShowDialog();
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit ClipNotice", null, (_, _) => ExitThread());

        _tray = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "ClipNotice",
            Visible = true,
            ContextMenuStrip = menu,
        };

        try
        {
            if (Clipboard.ContainsText())
                _lastText = Clipboard.GetText() ?? string.Empty;
        }
        catch
        {
            // Clipboard locked at startup — accept that the first poll may show it
        }

        _pollTimer = new System.Windows.Forms.Timer { Interval = 500 };
        _pollTimer.Tick += Poll;
        _pollTimer.Start();
    }

    void Poll(object? sender, EventArgs e)
    {
        try
        {
            if (!Clipboard.ContainsText()) return;
            var text = Clipboard.GetText();
            if (string.IsNullOrEmpty(text) || text == _lastText) return;
            _lastText = text;
            _sticky.ShowText(text);
        }
        catch
        {
            // Clipboard unavailable (another app holds it) — skip this tick
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _pollTimer.Stop();
            _pollTimer.Dispose();
            _tray.Visible = false;
            _tray.Dispose();
            _sticky.Dispose();
        }
        base.Dispose(disposing);
    }
}
