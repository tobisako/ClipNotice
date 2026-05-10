using System;
using System.Windows.Forms;

namespace ClipNotice;

sealed class ClipboardMonitor : ApplicationContext
{
    readonly StickyForm _sticky;
    readonly System.Windows.Forms.Timer _pollTimer;
    string _lastText = string.Empty;

    public ClipboardMonitor()
    {
        Settings.Load();
        _sticky = new StickyForm();

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
            _sticky.Dispose();
        }
        base.Dispose(disposing);
    }
}
