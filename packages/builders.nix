# Build helpers for the packages here.
{ pkgs, lib }:
{
  # An executable `name` that runs a nu-checked nushell `script` with `runtimeInputs` (plus nushell) on PATH.
  # Other arguments (`meta`, `passthru`) reach `writeShellApplication`.
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
