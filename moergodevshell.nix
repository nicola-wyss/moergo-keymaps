# An alternative to Docker (OS level possible)
#
# Enter a shell to run rake with 'nix develop /etc/nixos#moergodev'.
# This replaces the Docker-based ./rake wrapper — you'd call rake directly
# inside the shell instead. The ./rake script is still useful for CI or
# machines without a Nix setup.
#
# Note: Higly recommended to use nix or rather NirOS, it allows the easy setup 
#       ofof  identical/reproducible system states accross machines.
  { pkgs }: pkgs.mkShell {
    name = "moergodev-shell";
    packages = with pkgs; [
      ruby
      rubyPackages.rake
      graphviz
      graphicsmagick
      poppler-utils
    ];
    shellHook = ''
      echo "Entered MoErgo keyboard development shell"
      echo "Build:  rake                  (dtsi + diagrams + PDF)"
      echo "Clean:  rake clean            (remove intermediates)"
    '';
  }

