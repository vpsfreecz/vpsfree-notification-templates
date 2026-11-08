# vpsFree.cz notification templates for vpsAdmin

This repository contains the notification templates used by vpsFree.cz. The
current templates are for email delivery by vpsAdmin.

## Template structure

Each template has one metadata file and an `email/` directory:

```text
templates/user_create/
├── meta.rb
└── email/
    ├── cs.subject.erb
    ├── cs.text.erb
    ├── en.subject.erb
    └── en.text.erb
```

`meta.rb` selects the vpsAdmin template type and sets properties shared by the
email variants. It can also set sender addresses per language:

```ruby
template do
  label 'User created'

  lang :en do
    from 'support@example.com'
    reply_to 'support@example.com'
    return_path 'bounces@example.com'
  end
end
```

The metadata file uses a small literal DSL. It is not general Ruby: keep values
as strings, symbols, or booleans and use only the documented `template`, `lang`,
and property declarations. Language codes are normalized two-letter codes.

Name the variant files `<language>.subject.erb`, `<language>.text.erb`, and
`<language>.html.erb`. Each language needs a text or HTML body. A subject file
is optional when `meta.rb` provides the subject.

## Checks

Run all flake checks before committing:

```shell
nix flake check
```

To check the working tree without building the package, run:

```shell
nix run .#check
```

The parser and checker come from the pinned vpsAdmin input, so this repository
does not need a separate Ruby toolchain or checker implementation.

Check the DNS monitoring notification branches with synthetic addresses and
identities from the same development shell:

```shell
nix develop -c ruby test/dns_monitoring_templates.rb
```

Pass an output directory to retain the 12 rendered Czech/English examples for
review. The check distinguishes successful readiness from configuration removal
and configuration restoration; it does not send email.

## Use with vpsAdmin

Add this repository as a flake input and pass its package to the vpsAdmin NixOS
module:

```nix
{
  inputs.notificationTemplates = {
    url = "github:vpsfreecz/vpsfree-notification-templates";
    inputs.vpsadmin.follows = "vpsadmin";
  };

  # In a NixOS module with `inputs` and `pkgs` in scope:
  vpsadmin.api.notificationTemplates.source =
    inputs.notificationTemplates.packages.${pkgs.system}.default;
}
```

vpsAdmin overlays these templates on its built-in templates and reconciles the
effective set before starting the API. The template source is a build input;
there is no separate upload or installation command.
