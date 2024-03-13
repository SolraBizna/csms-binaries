This directory contains a static library build of the C binding to [the Second Music System](https://github.com/SolraBizna/second-music-system) for the Windows and macOS operating systems. You can use these binaries to ease the build process of an SMS-using program on Windows or macOS. This way, you don't have to have a Rust build environment, or handle the unique pains of building embeddable libraries on those platforms, to use Second Music System in your project.

You can either refer to this repository using git submodules, or simply unzip a "source release" of this repository into your own build system, probably never to be touched nor updated again.

# Getting other binaries

For every push we make to our [official `second-music-system` repository][1] (including branches), we automatically build binaries using GitHub Actions. If all those builds succeed, we also push the resulting binaries to a corresponding branch of our [official `csms-binaries` repository][2]. All of this plumbing should remain intact even for forks. Cloning/downloading a particular commit or branch of `csms-binaries` should be all that you need.

[1]: https://github.com/SolraBizna/second-music-system
[2]: https://github.com/SolraBizna/csms-binaries

Given a GitHub Actions run whose binaries you want to ingest, you can manually update this directory using the included `update.lua`. You will need the following prerequisites:

- UNIX-like operating environment (WSL, MinGW/Git Bash, Cygwin, or... actually being on a UNIX-like OS)
- Lua 5.4
- Lua `cjson`, `lfs`, `http`, and `base64` modules (use `luarocks` to install `lua-cjson2`, `luafilesystem`, `http`, `base64` respectively)
- `unzip` and `git` utilities
- A [GitHub Personal Access Token][3] with access to the Second Music System repository you want to ingest (this is unfortunately mandatory even if the SMS repo is public)

[3]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

With the prerequisites in place, use a command line like:

```sh
GITHUB_TOKEN="github_pat_PutYourRealPersonalAccessTokenHere_ThisIsNotARealPersonalAccessTokenButItLooksVaguelyRight" ./update.lua https://github.com/SolraBizna/second-music-system/actions/run/RUN_ID_GOES_HERE
```

This should work even for forked repositories, as long as the GitHub Actions are still working for that fork. It will wipe out all previous artifacts and headers in this directory, and replace them with the ones from that particular GitHub Actions run.

Information about what branch, commit hash, git repository, and GitHub Actions run these binaries came from is found in the `SOURCE_*` files. (Note that GitHub Actions have an expiration date, so the URL in the `SOURCE_RUN` file is likely to be dead after a very short time.)

# Legalese

Second Music System is copyright 2022 and 2023 Solra Bizna and Noah Obert. It is licensed under either of:

 * Apache License, Version 2.0
   ([LICENSE-APACHE](LICENSE-APACHE) or
   <http://www.apache.org/licenses/LICENSE-2.0>)
 * MIT license
   ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the Second Music System crate by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
