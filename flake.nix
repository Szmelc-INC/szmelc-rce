{
  description = "Szmelc-RCE — self-hostable browser remote-control extension (MV3) + bridge backends (Node/PHP)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      version = "1.1.0";

      meta = with nixpkgs.lib; {
        description = "Szmelc-RCE — self-hostable browser remote-control extension + bridge backends";
        homepage = "https://github.com/Szmelc-INC/szmelc-rce";
        license = licenses.mit;
        platforms = platforms.all;
      };
    in
    {
      # ---------------------------------------------------------------- pkgs --
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in
        rec {
          # The extension itself: load via chrome://extensions → Developer
          # mode → Load unpacked → <out>/share/szmelc-rce/extension
          extension = pkgs.stdenv.mkDerivation {
            pname = "szmelc-rce-extension";
            inherit version;
            src = self;
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/szmelc-rce/extension
              cp -a manifest.json service-worker-loader.js \
                    offscreen.html offscreen.js options.html sidepanel.html \
                    pairing.html blocked.html gif.js gif.worker.js \
                    gif_viewer.html gif_viewer.js managed_schema.json \
                    icon-16.png icon-32.png icon-48.png icon-128.png \
                    agent_icon.svg szmelc-mark.svg \
                    assets i18n sounds public action LICENSE \
                    $out/share/szmelc-rce/extension/
              runHook postInstall
            '';
            inherit meta;
          };

          # Node bridge backend (ws vendored — no npmDepsHash needed).
          backend-node = pkgs.stdenv.mkDerivation {
            pname = "szmelc-rce-backend";
            inherit version;
            src = self;
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/szmelc-rce
              cp -a backend/. $out/lib/szmelc-rce/backend/
              cp -a server.php dev $out/lib/szmelc-rce/
              mkdir -p $out/bin
              cat > $out/bin/szmelc-rce-backend <<'WRAPPER'
              #!/bin/sh
              # Configuration via env: PORT HOST RCE_API_TOKEN RCE_PERMISSIONS
              # RCE_TOOL_TIMEOUT_MS (see backend/README.md)
              exec node /usr/lib/szmelc-rce/backend/server.mjs "$@"
              WRAPPER
              sed -i "s|/usr/lib/szmelc-rce/backend/server.mjs|$out/lib/szmelc-rce/backend/server.mjs|" $out/bin/szmelc-rce-backend
              chmod +x $out/bin/szmelc-rce-backend
              runHook postInstall
            '';
            meta = meta // {
              mainProgram = "szmelc-rce-backend";
            };
          };

          # PHP bridge backend (static resolver + daemon; no PHP extensions).
          backend-php = pkgs.stdenv.mkDerivation {
            pname = "szmelc-rce-backend-php";
            inherit version;
            src = self;
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/szmelc-rce
              cp -a server.php $out/lib/szmelc-rce/server.php
              cp -a native-host $out/lib/szmelc-rce/native-host
              mkdir -p $out/bin
              cat > $out/bin/szmelc-rce-backend <<WRAPPER
              #!/bin/sh
              exec ${pkgs.php}/bin/php $out/lib/szmelc-rce/server.php "\$@"
              WRAPPER
              chmod +x $out/bin/szmelc-rce-backend
              runHook postInstall
            '';
            meta = meta // {
              mainProgram = "szmelc-rce-backend";
            };
          };

          default = extension;
        });

      # ----------------------------------------------------------- devshell --
      devShells = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [ nodejs php python3 zip ];
            shellHook = ''
              echo "szmelc-rce devshell: node $(node --version), php $(php --version | head -1)"
              echo "  npm run check | validate | build | crx | test:*   (see package.json)"
            '';
          };
        });

      # -------------------------------------------------------- NixOS module --
      # services.szmelc-rce-backend.* — runs the bridge backend as a systemd
      # service. Defaults to the Node backend; set `package` to
      # szmelc-rce.packages.<system>.backend-php for the PHP variant.
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.szmelc-rce-backend;
        in
        {
          options.services.szmelc-rce-backend = {
            enable = mkEnableOption "Szmelc-RCE bridge backend (browser remote-control bridge)";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.backend-node;
              defaultText = literalExpression "szmelc-rce.packages.\${system}.backend-node";
              description = "Backend package to run (backend-node or backend-php).";
            };

            port = mkOption {
              type = types.port;
              default = 8080;
              description = "TCP port to listen on.";
            };

            host = mkOption {
              type = types.str;
              default = "0.0.0.0";
              description = "Address to bind.";
            };

            apiToken = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Bearer token required for agent HTTP/WS access. Strongly recommended on public hosts.";
            };

            permissions = mkOption {
              type = types.enum [ "auto" "deny" ];
              default = "deny";
              description = "Answer to the extension's permission_request frames (auto = approve).";
            };

            openFirewall = mkOption {
              type = types.bool;
              default = false;
              description = "Open the configured port in the firewall.";
            };
          };

          config = mkIf cfg.enable {
            systemd.services.szmelc-rce-backend = {
              description = "Szmelc-RCE backend (browser remote-control bridge)";
              documentation = [ "https://github.com/Szmelc-INC/szmelc-rce/blob/main/backend/README.md" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];

              environment = {
                PORT = toString cfg.port;
                HOST = cfg.host;
                RCE_PERMISSIONS = cfg.permissions;
              } // optionalAttrs (cfg.apiToken != null) {
                RCE_API_TOKEN = cfg.apiToken;
              };

              serviceConfig = {
                ExecStart = "${cfg.package}/bin/szmelc-rce-backend";
                Restart = "on-failure";
                DynamicUser = true;
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
              };
            };

            networking.firewall.allowedTCPPorts =
              mkIf cfg.openFirewall [ cfg.port ];
          };
        };
    };
}
