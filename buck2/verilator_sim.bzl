load("//buck2:system_verilog.bzl", "SvIncludeDirTSet", "SvModuleTSet", "SvPackageTSet", "SvSourcesInfo")

VerilatorModelInfo = provider(fields = {
    "lib": provider_field(typing.Any),
    "include_dir": provider_field(typing.Any),
    "top_module": provider_field(typing.Any),
    "trace": provider_field(typing.Any),
})

def _verilator_model_impl(ctx: AnalysisContext) -> list[Provider]:
    lib = ctx.actions.declare_output("Vtop__ALL.a")
    include_dir = ctx.actions.declare_output("include", dir = True)

    agg_pkgs = ctx.actions.tset(SvPackageTSet, children = [dep[SvSourcesInfo].transitive_packages for dep in ctx.attrs.deps])
    agg_mods = ctx.actions.tset(SvModuleTSet, children = [dep[SvSourcesInfo].transitive_modules for dep in ctx.attrs.deps])
    agg_dirs = ctx.actions.tset(SvIncludeDirTSet, children = [dep[SvSourcesInfo].transitive_include_dirs for dep in ctx.attrs.deps])

    seen_pkgs = {}
    unique_sources = []
    for src_list in agg_pkgs.traverse(ordering = "postorder"):
        for src in src_list:
            if src.short_path not in seen_pkgs:
                seen_pkgs[src.short_path] = True
                unique_sources.append(src)
    for src_list in agg_mods.traverse(ordering = "topological"):
        unique_sources.extend(src_list)

    unique_dirs = [d for dir_list in agg_dirs.traverse(ordering = "topological") for d in dir_list]

    vargs = ["verilator", "-cc", "--vpi", "--public-flat-rw", "--prefix", "Vtop", "--build"]
    vargs.extend(["--top-module", ctx.attrs.top_module])
    vargs.extend(["--timescale", "1ns/1ps"])

    if ctx.attrs.trace:
        vargs.extend(["--trace", "--trace-fst", "--trace-structs"])

    vargs.extend(ctx.attrs.compile_args)

    for key, value in ctx.attrs.parameters.items():
        vargs.append("-G{}={}".format(key, value))

    for d in unique_dirs:
        vargs.append(cmd_args("+incdir+", d, delimiter = ""))

    vargs.extend(["-Mdir", "$MDIR"])

    for src in unique_sources:
        vargs.append(src)

    script_content = cmd_args(
        "#!/bin/bash",
        "set -e",
        "MDIR=$(mktemp -d)",
        "trap 'rm -rf \"$MDIR\"' EXIT",
        cmd_args(vargs, delimiter = " "),
        cmd_args("cp \"$MDIR/Vtop__ALL.a\"", lib.as_output(), delimiter = " "),
        cmd_args("mkdir -p", include_dir.as_output(), delimiter = " "),
        cmd_args("cp \"$MDIR\"/*.h", include_dir.as_output(), delimiter = " "),
        delimiter = "\n",
    )

    build_script = ctx.actions.write(
        "verilator_build.sh",
        script_content,
        is_executable = True,
    )

    ctx.actions.run(
        cmd_args(["bash", build_script], hidden = unique_sources + [lib.as_output(), include_dir.as_output()]),
        category = "verilator",
    )

    return [
        DefaultInfo(default_output = lib),
        VerilatorModelInfo(
            lib = lib,
            include_dir = include_dir,
            top_module = ctx.attrs.top_module,
            trace = ctx.attrs.trace,
        ),
    ]

verilator_model = rule(
    impl = _verilator_model_impl,
    attrs = {
        "top_module": attrs.string(),
        "deps": attrs.list(attrs.dep(providers = [SvSourcesInfo])),
        "parameters": attrs.dict(key = attrs.string(), value = attrs.string(), default = {}),
        "compile_args": attrs.list(attrs.string(), default = []),
        "trace": attrs.bool(default = True),
    },
)
