using System.Drawing;
using Microsoft.Win32;

namespace ClipNotice;

static class Settings
{
    const string Key = @"Software\ClipNotice";

    static float _fontSize = 13f;
    static Color _textColor = Color.Black;
    static Color _bgColor = Color.LightYellow;
    static bool _wordWrap = true;

    public static float FontSize
    {
        get => _fontSize;
        set { _fontSize = value; Save(); }
    }

    public static Color TextColor
    {
        get => _textColor;
        set { _textColor = value; Save(); }
    }

    public static Color BgColor
    {
        get => _bgColor;
        set { _bgColor = value; Save(); }
    }

    public static bool WordWrap
    {
        get => _wordWrap;
        set { _wordWrap = value; Save(); }
    }

    public static void Load()
    {
        using var key = Registry.CurrentUser.OpenSubKey(Key);
        if (key is null) return;
        if (key.GetValue("FontSize") is int fs) _fontSize = fs;
        if (key.GetValue("TextColorArgb") is int tc) _textColor = Color.FromArgb(tc);
        if (key.GetValue("BgColorArgb") is int bc) _bgColor = Color.FromArgb(bc);
        if (key.GetValue("WordWrap") is int ww) _wordWrap = ww != 0;
    }

    static void Save()
    {
        using var key = Registry.CurrentUser.CreateSubKey(Key);
        key.SetValue("FontSize", (int)_fontSize);
        key.SetValue("TextColorArgb", _textColor.ToArgb());
        key.SetValue("BgColorArgb", _bgColor.ToArgb());
        key.SetValue("WordWrap", _wordWrap ? 1 : 0);
    }
}
