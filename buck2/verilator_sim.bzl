load("//buck2:system_verilog.bzl", "SvSourcesInfo", "collect_transitive_sv", "slang_order_cmd")

VerilatorModelInfo = provider(fields = {
    "lib": provider_field(typing.Any),
    "include_dir": provider_field(typing.Any),
    "top_module": provider_field(typing.Any),
    "trace": provider_field(typing.Any),
})

def _verilator_model_impl(ctx: AnalysisContext) -> list[Provider]:
    lib = ctx.actions.declare_output("Vtop__ALL.a")
    include_dir = ctx.actions.declare_output("include", dir = True)

    sources, blackboxes, include_dirs = collect_transitive_sv(ctx, ctx.attrs.deps)

    slang_cmd = slang_order_cmd(sources, include_dirs, ctx.attrs.top_module, "$MDIR/sv_order.txt")

    vargs = ["verilator", "-cc", "--vpi", "--public-flat-rw", "--prefix", "Vtop", "--build"]
    vargs.extend(["--top-module", ctx.attrs.top_module])
    vargs.extend(["--timescale", "1ns/1ps"])

    if ctx.attrs.trace:
        vargs.extend(["--trace", "--trace-fst", "--trace-structs"])

    vargs.extend(ctx.attrs.compile_args)

    for key, value in ctx.attrs.parameters.items():
        vargs.append("-G{}={}".format(key, value))

    for d in include_dirs:
        vargs.append(cmd_args("+incdir+", d, delimiter = ""))

    vargs.extend(["-Mdir", "$MDIR", "-f", "$MDIR/sv_order.txt"])

    for bb in blackboxes:
        vargs.append(bb)

    script_content = cmd_args(
        "#!/bin/bash",
        "set -e",
        "MDIR=$(mktemp -d)",
        "trap 'rm -rf \"$MDIR\"' EXIT",
        cmd_args(slang_cmd, delimiter = " "),
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
        cmd_args(
            ["bash", build_script],
            hidden = sources + blackboxes + include_dirs + [lib.as_output(), include_dir.as_output()],
        ),
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
