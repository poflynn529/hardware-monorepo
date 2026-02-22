SvSourcesInfo = provider(fields = {
    "sources": provider_field(typing.Any),
    "transitive_sources": provider_field(typing.Any),
    "include_dirs": provider_field(typing.Any),
    "transitive_include_dirs": provider_field(typing.Any),
})

def _sv_library_impl(ctx: AnalysisContext) -> list[Provider]:
    sources = ctx.attrs.srcs
    include_dirs = ctx.attrs.include_dirs

    # Deps first so packages are declared before files that import them
    transitive_sources = []
    transitive_include_dirs = []

    for dep in ctx.attrs.deps:
        dep_info = dep[SvSourcesInfo]
        transitive_sources.extend(dep_info.transitive_sources)
        transitive_include_dirs.extend(dep_info.transitive_include_dirs)

    transitive_sources.extend(sources)
    transitive_include_dirs.extend(include_dirs)

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
