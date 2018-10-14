"""
MIT License

Copyright (c) 2018 Brian Cairl

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

_CMAKE_THIS_NEW_HTTP_ARCHIVE_BUILD = """
cc_library(
    name = "{name}",
    hdrs = glob([
        "{include_dir}/include/**/**/*"
    ]),
    srcs = glob([
        "lib/*"
    ]),
    strip_include_prefix = "{strip_include_prefix}",
    include_prefix = "{include_prefix}",
    copts = [{copts_concat}],
    deps = [{deps_concat}],
    visibility = [
        "//visibility:public"
    ],
)
"""


def _cmake_this_new_http_archive_impl(ctx):
    # Current directory
    cwd = ctx.path('.')

    # Path to place cmake build artifacts
    build_path = "%s/%s" % (cwd, ctx.attr.downloaded_file_path)

    # Download + extract archive
    ctx.download_and_extract(
        url=ctx.attr.url,
        sha256=ctx.attr.sha256, 
        stripPrefix=ctx.attr.strip_prefix,
        output=ctx.attr.downloaded_file_path,
        type='', # auto detect compression type
    )

    # Run cmake build configuration
    ctx.execute(
        [
            "cmake", build_path,
            "-DCMAKE_BUILD_TYPE=Release",
            "-DBUILD_SHARED_LIBS:bool=ON",
        ],
        timeout=600,
        quiet=False
    )

    # Build
    ctx.execute(
        [
            "make",
        ],
        timeout=600,
        quiet=False
    )

    deps_concat = ""
    for d in ctx.attr.deps :
        deps_concat += ", '%s'" % (d)

    copts_concat = ""
    for d in ctx.attr.copts :
        copts_concat += ", '%s'" % (d)

    full_strip_include_prefix = "%s/%s" % (ctx.attr.downloaded_file_path,
                                           ctx.attr.strip_include_prefix)

    # Create bazel build contents
    build_file_content = _CMAKE_THIS_NEW_HTTP_ARCHIVE_BUILD.format(
        name=ctx.attr.name,
        include_dir=ctx.attr.downloaded_file_path,
        strip_include_prefix=full_strip_include_prefix,
        include_prefix=ctx.attr.include_prefix,
        copts_concat=copts_concat,
        deps_concat=deps_concat
    )

    # Create build file
    bash_exe = ctx.os.environ["BAZEL_SH"] if "BAZEL_SH" in ctx.os.environ else "bash"
    ctx.execute([bash_exe, "-c", "rm -f BUILD.bazel"])
    ctx.file("BUILD.bazel", build_file_content)


cmake_this_new_http_archive = repository_rule(
    implementation=_cmake_this_new_http_archive_impl,
    local=True,
    attrs={
        "url": attr.string(mandatory=True),
        "cmake_path": attr.string(mandatory=True),
        "sha256": attr.string(mandatory=True),
        "strip_prefix": attr.string(mandatory=True),
        "deps": attr.string_list(default=[]),
        "copts": attr.string_list(default=[]),
        "include_prefix": attr.string(default = ""),
        "strip_include_prefix": attr.string(default = ""),
        "downloaded_file_path": attr.string(default = "downloaded"),
    }
)
"""
Downloads a Bazel repository as a compressed archive file, decompresses it,
builds under CMake, and makes its targets available for binding.

It supports the following file extensions: `"zip"`, `"jar"`, `"war"`, `"tar"`,
`"tar.gz"`, `"tgz"`, `"tar.xz"`, and `tar.bz2`.
"""
