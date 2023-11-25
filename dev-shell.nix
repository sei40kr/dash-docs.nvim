{ dash-docs-nvim, mkShell, neovim, sqlite, vimPlugins }:

mkShell {
  name = "dash-docs.nvim-dev-shell";

  buildInputs = [ sqlite ];

  packages = [
    (neovim.override {
      configure = {
        customRC = ''
          lua <<EOF
          vim.g.sqlite_clib_path = "${sqlite.out}/lib/libsqlite3.dylib";
          EOF
        '';
        packages.myVimPackage.start = [
          dash-docs-nvim
          vimPlugins.sqlite-lua
        ];
      };
    })
  ];

  shellHook = ''
    export NVIM_LOG_FILE=log
    export VIM=
    export VIMRUNTIME=
    export XDG_CONFIG_HOME=$(mktemp -d)
    export XDG_DATA_HOME=$(mktemp -d)
    export VIMINIT=
  '';
}
