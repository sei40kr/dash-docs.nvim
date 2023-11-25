{ vimUtils }:

vimUtils.buildVimPlugin {
  pname = "dash-docs.nvim";
  version = "0.0.1";

  src = ./.;

  meta.homepage = "https://github.com/sei40kr/dash-docs.nvim";
}
