import easyinstaller.debugdump;
import easyinstaller.inplace_path;
import easyinstaller.plugin;
import easyinstaller.project;
import easyinstaller.ci_profile;
import easyinstaller.ci_emit;
import easyinstaller.shell_hooks;
import easyinstaller.scriptbook_host;
import easyinstaller.versioninfo;
import std.file : mkdirRecurse, exists;
import std.path : buildPath, absolutePath;
import std.stdio : writeln, stderr;
import std.string : toLower, startsWith;

// Pull in builtin plugins
import easyinstaller.plugins.portable_zip;
import easyinstaller.plugins.nsis;
import easyinstaller.plugins.inno;
import easyinstaller.plugins.msi_msix;
import easyinstaller.plugins.appimage;
import easyinstaller.plugins.install_coordinator;

int main(string[] args)
{
    if (args.length < 2)
        return usage();

    auto cmd = args[1].toLower;
    try
    {
        switch (cmd)
        {
        case "--version":
        case "version":
            writeln(aboutLine());
            return 0;
        case "debug-dump":
            if (args.length >= 3)
            {
                writeDebugDump(args[2]);
                writeln("Wrote ", args[2]);
            }
            else
                writeln(buildDebugDump());
            return 0;
        case "inplace-path":
            return cmdInplace(args[2 .. $]);
        case "new-project":
            return cmdNewProject(args[2 .. $]);
        case "emit-ci":
            return cmdEmitCi(args[2 .. $]);
        case "build":
            return cmdBuild(args[2 .. $]);
        case "emit":
            return cmdEmit(args[2 .. $]);
        case "plugins":
            return cmdPlugins(args[2 .. $]);
        case "shell":
            return cmdShell(args[2 .. $]);
        case "help":
        case "--help":
        case "-h":
            return usage();
        default:
            stderr.writeln("Unknown command: ", args[1]);
            return usage();
        }
    }
    catch (Exception e)
    {
        stderr.writeln("error: ", e.msg);
        return 1;
    }
}

int usage()
{
    writeln(aboutLine());
    writeln(`
Usage:
  ibex inplace-path add|remove|list [dir]
  ibex new-project <dir> [--plugin=<id>] [--intent=package|ci-pipeline] [--runner=<id>]
  ibex emit-ci [dir] [--runner=<id>] [--plugin=<id>]
  ibex build <dir> [--plugin=<id>]
  ibex emit <dir> [--plugin=<id>]
  ibex plugins list|info <id>|describe <id>
  ibex plugins install-tool <id> [--dry-run]
  ibex plugins open-gui <id> [dir]
  ibex plugins install-gui <id>
  ibex shell install|uninstall
  ibex --version
  ibex debug-dump [file]

CI runners: github-actions, gitlab-ci, azure-pipelines, jenkins, circleci, bitbucket-pipelines
emit-ci writes workflow files + CI-INSTALLER.adoc only (no package build).
install-tool runs a Scriptbook playbook (bootstraps Scriptbook if needed).
open-gui emits sources and opens the third-party designer on that file.
`);
    return 0;
}

int cmdInplace(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("inplace-path requires add|remove|list");
        return 1;
    }
    auto sub = args[0].toLower;
    if (sub == "list")
    {
        writeln(listInPlace());
        return 0;
    }
    if (args.length < 2)
    {
        stderr.writeln("directory required");
        return 1;
    }
    if (sub == "add")
        writeln(addInPlace(args[1]));
    else if (sub == "remove")
        writeln(removeInPlace(args[1]));
    else
    {
        stderr.writeln("unknown subcommand: ", sub);
        return 1;
    }
    return 0;
}

int cmdNewProject(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("directory required");
        return 1;
    }
    string dir = args[0];
    string plugin = "portable-zip";
    string intent = "package";
    string runner = "github-actions";
    foreach (a; args[1 .. $])
    {
        if (a.length > 9 && a[0 .. 9] == "--plugin=")
            plugin = a[9 .. $];
        else if (a.length > 9 && a[0 .. 9] == "--intent=")
            intent = a[9 .. $];
        else if (a.length > 9 && a[0 .. 9] == "--runner=")
            runner = a[9 .. $];
    }
    auto path = createNewProject(absolutePath(dir), plugin, intent, runner);
    writeln("Created ", path);
    if (intent == "ci-pipeline")
        writeln("Also wrote ci-runner.sdl and emitted CI files (see CI-INSTALLER.adoc).");
    return 0;
}

int cmdEmitCi(string[] args)
{
    string dir = ".";
    string runnerOverride;
    string pluginOverride;
    foreach (a; args)
    {
        if (a.length > 9 && a[0 .. 9] == "--runner=")
            runnerOverride = a[9 .. $];
        else if (a.length > 9 && a[0 .. 9] == "--plugin=")
            pluginOverride = a[9 .. $];
        else if (!a.startsWith("--"))
            dir = a;
    }
    dir = absolutePath(dir);

    CiRunnerProfile profile;
    auto profilePath = ciProfilePath(dir);
    if (exists(profilePath))
        profile = loadCiProfile(dir);
    else
    {
        string plugin = "portable-zip";
        if (exists(projectFilePath(dir)))
            plugin = loadProject(dir).plugin;
        profile = defaultCiProfile(dir,
            runnerOverride.length ? runnerOverride : "github-actions", plugin);
        saveCiProfile(profile);
        writeln("Wrote ", profilePath);
    }
    if (runnerOverride.length)
        profile.runner = runnerOverride;
    if (pluginOverride.length)
        profile.plugin = pluginOverride;
    saveCiProfile(profile);

    auto result = emitCi(dir, profile);
    writeln(result.summary);
    return 0;
}

int cmdBuild(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("project directory required");
        return 1;
    }
    auto project = loadProject(args[0]);
    foreach (a; args[1 .. $])
    {
        if (a.length > 9 && a[0 .. 9] == "--plugin=")
            project.plugin = a[9 .. $];
    }
    auto plug = findPlugin(project.plugin);
    if (plug is null)
    {
        stderr.writeln("unknown plugin: ", project.plugin);
        return 1;
    }
    auto outDir = buildPath(project.rootDir, "dist");
    if (!exists(outDir))
        mkdirRecurse(outDir);
    writeln(plug.build(project, outDir));
    return 0;
}

int cmdEmit(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("project directory required");
        return 1;
    }
    auto project = loadProject(args[0]);
    foreach (a; args[1 .. $])
    {
        if (a.length > 9 && a[0 .. 9] == "--plugin=")
            project.plugin = a[9 .. $];
    }
    auto plug = findPlugin(project.plugin);
    if (plug is null)
    {
        stderr.writeln("unknown plugin: ", project.plugin);
        return 1;
    }
    auto outDir = buildPath(project.rootDir, "dist");
    if (!exists(outDir))
        mkdirRecurse(outDir);
    writeln(plug.emitSources(project, outDir));
    return 0;
}

int cmdPlugins(string[] args)
{
    if (!args.length || args[0].toLower == "list")
    {
        foreach (p; allPlugins())
        {
            auto tool = p.detectTool();
            writeln(p.id, "\t", p.displayName(), "\t",
                tool.length ? "tool=" ~ tool : "tool=missing",
                p.guiName.length ? "\tgui=" ~ p.guiName : "",
                p.installPlaybook.length ? "\tplaybook=" ~ p.installPlaybook : "");
        }
        return 0;
    }
    auto sub = args[0].toLower;
    if (sub == "install-scriptbook")
    {
        writeln(installScriptbook());
        return findScriptbook().length ? 0 : 1;
    }
    if (args.length < 2)
    {
        stderr.writeln("plugin id required");
        return 1;
    }
    auto p = findPlugin(args[1]);
    if (p is null)
    {
        stderr.writeln("unknown plugin: ", args[1]);
        return 1;
    }
    if (sub == "info")
    {
        auto g = guiInfoFor(p);
        writeln("id: ", p.id);
        writeln("name: ", p.displayName);
        writeln("targets: ", p.targets);
        writeln("canBuild: ", p.canBuild);
        writeln("tool: ", p.detectTool.length ? p.detectTool : "(none)");
        writeln("gui: ", g.name.length ? g.name : "(none)");
        writeln("guiPath: ", g.guiPath.length ? g.guiPath : "(none)");
        writeln("guiUrl: ", g.url);
        writeln("guiInstalled: ", g.guiInstalled);
        writeln("hint: ", g.detectDetail);
        writeln("installPlaybook: ", p.installPlaybook.length ? p.installPlaybook : "(none)");
        foreach (f; p.extrasSchema)
            writeln("extra: ", f.key, " (", f.type, ", default=", f.defaultValue, ") ", f.description);
        return 0;
    }
    if (sub == "describe")
    {
        writeln(describeJson(p));
        return 0;
    }
    if (sub == "install-tool")
    {
        bool dryRun;
        foreach (a; args[2 .. $])
            if (a == "--dry-run")
                dryRun = true;
        auto run = runInstallPlaybook(p, dryRun);
        writeln(run.summary);
        return run.status == 0 ? 0 : 1;
    }
    if (sub == "open-gui")
    {
        string dir = args.length >= 3 && !args[2].startsWith("--") ? args[2] : ".";
        auto project = loadProject(absolutePath(dir));
        project.plugin = p.id;
        auto outDir = buildPath(project.rootDir, "dist");
        if (!exists(outDir))
            mkdirRecurse(outDir);
        writeln(openDesigner(p, project, outDir));
        return 0;
    }
    if (sub == "install-gui")
    {
        if (!p.guiInstallUrl.length)
        {
            writeln("No GUI/install URL for ", p.id);
            return 0;
        }
        writeln(openUrl(p.guiInstallUrl));
        return 0;
    }
    stderr.writeln("unknown plugins subcommand: ", sub);
    return 1;
}

int cmdShell(string[] args)
{
    if (!args.length)
    {
        stderr.writeln("shell install|uninstall");
        return 1;
    }
    auto sub = args[0].toLower;
    if (sub == "install")
        writeln(installShell());
    else if (sub == "uninstall")
        writeln(uninstallShell());
    else
    {
        stderr.writeln("unknown: ", sub);
        return 1;
    }
    return 0;
}
