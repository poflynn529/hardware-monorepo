SvSourcesInfo = provider(fields = {
    "sources": provider_field(typing.Any),
    "transitive_sources": provider_field(typing.Any),
    "include_dirs": provider_field(typing.Any),
    "transitive_include_dirs": provider_field(typing.Any),
})

def _sv_library_impl(ctx: AnalysisContext) -> list[Provider]:
    sources = ctx.attrs.srcs
    include_dirs = ctx.attrs.include_dirs

    transitive_sources = depset(
        direct = sources,
        transitive = [dep[SvSourcesInfo].transitive_sources for dep in ctx.attrs.deps],
        order = "postorder",
    )
    transitive_include_dirs = depset(
        direct = include_dirs,
        transitive = [dep[SvSourcesInfo].transitive_include_dirs for dep in ctx.attrs.deps],
        order = "postorder",
    )

    return [
        DefaultInfo(default_output = ctx.actions.symlinked_dir("srcs", {
            src.short_path: src for src in sources
        })),
        SvSourcesInfo(
            sources = sources,
            transitive_sources = transitive_sources,
            include_dirs = include_dirs,
            transitive_include_dirs = transitive_include_dirs,
        ),
    ]

sv_library = rule(
    impl = _sv_library_impl,
    attrs = {
        "srcs": attrs.list(attrs.source()),
        "deps": attrs.list(attrs.dep(providers = [SvSourcesInfo]), default = []),
        "include_dirs": attrs.list(attrs.source(allow_directory = True), default = []),
    },
)
