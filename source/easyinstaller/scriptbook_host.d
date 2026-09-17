module easyinstaller.scriptbook_host;

import easyinstaller.paths : configRoot;
import easyinstaller.plugin : InstallerPlugin, which;
import std.file : exists, thisExePath;
import std.path : buildPath, dirName;
import std.process : execute;
import std.array : join;

/// Locate the Scriptbook CLI (PATH, Ibex bin, sibling checkout).
string findScriptbook()
{
    auto w = which("scriptbook");
    if (w.length)
        return w;
    version (Windows)
    {
        auto local = buildPath(configRoot(), "bin", "scriptbook.exe");
        if (exists(local))
            return local;
    }
    else
    {
        auto local = buildPath(configRoot(), "bin", "scriptbook");
        if (exists(local))
            return local;
    }
    foreach (c; siblingScriptbookBins())
        if (exists(c))
            return c;
    return "";
}

string playbooksDir()
{
    foreach (d; playbookCandidates())
        if (exists(d))
            return d;
    return playbookCandidates()[0];
}

string playbookPath(string filename)
{
    if (!filename.length)
        return "";
    auto dir = playbooksDir();
    auto p = buildPath(dir, filename);
    return exists(p) ? p : "";
}

string bootstrapScript()
{
    version (Windows)
        enum name = "install-scriptbook.ps1";
    else
        enum name = "install-scriptbook.sh";
    foreach (d; scriptDirCandidates())
    {
        auto p = buildPath(d, name);
        if (exists(p))
            return p;
    }
    return "";
}

/// Install Scriptbook via the bootstrap script (does not require Scriptbook).
string installScriptbook()
{
    auto already = findScriptbook();
    if (already.length)
        return "Scriptbook already at " ~ already;
    auto script = bootstrapScript();
    if (!script.length)
        return "Bootstrap script not found. Clone ibex-install-builder and run scripts/install-scriptbook"
            ~ (onWindows() ? ".ps1" : ".sh")
            ~ ", or download a release from https://github.com/dev-centr/scriptbook/releases";
    version (Windows)
    {
        auto r = execute([
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script
        ]);
        auto found = findScriptbook();
        if (r.status != 0)
            return "Scriptbook bootstrap failed:\n" ~ r.output;
        return r.output ~ (found.length ? "\nScriptbook: " ~ found : "\nScriptbook not on PATH yet — see bootstrap output.");
    }
    else
    {
        auto r = execute(["bash", script]);
        auto found = findScriptbook();
        if (r.status != 0)
            return "Scriptbook bootstrap failed:\n" ~ r.output;
        return r.output ~ (found.length ? "\nScriptbook: " ~ found : "\nScriptbook not on PATH yet — see bootstrap output.");
    }
}

struct PlaybookRun
{
    int status;
    string summary;
}

/// Run a plugin install playbook through Scriptbook (bootstraps Scriptbook if needed).
PlaybookRun runInstallPlaybook(InstallerPlugin plugin, bool dryRun)
{
    PlaybookRun result;
    if (!plugin.installPlaybook.length)
    {
        result.status = 0;
        result.summary = plugin.id ~ " has no install playbook (built-in or optional).";
        return result;
    }
    if (!targetsCurrentOs(plugin))
    {
        result.status = 1;
        result.summary = plugin.id ~ " targets " ~ plugin.targets.join(",")
            ~ " — not this OS.";
        return result;
    }
    auto sb = findScriptbook();
    if (!sb.length)
    {
        auto boot = installScriptbook();
        sb = findScriptbook();
        if (!sb.length)
        {
            result.status = 1;
            result.summary = boot ~ "\nCannot run playbooks without Scriptbook.";
            return result;
        }
    }
    auto cmk = playbookPath(plugin.installPlaybook);
    if (!cmk.length)
    {
        result.status = 1;
        result.summary = "Playbook not found: " ~ plugin.installPlaybook
            ~ " (looked in " ~ playbooksDir() ~ ")";
        return result;
    }
    string[] cmd = [sb, "run", cmk, "--yes"];
    if (dryRun)
        cmd ~= "--dry-run";
    auto r = execute(cmd);
    result.status = r.status;
    result.summary = "scriptbook " ~ (dryRun ? "dry-run " : "") ~ cmk ~ "\n" ~ r.output;
    return result;
}

bool targetsCurrentOs(InstallerPlugin p)
{
    foreach (t; p.targets)
    {
        if (t == "all")
            return true;
        version (Windows)
        {
            if (t == "windows")
                return true;
        }
        else version (OSX)
        {
            if (t == "macos")
                return true;
        }
        else
        {
            if (t == "linux")
                return true;
        }
    }
    return false;
}

private bool onWindows()
{
    version (Windows)
        return true;
    else
        return false;
}

private string exeDir()
{
    return dirName(thisExePath());
}

private string[] playbookCandidates()
{
    return [
        buildPath(exeDir(), "playbooks"),
        buildPath(exeDir(), "..", "playbooks"),
        buildPath(configRoot(), "playbooks"),
    ];
}

private string[] scriptDirCandidates()
{
    return [
        buildPath(exeDir(), "scripts"),
        buildPath(exeDir(), "..", "scripts"),
    ];
}

private string[] siblingScriptbookBins()
{
    auto parent = dirName(exeDir());
    version (Windows)
        return [
            buildPath(parent, "scriptbook", "cli", "bin", "scriptbook.exe"),
            buildPath(exeDir(), "..", "scriptbook", "cli", "bin", "scriptbook.exe"),
        ];
    else
        return [
            buildPath(parent, "scriptbook", "cli", "bin", "scriptbook"),
            buildPath(exeDir(), "..", "scriptbook", "cli", "bin", "scriptbook"),
        ];
}
