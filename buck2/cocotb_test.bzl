load("//buck2:verilator_sim.bzl", "VerilatorSimInfo")

def _cocotb_test_impl(ctx: AnalysisContext) -> list[Provider]:
    sim_info = ctx.attrs.sim[VerilatorSimInfo]
    vtop = sim_info.executable

    results_xml = ctx.actions.declare_output("results.xml")
    dump_fst = ctx.actions.declare_output("dump.fst")

    # Build PYTHONPATH from python_path entries
    python_path = ":".join(ctx.attrs.python_path)

    # Build env export lines
    env_lines = []

    # Add venv site-packages for embedded Python (cocotb VPI uses dlopen'd libpython)
    if ctx.attrs.venv:
        env_lines.append("export VIRTUAL_ENV={}".format(ctx.attrs.venv))
        env_lines.append("export PYGPI_PYTHON_BIN={}/bin/python3".format(ctx.attrs.venv))
        env_lines.append("VENV_SITE=$({venv}/bin/python3 -c \"import site; print(':'.join(site.getsitepackages()))\")".format(venv = ctx.attrs.venv))

    env_lines.append(cmd_args("export COCOTB_TEST_MODULES=", ctx.attrs.test_module, delimiter = ""))
    env_lines.append(cmd_args("export COCOTB_TOPLEVEL=", sim_info.top_module, delimiter = ""))
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

    # Copy commands - cd back to ROOTDIR first so relative artifact paths work
    cp_results = cmd_args("cp \"$WORKDIR/results.xml\"", results_xml.as_output(), "2>/dev/null || echo '<testsuites/>' >", results_xml.as_output(), delimiter = " ")
    cp_fst = cmd_args("cp \"$WORKDIR/dump.fst\"", dump_fst.as_output(), "2>/dev/null || touch", dump_fst.as_output(), delimiter = " ")

    lines = [
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

    script_content = cmd_args(lines, delimiter = "\n")

    test_script = ctx.actions.write(
        "cocotb_run.sh",
        script_content,
        is_executable = True,
    )

    cmd = cmd_args(
        ["bash", test_script],
        hidden = [vtop, results_xml.as_output(), dump_fst.as_output()],
    )
    ctx.actions.run(cmd, category = "cocotb_test")

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
        "sim": attrs.dep(providers = [VerilatorSimInfo]),
        "test_module": attrs.string(),
        "python_path": attrs.list(attrs.string(), default = []),
        "venv": attrs.string(default = ""),
        "env": attrs.dict(key = attrs.string(), value = attrs.string(), default = {}),
    },
)
