return {
  cmd = { 'nil' },
  filetypes = { 'nix' },
  root_markers = {
    'flake.nix',
    'flake.lock',
    'shell.nix',
    'default.nix',
    '.git',
  },
  settings = {
    ['nil'] = {
      formatting = {
        command = { 'nixpkgs-fmt' },
      },
    },
  },
}
