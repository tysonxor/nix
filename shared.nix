# Must be OS Agnostic! Shared between Linux and Mac
{ ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "ls -la";
      gs = "git status";
      gb = "git branch";
      gl = "git --no-pager log --pretty=format:'%C(yellow)%h ` ` %C(white)%an ` ` %C(green)%ad ` ` %C(red)%d %C(reset)%s' --date=relative --color";
      grbm = "git fetch; git rebase origin/main";
      grsm = "git fetch; git reset --hard origin/main";
      gc = "git fetch; git checkout";
      gcb = "git checkout -b";
      gd = "git diff";
      lg = "lazygit";
      k = "clear";
      lld = "ls -la | grep ^d";
      sql="psql -h localhost -U postgres -d";
    };
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
