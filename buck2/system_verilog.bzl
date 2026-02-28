SvPackageTSet = transitive_set()
SvModuleTSet = transitive_set()
SvIncludeDirTSet = transitive_set()

SvSourcesInfo = provider(fields = {
    "sources": provider_field(typing.Any),
    "transitive_packages": provider_field(typing.Any),
    "transitive_modules": provider_field(typing.Any),
    "include_dirs": provider_field(typing.Any),
    "transitive_include_dirs": provider_field(typing.Any),
})

def _sv_package_impl(ctx: AnalysisContext) -> list[Provider]:
    source = ctx.attrs.src

    transitive_packages = ctx.actions.tset(
        SvPackageTSet,
        value = [source],
        children = [dep[SvSourcesInfo].transitive_packages for dep in ctx.attrs.deps],
    )

    return [
        DefaultInfo(default_output = ctx.actions.symlinked_dir("srcs", {source.short_path: source})),
        SvSourcesInfo(
            sources = [source],
            transitive_packages = transitive_packages,
            transitive_modules = ctx.actions.tset(SvModuleTSet),
            include_dirs = [],
            transitive_include_dirs = ctx.actions.tset(SvIncludeDirTSet),
        ),
    ]

sv_package = rule(
    impl = _sv_package_impl,
    attrs = {
        "src": attrs.source(),
        "deps": attrs.list(attrs.dep(providers = [SvSourcesInfo]), default = []),
    },
)

def _sv_module_library_impl(ctx: AnalysisContext) -> list[Provider]:
    sources = ctx.attrs.srcs
    include_dirs = ctx.attrs.include_dirs

    transitive_packages = ctx.actions.tset(
        SvPackageTSet,
        children = [dep[SvSourcesInfo].transitive_packages for dep in ctx.attrs.deps],
    )
    transitive_modules = ctx.actions.tset(
        SvModuleTSet,
        value = sources,
        children = [dep[SvSourcesInfo].transitive_modules for dep in ctx.attrs.deps],
    )
    transitive_include_dirs = ctx.actions.tset(
        SvIncludeDirTSet,
        value = include_dirs,
        children = [dep[SvSourcesInfo].transitive_include_dirs for dep in ctx.attrs.deps],
    )

    return [
        DefaultInfo(default_output = ctx.actions.symlinked_dir("srcs", {
            src.short_path: src for src in sources
        })),
        SvSourcesInfo(
            sources = sources,
            transitive_packages = transitive_packages,
            transitive_modules = transitive_modules,
            include_dirs = include_dirs,
            transitive_include_dirs = transitive_include_dirs,
        ),
    ]

sv_module_library = rule(
    impl = _sv_module_library_impl,
    attrs = {
        "srcs": attrs.list(attrs.source()),
        "deps": attrs.list(attrs.dep(providers = [SvSourcesInfo]), default = []),
        "include_dirs": attrs.list(attrs.source(allow_directory = True), default = []),
    },
)
