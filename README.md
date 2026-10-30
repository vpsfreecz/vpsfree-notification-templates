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

## Repeated-incident notifications

`vps_memory_pressure_warning` and `vps_memory_pressure_stopped` provide specific
advice for VPS memory-pressure incidents. `vps_incident_warning` and
`vps_incident_stopped` provide generic incident escalation messages. Each pair
has Czech and English subjects and plain-text bodies. A stopped template covers
both first and repeat stops and reports only confirmed success. These supplement
the existing individual incident notifications.

The vpsAdmin rule registry explicitly selects a specific pair when installed,
otherwise the generic pair. A disabled recipient preference or rendering or
sending failure does not select an alternate template. Existing template
language fallback still applies. The backend supplies `incident_type` as a
registered safe key and `incident_type_label` in the actual rendered language.
The generic pair makes no memory, worker-count or membership assumptions.

Incident counts and event timestamps describe the original decision. The
backend refreshes `warning_limit`, `stop_limit` and `stop_enforced` from effective
settings when rendering or retrying mail. Future automatic-stop consequences
appear only when `stop_enforced` is true. Stopped messages describe autostart
being disabled by that stop; a subsequent manual start may have changed it.
Manual-start guidance remains when enforcement has since been disabled.

These templates require matching vpsAdmin registrations and variables. Deploy
matching backend and templates before enabling notifications; older versions do
not send these template names. Existing individual incident and OOM-report
notifications remain separate.
