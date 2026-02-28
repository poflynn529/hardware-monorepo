load("//buck2:system_verilog.bzl", "SvModuleTSet", "SvPackageTSet", "SvSourcesInfo")

VivadoSynthInfo = provider(fields = {
    "utilization_report": provider_field(typing.Any),
    "timing_report":      provider_field(typing.Any),
})

# Sources and the output path are injected at run-time via -tclargs so that
# the TCL file itself contains no absolute paths and can be written at
# analysis time.
_SYNTH_TCL = """
# Reset the tclapp store so that stale/incompatible apps (e.g. aldec::riviera)
# don't abort the session before synthesis starts.
catch {{ tclapp::reset_tclstore }} err

set srcs     [lrange $argv 0 end-2]
set util_rpt [lindex $argv end-1]
set time_rpt [lindex $argv end]

foreach src $srcs {{
    read_verilog -sv $src
}}

synth_design -top {top} -part {part} -mode out_of_context{generics}
report_utilization -file $util_rpt
report_timing -delay_type max -max_paths 1 -nworst 1 -file $time_rpt
"""

def _vivado_synth_impl(ctx: AnalysisContext) -> list[Provider]:
    agg_pkgs = ctx.actions.tset(SvPackageTSet, children = [dep[SvSourcesInfo].transitive_packages for dep in ctx.attrs.deps])
    agg_mods = ctx.actions.tset(SvModuleTSet, children = [dep[SvSourcesInfo].transitive_modules for dep in ctx.attrs.deps])

    seen_pkgs = {}
    unique_sources = []
    for src_list in agg_pkgs.traverse(ordering = "postorder"):
        for src in src_list:
            if src.short_path not in seen_pkgs:
                seen_pkgs[src.short_path] = True
                unique_sources.append(src)

    for src_list in agg_mods.traverse(ordering = "topological"):
        unique_sources.extend(src_list)

    util_report   = ctx.actions.declare_output("{}.utilization.rpt".format(ctx.attrs.top_module))
    timing_report = ctx.actions.declare_output("{}.timing.rpt".format(ctx.attrs.top_module))

    generic_str = ""
    if ctx.attrs.parameters:
        items = " ".join(["{}={}".format(k, v) for k, v in ctx.attrs.parameters.items()])
        generic_str = " -generic {{{}}}".format(items)

    tcl_file = ctx.actions.write(
        "synth_{}.tcl".format(ctx.attrs.top_module),
        _SYNTH_TCL.format(
            top      = ctx.attrs.top_module,
            part     = ctx.attrs.part,
            generics = generic_str,
        ),
    )

    # flock serialises concurrent Vivado invocations (parallel Buck2 actions
    # share the same Vivado resource pool and crash otherwise).
    vivado_cmd = cmd_args(
        ["flock", "/tmp/vivado_synthesis.lock",
         "vivado", "-mode", "batch", "-nojournal", "-nolog", "-source", tcl_file, "-tclargs"],
        delimiter = " ",
    )
    for src in unique_sources:
        vivado_cmd.add(src)
    vivado_cmd.add(util_report.as_output())
    vivado_cmd.add(timing_report.as_output())

    script = ctx.actions.write(
        "vivado_synth_{}.sh".format(ctx.attrs.top_module),
        cmd_args(
            "#!/bin/bash",
            "set -e",
            vivado_cmd,
            delimiter = "\n",
        ),
        is_executable = True,
    )
    ctx.actions.run(
        cmd_args(["bash", script], hidden = unique_sources + [tcl_file, util_report.as_output(), timing_report.as_output()]),
        category = "vivado_synth",
    )

    return [
        DefaultInfo(default_output = util_report),
        VivadoSynthInfo(
            utilization_report = util_report,
            timing_report      = timing_report,
        ),
    ]

vivado_synth = rule(
    impl = _vivado_synth_impl,
    attrs = {
        "top_module": attrs.string(),
        "deps":       attrs.list(attrs.dep(providers = [SvSourcesInfo])),
        "parameters": attrs.dict(key = attrs.string(), value = attrs.string(), default = {}),
        "part":       attrs.string(default = "xc7a100tcsg324-1"),
    },
)

# ── Comparison rule ──────────────────────────────────────────────────────────

def _vivado_compare_impl(ctx: AnalysisContext) -> list[Provider]:
    util_reports   = [dep[VivadoSynthInfo].utilization_report for dep in ctx.attrs.synths]
    timing_reports = [dep[VivadoSynthInfo].timing_report      for dep in ctx.attrs.synths]
    out            = ctx.actions.declare_output("comparison.txt")

    # Args order: <util_a> <timing_a> <util_b> <timing_b> <output>
    cmd = cmd_args(
        [ctx.attrs.python_bin, ctx.attrs.compare_script],
        delimiter = " ",
    )
    cmd.add(util_reports[0])
    cmd.add(timing_reports[0])
    cmd.add(util_reports[1])
    cmd.add(timing_reports[1])
    cmd.add(out.as_output())

    script = ctx.actions.write(
        "vivado_compare.sh",
        cmd_args("#!/bin/bash", "set -e", cmd, delimiter = "\n"),
        is_executable = True,
    )
    ctx.actions.run(
        cmd_args(["bash", script], hidden = util_reports + timing_reports + [ctx.attrs.compare_script, out.as_output()]),
        category = "vivado_compare",
    )

    return [DefaultInfo(default_output = out)]

vivado_compare = rule(
    impl = _vivado_compare_impl,
    attrs = {
        "synths":         attrs.list(attrs.dep(providers = [VivadoSynthInfo])),
        "compare_script": attrs.source(),
        "python_bin":     attrs.string(default = "python3"),
    },
)
