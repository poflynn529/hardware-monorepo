SvSourceTSet = transitive_set()
SvBlackboxTSet = transitive_set()
SvIncludeDirTSet = transitive_set()

SvSourcesInfo = provider(fields = {
    "transitive_sources": provider_field(typing.Any),
    "transitive_blackboxes": provider_field(typing.Any),
    "transitive_include_dirs": provider_field(typing.Any),
})

def _sv_library_impl(ctx: AnalysisContext) -> list[Provider]:
    own_sources = [] if ctx.attrs.blackbox else ctx.attrs.srcs
    own_blackboxes = ctx.attrs.srcs if ctx.attrs.blackbox else []
    include_dirs = ctx.attrs.include_dirs

    transitive_sources = ctx.actions.tset(
        SvSourceTSet,
        value = own_sources,
        children = [dep[SvSourcesInfo].transitive_sources for dep in ctx.attrs.deps],
    )
    transitive_blackboxes = ctx.actions.tset(
        SvBlackboxTSet,
        value = own_blackboxes,
        children = [dep[SvSourcesInfo].transitive_blackboxes for dep in ctx.attrs.deps],
    )
    transitive_include_dirs = ctx.actions.tset(
        SvIncludeDirTSet,
        value = include_dirs,
        children = [dep[SvSourcesInfo].transitive_include_dirs for dep in ctx.attrs.deps],
    )

    return [
        DefaultInfo(default_output = ctx.actions.symlinked_dir("srcs", {
            src.short_path: src for src in ctx.attrs.srcs
        })),
        SvSourcesInfo(
            transitive_sources = transitive_sources,
            transitive_blackboxes = transitive_blackboxes,
            transitive_include_dirs = transitive_include_dirs,
        ),
    ]

sv_library = rule(
    impl = _sv_library_impl,
    attrs = {
        "srcs": attrs.list(attrs.source(), default = []),
        "deps": attrs.list(attrs.dep(providers = [SvSourcesInfo]), default = []),
        "include_dirs": attrs.list(attrs.source(allow_directory = True), default = []),
        "blackbox": attrs.bool(default = False),
    },
)

def _dedup_traverse(tset):
    seen = {}
    result = []
    for val_list in tset.traverse():
        for v in val_list:
            if v.short_path not in seen:
                seen[v.short_path] = True
                result.append(v)
    return result

def collect_transitive_sv(ctx: AnalysisContext, deps) -> (list, list, list):
    agg_srcs = ctx.actions.tset(
        SvSourceTSet,
        children = [d[SvSourcesInfo].transitive_sources for d in deps],
    )
    agg_bb = ctx.actions.tset(
        SvBlackboxTSet,
        children = [d[SvSourcesInfo].transitive_blackboxes for d in deps],
    )
    agg_dirs = ctx.actions.tset(
        SvIncludeDirTSet,
        children = [d[SvSourcesInfo].transitive_include_dirs for d in deps],
    )

    return _dedup_traverse(agg_srcs), _dedup_traverse(agg_bb), _dedup_traverse(agg_dirs)

def slang_order_cmd(sources, include_dirs, top_module, out_path):
    args = cmd_args([
        "slang",
        "--lint-only",
        "--ignore-unknown-modules",
        "--timescale", "1ns/1ps",
        "--Mmodule", out_path,
        "--depfile-sort",
        "--top", top_module,
    ])
    for d in include_dirs:
        args.add(cmd_args("+incdir+", d, delimiter = ""))
    for s in sources:
        args.add(s)
    return args
