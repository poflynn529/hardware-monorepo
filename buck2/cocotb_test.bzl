load("//buck2:verilator_sim.bzl", "VerilatorModelInfo")

def _cocotb_test_impl(ctx: AnalysisContext) -> list[Provider]:
    model_info = ctx.attrs.model[VerilatorModelInfo]

    vtop = ctx.actions.declare_output("Vtop")
    results_xml = ctx.actions.declare_output("results.xml")
    dump_fst = ctx.actions.declare_output("dump.fst")

    # ── Link action ──────────────────────────────────────────────────────────
    runtime_cpps = [
        "$VERILATOR_ROOT/include/verilated.cpp",
        "$VERILATOR_ROOT/include/verilated_vpi.cpp",
        "$VERILATOR_ROOT/include/verilated_threads.cpp",
    ]
    if model_info.trace:
        runtime_cpps.append("$VERILATOR_ROOT/include/verilated_fst_c.cpp")

    link_args = [
        "g++", "-std=c++17", "-O2", "-o", vtop.as_output(),
        cmd_args("-I", model_info.include_dir, delimiter = ""),
        "-I$VERILATOR_ROOT/include",
        "-I$VERILATOR_ROOT/include/vltstd",
        ctx.attrs.verilator_cpp,
    ] + runtime_cpps + [
        model_info.lib,
        "-Wl,-rpath,{l} -L{l} -lcocotbvpi_verilator".format(l = ctx.attrs.cocotb_lib_dir),
        "-lz",
    ]

    link_script = ctx.actions.write(
        "verilator_link.sh",
        cmd_args(
            "#!/bin/bash",
            "set -e",
            "VERILATOR_ROOT=$(verilator --getenv VERILATOR_ROOT)",
            cmd_args(link_args, delimiter = " "),
            delimiter = "\n",
        ),
        is_executable = True,
    )

    ctx.actions.run(
        cmd_args(["bash", link_script], hidden = [model_info.lib, model_info.include_dir, vtop.as_output()]),
        category = "verilator_link",
    )

    # ── Test-run action ───────────────────────────────────────────────────────
    python_path = ":".join(ctx.attrs.python_path)

    env_lines = []

    if ctx.attrs.venv:
        env_lines.append("export VIRTUAL_ENV={}".format(ctx.attrs.venv))
        env_lines.append("export PYGPI_PYTHON_BIN={}/bin/python3".format(ctx.attrs.venv))
        env_lines.append("VENV_SITE=$({venv}/bin/python3 -c \"import site; print(':'.join(site.getsitepackages()))\")".format(venv = ctx.attrs.venv))

    env_lines.append(cmd_args("export COCOTB_TEST_MODULES=", ctx.attrs.test_module, delimiter = ""))
    env_lines.append(cmd_args("export COCOTB_TOPLEVEL=", model_info.top_module, delimiter = ""))
    env_lines.append("export TOPLEVEL_LANG=verilog")
    pythonpath_parts = []
    if python_path:
        pythonpath_parts.append(python_path)
    if ctx.attrs.venv:
        pythonpath_parts.append("$VENV_SITE")
    pythonpath_parts.append("$PYTHONPATH")
    env_lines.append("export PYTHONPATH=\"{}\"".format(":".join(pythonpath_parts)))

    for key, value in ctx.attrs.env.items():
        env_lines.append("export {}=\"{}\"".format(key, value))

    cp_results = cmd_args("cp \"$WORKDIR/results.xml\"", results_xml.as_output(), "2>/dev/null || echo '<testsuites/>' >", results_xml.as_output(), delimiter = " ")
    cp_fst = cmd_args("cp \"$WORKDIR/dump.fst\"", dump_fst.as_output(), "2>/dev/null || touch", dump_fst.as_output(), delimiter = " ")

    test_lines = [
        "#!/bin/bash",
        "set +e",
        "ROOTDIR=$(pwd)",
        "WORKDIR=$(mktemp -d)",
        "trap 'rm -rf \"$WORKDIR\"' EXIT",
        cmd_args("cp", vtop, "\"$WORKDIR/Vtop\"", delimiter = " "),
        "chmod +x \"$WORKDIR/Vtop\"",
        "cd \"$WORKDIR\"",
    ] + env_lines + [
        "\"$WORKDIR/Vtop\" 2>&1",
        "TEST_RC=$?",
        "cd \"$ROOTDIR\"",
        cp_results,
        cp_fst,
        "if [ -f \"$WORKDIR/results.xml\" ] && ! grep -q '<failure' \"$WORKDIR/results.xml\" 2>/dev/null && ! grep -q '<error' \"$WORKDIR/results.xml\" 2>/dev/null; then",
        "  exit 0",
        "else",
        "  echo 'Tests failed (rc=$TEST_RC) - check results.xml'",
        "  cat \"$WORKDIR/results.xml\" 2>/dev/null || true",
        "  exit 1",
        "fi",
    ]

    test_script = ctx.actions.write(
        "cocotb_run.sh",
        cmd_args(test_lines, delimiter = "\n"),
        is_executable = True,
    )

    ctx.actions.run(
        cmd_args(["bash", test_script], hidden = [vtop, results_xml.as_output(), dump_fst.as_output()]),
        category = "cocotb_test",
    )

    return [
        DefaultInfo(
            default_output = results_xml,
            sub_targets = {
                "waveform": [DefaultInfo(default_output = dump_fst)],
            },
        ),
    ]

cocotb_test = rule(
    impl = _cocotb_test_impl,
    attrs = {
        "model": attrs.dep(providers = [VerilatorModelInfo]),
        "test_module": attrs.string(),
        "cocotb_lib_dir": attrs.string(),
        "verilator_cpp": attrs.string(),
        "python_path": attrs.list(attrs.string(), default = []),
        "venv": attrs.string(default = ""),
        "env": attrs.dict(key = attrs.string(), value = attrs.string(), default = {}),
    },
)
