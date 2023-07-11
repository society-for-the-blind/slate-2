# Apr 9, 2023, 9:59 PM EDT
{ nixpkgs_commit ? "ea96b4af6148114421fda90df33cf236ff5ecf1d"
,  nix_shell_dir ? "" # --argstr
,      timestamp ? "" # --argstr
,           port ? "80"
}:

# HOW TO CALL? {{- {{-
# ====================================================
# The  most  common way  will  probably  be from  this
# repo  after  the  main  shell.nix  already  exported
# `NIX_SHELL_DIR` so:
#
#     # TODO See issue #23
#     just gunicorn_local 8000 &
#     nix-shell --argstr "nix_shell_dir" "${NIX_SHELL_DIR}" --argstr "timestamp" "$(date '+%Y-%m-%d_%H-%M-%S')" \
#       --argstr "port" "8001" nginx_shell.nix
#
#     # or, when serving from a privileged port (e.g., 80):
#     # TODO See issue #24
#     # NOTE Is it ok to run NGINX as root?
#     #      Yes: https://unix.stackexchange.com/questions/134301/
#     sudo $(which nix-shell) --argstr "nix_shell_dir" "${NIX_SHELL_DIR}" --argstr "timestamp" "$(date '+%Y-%m-%d_%H-%M-%S')" --argstr "port" "80" nginx_shell.nix
# }}- }}-

# TODO look into `nginx` package in Nixpkgs
# NOTE ERRORS ON FIRST RUN {{- {{-
#      ===================
# There will probably be a lot of errors along the lines of:
#
#     2023/05/05 15:55:03 [emerg] 3106282#3106282: mkdir() "/var/cache/nginx/proxy" failed (13: Permission denied)
#
# This is because (as far as I was able to figure it out) the NGINX Nix package has been compiled with these hard paths that HAVE TO exist, even though they won't be touched (and some of them could be over-ridden; e.g., error.log - see below).`
#
# These have done the trick thus far:
#
#     sudo mkdir -p /var/log/nginx/
#     sudo touch /var/log/nginx/error.log
#     sudo mkdir -p /var/cache/nginx/proxy
#     sudo mkdir -p /var/cache/nginx/uwsgi
#     sudo mkdir -p /var/cache/nginx/scgi
#     sudo mkdir -p /var/cache/nginx/fastcgi
#     sudo mkdir -p /var/cache/nginx/client_body
#
#     # https://serverfault.com/questions/235154
#     # (The user should be whoever starts NGINX.)
#     sudo chown -R $(whoami):$(whoami) /var/{log,cache}/nginx
#
# As a one-liner:
#
#     sudo mkdir -p /var/log/nginx/ && sudo touch /var/log/nginx/error.log && sudo mkdir -p /var/cache/nginx/proxy && sudo mkdir -p /var/cache/nginx/uwsgi && sudo mkdir -p /var/cache/nginx/scgi && sudo mkdir -p /var/cache/nginx/fastcgi && sudo mkdir -p /var/cache/nginx/client_body & sudo chown -R $(whoami):$(whoami) /var/{log,cache}/nginx
# }}- }}-

# OUTDATED? (2023-07-08) {{- {{-
# NOTE https://discourse.nixos.org/t/how-to-add-local-files-into-nginx-derivation-for-nix-shell/6603
# Opted to keep `nginx.conf` out of the store, because
# 1. it is already in version control
# 2. if changes need to be made, one would have to create another config to override it
# -- Although, are there merits to keep it in the store?
#    + with NixOS, this would be a no brainer, but then the config would have to be rebuilt
#    + if a default config is kept in the store, it could still be over-ridden with another one using `-c`
#    Nonetheless, when this repo is deployed via a `shell.nix`, it may be more convenient to refer to a non-store config.
#
# let
#   nginx-with-config = pkgs.writeScriptBin "nginx-alt" ''
#     exec ${pkgs.nginx}/bin/nginx -c ${./nginx.conf} "$@"
#   '';
#
# in
# }}- }}-

let

  nixpkgs_url = "https://github.com/nixos/nixpkgs/tarball/${nixpkgs_commit}";
  pkgs =
    import
      # The downloaded archive will be (temporarily?) housed in the Nix store
      # e.g., "/nix/store/gk9x7syd0ic6hjrf0fs6y4bsd16zgscg-source"
      # (Try any of the `fetchTarball` commands  below  in `nix repl`, and it
      #  will print out the path.)
      ( builtins.fetchTarball nixpkgs_url) { config = {}; overlays = []; }
  ;

  # Realized in `shellHook`
  nginx_dir = nix_shell_dir + "/nginx";

  # NGINX doc's most valuable pages:
  # + [Alphabetical index of directives](http://nginx.org/en/docs/dirindex.html)
  # + [Alphabetical index of variables](http://nginx.org/en/docs/varindex.html)

  nginx_conf = # {{-
    pkgs.writeTextFile {

      name = "nginx.conf";

      text =
        # NOTE no `user` directive {{- {{-
        # The default for `user` is
        #
        #     user nobody nobody;
        #
        # but can't  simply put it  here as it will  fail. For
        # one,  there  is no  "nobody"  group,  and this  also
        # doesn't seem  to work  simply as `user  nobody;`, so
        # leaving it off, and relying on the default.

        # UPDATE: The "Deploying Gunicorn" guide in the Gunicorn docs
        #         (https://docs.gunicorn.org/en/latest/deploy.html)
        #         recommends
        #
        #     user nobody nogroup;
        #
        #         but don't know if this is Ubuntu-specific thing or
        #         not,  and, thus far,  this whole `shell.nix`-based
        #         setup seems to be  distro-agnostic  so will try to
        #         keep it that way.

        # }}- }}-
        # WARNING `error_log` here is a must {{- {{-
        #         ==========================
        # This directive can be  over-ridden in lower levels /
        # contexts (e.g., see in `http`).
        #
        # An  `error_log`  directive  **must** stand  here  in
        # either   case,  otherwise   NGINX  will   check  for
        # `/var/log/nginx/error.log`, as  this value  has been
        # compiled into it. From the
        # [docs](http://nginx.org/en/docs/ngx_core_module.html#error_log):
        #
        # > If  on the  main configuration  level (i.e.,  `main`
        # > context) writing a  log to a file  is not explicitly
        # > defined, the default file will be used.
        #
        #
        # The file in the main `error_log` declaration doesn't
        # have  to  exist  (unlike  `/var/log/nginx/error.log`
        # when  no  main   level  `error_log`  declaration  is
        # present), but if there  is no new default specified,
        # then `nginx` will simply blow up for some reason. Go
        # figure.

        # EDIT: `nginx_main_error.log` and error logs in lower
        # block levels don't  seem to be the  same: The former
        # is for the entire NGINX  runtime, and the others are
        # for the specific block.

        # }}- }}-
        ''
          error_log ${nginx_dir}/nginx_main_error.log debug;
          pid ${nginx_dir}/nginx_${timestamp}.pid;
          worker_processes auto;
        ''

        # COPIED VERBATIM FROM OLD PROD
        # (Also, `nginx` won't run without this block being present.)
      + ''
          events {
              worker_connections 1024; # OLD: 768; DEFAULT: 512
          }
        ''

      # `http` DIRECTIVE {{-
      # (https://nginx.org/en/docs/http/ngx_http_core_module.html)
      + ''
          http {
        ''

        # Logging Settings {{-

              # TODO r?syslog
      + ''
              access_log ${nginx_dir}/access_${timestamp}.log;
              error_log ${nginx_dir}/error_${timestamp}.log debug;
        ''

        # }}-
        # Basic Settings {{-

              # https://stackoverflow.com/questions/58066785/
      + ''
              sendfile on;
        ''

      + ''
              sendfile_max_chunk 2m; # DEFAULT
              tcp_nopush on;
              tcp_nodelay on;        # DEFAULT
              keepalive_timeout 75s; # DEFAULT
        ''
              # https://stackoverflow.com/questions/71880042/
      + ''
              types { # {{-
                  text/html                             html htm shtml;
                  text/css                              css;
                  text/xml                              xml;
                  image/gif                             gif;
                  image/jpeg                            jpeg jpg;
                  application/javascript                js;
                  application/atom+xml                  atom;
                  application/rss+xml                   rss;

                  text/mathml                           mml;
                  text/plain                            txt;
                  text/vnd.sun.j2me.app-descriptor      jad;
                  text/vnd.wap.wml                      wml;
                  text/x-component                      htc;

                  image/png                             png;
                  image/tiff                            tif tiff;
                  image/vnd.wap.wbmp                    wbmp;
                  image/x-icon                          ico;
                  image/x-jng                           jng;
                  image/x-ms-bmp                        bmp;
                  image/svg+xml                         svg svgz;
                  image/webp                            webp;

                  application/font-woff                 woff;
                  application/java-archive              jar war ear;
                  application/json                      json;
                  application/mac-binhex40              hqx;
                  application/msword                    doc;
                  application/pdf                       pdf;
                  application/postscript                ps eps ai;
                  application/rtf                       rtf;
                  application/vnd.apple.mpegurl         m3u8;
                  application/vnd.ms-excel              xls;
                  application/vnd.ms-fontobject         eot;
                  application/vnd.ms-powerpoint         ppt;
                  application/vnd.wap.wmlc              wmlc;
                  application/vnd.google-earth.kml+xml  kml;
                  application/vnd.google-earth.kmz      kmz;
                  application/x-7z-compressed           7z;
                  application/x-cocoa                   cco;
                  application/x-java-archive-diff       jardiff;
                  application/x-java-jnlp-file          jnlp;
                  application/x-makeself                run;
                  application/x-perl                    pl pm;
                  application/x-pilot                   prc pdb;
                  application/x-rar-compressed          rar;
                  application/x-redhat-package-manager  rpm;
                  application/x-sea                     sea;
                  application/x-shockwave-flash         swf;
                  application/x-stuffit                 sit;
                  application/x-tcl                     tcl tk;
                  application/x-x509-ca-cert            der pem crt;
                  application/x-xpinstall               xpi;
                  application/xhtml+xml                 xhtml;
                  application/xspf+xml                  xspf;
                  application/zip                       zip;

                  application/octet-stream              bin exe dll;
                  application/octet-stream              deb;
                  application/octet-stream              dmg;
                  application/octet-stream              iso img;
                  application/octet-stream              msi msp msm;

                  application/vnd.openxmlformats-officedocument.wordprocessingml.document    docx;
                  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet          xlsx;
                  application/vnd.openxmlformats-officedocument.presentationml.presentation  pptx;

                  audio/midi                            mid midi kar;
                  audio/mpeg                            mp3;
                  audio/ogg                             ogg;
                  audio/x-m4a                           m4a;
                  audio/x-realaudio                     ra;

                  video/3gpp                            3gpp 3gp;
                  video/mp2t                            ts;
                  video/mp4                             mp4;
                  video/mpeg                            mpeg mpg;
                  video/quicktime                       mov;
                  video/webm                            webm;
                  video/x-flv                           flv;
                  video/x-m4v                           m4v;
                  video/x-mng                           mng;
                  video/x-ms-asf                        asx asf;
                  video/x-ms-wmv                        wmv;
                  video/x-msvideo                       avi;
              } # }}-
              default_type application/octet-stream; # DEFAULT: text/plain
        ''

              # COPIED VERBATIM FROM OLD PROD
      + ''
              types_hash_max_size 2048; # DEFAULT: 1024
        ''

        # }}-
        #  TODO: put in `server`
        # SSL Settings {{-
        #
        # https://ssl-config.mozilla.org/#server=nginx&version=1.22.1&config=intermediate&openssl=3.0.2&guideline=5.7

              # https://www.ssl.com/guide/disable-tls-1-0-and-1-1-apache-nginx/
      + ''
              ssl_protocols TLSv1.2 TLSv1.3;
        ''

              # https://serverfault.com/a/997685/322755
      + ''
              ssl_prefer_server_ciphers off;
              ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;

        ''

        # }}-
        # Compression Settings {{-
      + ''
          gzip on;
        ''

        # }}-
        # Virtual Host Configs {{-

              # TODO Make server blocks configurable / dev compatible {{- {{-
              #
              # These server configs cannot be used in dev because they require TLS:

              # 1. The 1st `server` block (i.e., the default) shuts down any incoming HTTP request if the Host header value of the HTTP request (i.e., `$host`) is not present, not matched subsequent `server` blocks, etc.
              # 2. The 2nd one redirects to the HTTPS version.
              # 3. The 3rd handles the request.

              # A solution would be simply to enable a server block that matches the the dev server and either port 80 or an unprivileged port, but this will be a systemd unit.

              # Maybe this is not even an issue: the systemd unit(s) will be a file in the repo, and the "prod" flag simply link this (these) to `/etc/systemd/system` (or wherever it is needed), while a "dev" flag could use a conf file generated in the shell.nix.

              # QUESTION / TODO: The systemd unit file(s) distributed with the repo will need to be saved in the Nix store to make nginx work, right?

              # }}- }}-
              # DEFAULT: if no Host match, close the connection to prevent host spoofing {{-
      + ''
              # server {
              #   listen 80 default_server;
              #   return 444;
              # }
        '' # }}-
      + ''
              server {
                  listen ${port};
        ''
        # TODO test this. Based on https://nginx.org/en/docs/http/request_processing.html if the request's Host header does not match any of the `server` blocks, the default one will handle it. Thus, the production settings can be used in a dev environment as well.
      + ''
                  server_name lynx.societyfortheblind.org;

                  location / {
                      # your website configuration goes here
                      # for example:
                      # root ${nix_shell_dir}/..;
                      # index ${nix_shell_dir}/../README.md;

                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;

                      proxy_pass http://localhost:8000;
                  }

                  location /static/ {
                    root ${nix_shell_dir}/django;
                  }
              }
          }
        ''
        # }}-
      # }}-
      ;
    };
  # }}-

  nginx_with_config =
    pkgs.writeShellScriptBin
      "nginx_lynx"
      ''
        exec ${pkgs.nginx}/bin/nginx -c ${nginx_conf} "$@"
      ''
  ;

in
  pkgs.mkShell {
    buildInputs = [
      # TODO for when a `just` recipe is created for NGINX: it runs as a daemon by default, same as PostgreSQL! Set trap / clean-up step to shut it down when exiting the shell.
      nginx_with_config
    ];


    # NOTE It may  take some  time for NGINX  to shut
    #      down (e.g., after  leaving the Nix shell);
    #      the line below in `ps ax` is a good sign:
    #
    #     2814526 ? S 0:00 nginx: worker process is shutting down
    #

    shellHook =
      ''
        mkdir -p ${nginx_dir}
        nginx_lynx

        trap \
          "nginx_lynx -s quit" \
          EXIT

      ''
    ;
  }

# vim: set foldmethod=marker foldmarker={{-,}}- foldlevelstart=0 tabstop=2 shiftwidth=2 expandtab:
