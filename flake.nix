{
  description = "Rust project";

  inputs = {
    rs-harbor.url = "git+ssh://git@github.com/caniko/rs-harbor.git?ref=trunk&rev=05cc4f162b55fa904b687db1821e2463fa813e50";
    nixpkgs.follows = "rs-harbor/nixpkgs";
    rust-overlay.follows = "rs-harbor/rust-overlay";
    crane.follows = "rs-harbor/crane";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = {
    self,
    rs-harbor,
    nixpkgs,
    rust-overlay,
    crane,
    flake-utils,
    treefmt-nix,
    git-hooks,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [(import rust-overlay)];
      };

      toolchain = rs-harbor.lib.mkToolchain {inherit pkgs; toolchainProfile = "stable";};
      inherit (toolchain) craneLib rustToolchain;
      buildCache = rs-harbor.lib.mkBuildCachePolicy {
        inherit pkgs;
        buildPackageSet = pkgs.buildPackages;
        sccachePackage = rs-harbor.packages.${system}.sccache;
        cacheRoot = null;
        namespaceScope = "canix-rust";
        namespaceGeneration = 5;
      };
      src = craneLib.cleanCargoSource ./.;
      commonArgs = {
        inherit src;
        strictDeps = true;
      };
      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      package = buildCache.withRustCache {
        package = craneLib.buildPackage (commonArgs // {inherit cargoArtifacts;});
      };
      treefmtEval = treefmt-nix.lib.evalModule pkgs (import ./nix/treefmt.nix);
      pre-commit-check = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = import ./nix/pre-commit.nix {
          inherit pkgs;
          treefmtWrapper = treefmtEval.config.build.wrapper;
          inherit rustToolchain;
        };
      };
    in {
      packages.default = package;
      formatter = treefmtEval.config.build.wrapper;
      checks = {
        default = package;
        formatting = treefmtEval.config.build.check self;
        clippy = craneLib.cargoClippy (commonArgs
          // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets --all-features -- --deny warnings";
          });
        fmt = craneLib.cargoFmt {inherit src;};
      };
      devShells.default = craneLib.devShell {
        checks = self.checks.${system};
        packages = with pkgs; [
          maturin
          cargo-about
          cargo-audit
          cargo-cyclonedx
          cargo-deny
          cargo-llvm-cov
          cargo-sbom
          cargo-nextest
          cosign
          file
          gnutar
          gzip
          jq
          minisign
          nodejs
          pre-commit
          rpm
          util-linux
          unzip
          zip
          reprepro
          rust-analyzer
          taplo
        ] ++ pre-commit-check.enabledPackages;
        shellHook = pre-commit-check.shellHook;
      };
      apps.local-check-fast = {
        type = "app";
        program = let
          script = pkgs.writeShellApplication {
            name = "local-check-fast";
            runtimeInputs = with pkgs; [
              cargo-deny
              git
              jq
              rustToolchain
            ];
            text = ''
              set -euo pipefail
              cargo test --workspace --all-features
              cargo clippy --workspace --all-targets --all-features -- --deny warnings
              cargo deny check bans licenses sources
              cargo package --workspace --allow-dirty --list >/dev/null
            '';
          };
        in "${script}/bin/local-check-fast";
        meta.description = "Run fast local validation checks";
      };
      apps.local-check-release = {
        type = "app";
        program = let
          script = pkgs.writeShellApplication {
            name = "local-check-release";
            runtimeInputs = with pkgs; [
              cargo-about
              cargo-cyclonedx
              cargo-deny
              cargo-sbom
              cosign
              jq
              minisign
              rustToolchain
            ];
            text = ''
              set -euo pipefail
              version="''${1:-}"
              if [ -z "$version" ]; then
                echo "usage: local-check-release <version>" >&2
                exit 2
              fi
              repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              cd "$repo"
              ${self.apps.${system}.local-check-fast.program}
              manifest="release/artifacts.json"
              mkdir -p release
              jq -n --arg version "$version" \
                '{version: $version, artifacts: [], skipped: [], generated_by: "simit local-check-release"}' \
                > "$manifest.tmp"
              mv "$manifest.tmp" "$manifest"
              manifest_add_file() {
                path="$1"
                producer="$2"
                [ -f "$path" ] || return 0
                sha256="$(sha256sum "$path" | awk '{print $1}')"
                jq --arg path "$path" --arg sha256 "$sha256" --arg producer "$producer" \
                  '.artifacts += [{path: $path, sha256: $sha256, producer: $producer}]' \
                  "$manifest" > "$manifest.tmp"
                mv "$manifest.tmp" "$manifest"
              }
              manifest_skip() {
                name="$1"
                reason="$2"
                jq --arg name "$name" --arg reason "$reason" \
                  '.skipped += [{name: $name, reason: $reason}]' \
                  "$manifest" > "$manifest.tmp"
                mv "$manifest.tmp" "$manifest"
              }
              if [ -f about-template.hbs ]; then
                cargo about generate --output-file release/THIRD_PARTY_LICENSES.html about-template.hbs
                manifest_add_file release/THIRD_PARTY_LICENSES.html cargo-about
              else
                echo "warning: about-template.hbs not found; skipping cargo-about report" >&2
                manifest_skip cargo-about "about-template.hbs not found"
              fi
              cargo sbom --output-format cyclone_dx_json_1_5 > "release/''${version}.cdx.json"
              cargo sbom --output-format spdx_json_2_3 > "release/''${version}.spdx.json"
              manifest_add_file "release/''${version}.cdx.json" cargo-sbom-cyclonedx
              manifest_add_file "release/''${version}.spdx.json" cargo-sbom-spdx
              if [ -n "''${COSIGN_PRIVATE_KEY:-}" ]; then
                echo "COSIGN_PRIVATE_KEY present; local release parity will not sign or upload" >&2
              else
                echo "warning: keyless Sigstore and COSIGN_PRIVATE_KEY unavailable locally; skipping local cosign signing" >&2
                manifest_skip cosign "keyless Sigstore and COSIGN_PRIVATE_KEY unavailable locally"
              fi
              if [ -x scripts/release-local-check.sh ]; then
                bash scripts/release-local-check.sh "$version"
              fi
              echo "local release parity dry-run passed for ''${version}; no external publish was attempted"
            '';
          };
        in "${script}/bin/local-check-release";
        meta.description = "Run local release parity checks without publishing";
      };
      apps.local-release-deploy = {
        type = "app";
        program = let
          script = pkgs.writeShellApplication {
            name = "local-release-deploy";
            runtimeInputs = with pkgs; [
              git
              jq
            ];
            text = ''
              set -euo pipefail
              version="''${1:-}"
              publish_flag="''${2:-}"
              publish_version="''${3:-}"
              if [ -z "$version" ] || [ "$publish_flag" != "--publish" ] || [ "$publish_version" != "$version" ]; then
                echo "usage: local-release-deploy <version> --publish <version>" >&2
                echo "refusing to publish without an explicit matching confirmation" >&2
                exit 2
              fi
              repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              cd "$repo"
              ${self.apps.${system}.local-check-release.program} "$version"
              if ! jq -e --arg version "$version" '.version == $version' release/artifacts.json >/dev/null; then
                echo "release/artifacts.json is missing or does not match version $version" >&2
                exit 1
              fi
              if [ -x scripts/local-release-deploy.sh ]; then
                SIMIT_LOCAL_RELEASE_CHECK_DONE=1 exec bash scripts/local-release-deploy.sh "$version" --publish "$version"
              fi
              echo "local-release-deploy has no project publisher hook at scripts/local-release-deploy.sh" >&2
              echo "Homebrew-capable hooks must build Darwin tarballs and gate tap pushes on HOMEBREW_TAP_TOKEN" >&2
              echo "local-check-release must remain non-publishing: no brew bump, git push, upload, or cargo publish" >&2
              exit 2
            '';
          };
        in "${script}/bin/local-release-deploy";
        meta.description = "Run the guarded local release deployment hook";
      };
    });
}
