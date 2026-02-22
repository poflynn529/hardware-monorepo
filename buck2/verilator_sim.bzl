load("//buck2:sv_library.bzl", "SvSourcesInfo")

VerilatorSimInfo = provider(fields = {
    "executable": provider_field(typing.Any),
    "top_module": provider_field(typing.Any),
})

def _verilator_sim_impl(ctx: AnalysisContext) -> list[Provider]:
    vtop = ctx.actions.declare_output("Vtop")

    sources = []
    include_dirs = []
    for dep in ctx.attrs.deps:
        info = dep[SvSourcesInfo]
        sources.extend(info.transitive_sources)
        include_dirs.extend(info.transitive_include_dirs)

    # Deduplicate while preserving order
    seen_sources = {}
    unique_sources = []
    for src in sources:
        key = src.short_path
        if key not in seen_sources:
            seen_sources[key] = True
            unique_sources.append(src)

    seen_dirs = {}
    unique_dirs = []
    for d in include_dirs:
        key = str(d)
        if key not in seen_dirs:
            seen_dirs[key] = True
            unique_dirs.append(d)

    # Build verilator args list for space-delimited joining
    vargs = ["verilator", "-cc", "--exe", "--vpi", "--public-flat-rw", "--prefix", "Vtop"]
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
    vargs.extend([
        "-LDFLAGS",
        "\"-Wl,-rpath,{lib} -L{lib} -lcocotbvpi_verilator\"".format(lib = ctx.attrs.cocotb_lib_dir),
    ])

    for src in unique_sources:
        vargs.append(src)

    vargs.append(ctx.attrs.verilator_cpp)

    # Build script lines - verilator cmd as single space-delimited line
    verilator_line = cmd_args(vargs, delimiter = " ")
    make_line = "make -C \"$MDIR\" -f Vtop.mk -j$(nproc)"
    cp_line = cmd_args("cp \"$MDIR/Vtop\"", vtop.as_output(), delimiter = " ")

    script_content = cmd_args(
        "#!/bin/bash",
        "set -e",
        "MDIR=$(mktemp -d)",
        "trap 'rm -rf \"$MDIR\"' EXIT",
        verilator_line,
        make_line,
        cp_line,
        delimiter = "\n",
    )

    build_script = ctx.actions.write(
        "verilator_build.sh",
        script_content,
        is_executable = True,
    )

    cmd = cmd_args(["bash", build_script], hidden = unique_sources + [vtop.as_output()])
    ctx.actions.run(cmd, category = "verilator")

    return [
        DefaultInfo(default_output = vtop),
        RunInfo(args = cmd_args(vtop)),
        VerilatorSimInfo(
            executable = vtop,
            top_module = ctx.attrs.top_module,
        ),
    ]

verilator_sim = rule(
    impl = _verilator_sim_impl,
    attrs = {
        "top_module": attrs.string(),
        "deps": attrs.list(attrs.dep(providers = [SvSourcesInfo])),
        "parameters": attrs.dict(key = attrs.string(), value = attrs.string(), default = {}),
        "compile_args": attrs.list(attrs.string(), default = []),
        "trace": attrs.bool(default = True),
        "cocotb_lib_dir": attrs.string(),
        "verilator_cpp": attrs.string(),
    },
)
