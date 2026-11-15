# Build helpers for the packages here.
{ pkgs, lib }:
{
  # Like writeShellApplication, whose other arguments it takes, for a nushell `script` nu-checked at build.
  writeNushellApplication =
    {
      name,
      runtimeInputs ? [ ],
      script,
      ...
    }@args:
    let
      checked = pkgs.runCommandLocal "${name}.nu" { } ''
        ${lib.getExe pkgs.nushell} --no-config-file --commands 'if not (nu-check "${script}") { exit 1 }'
        cp ${script} $out
      '';
    in
    pkgs.writeShellApplication (
      removeAttrs args [ "script" ]
      // {
        runtimeInputs = [ pkgs.nushell ] ++ runtimeInputs;
        text = ''exec nu ${checked} "$@"'';
      }
    );
}
