# Repository Guidelines

## Project Structure

Templates for vpsAdmin live under `templates/` in snake_case directories, such
as `templates/user_create/` or `templates/vps_network_enabled/`.

Each directory contains `meta.rb` for the template type, label, visibility, and
sender addresses. Email variants live in `email/` and use names such as
`en.subject.erb`, `cs.text.erb`, or `en.html.erb`. There is no repository-local
Ruby library or checker.

## Build and Test Commands

- `nix flake check`: validate the templates and build the default package.
- `nix run .#check`: validate the working tree with vpsAdmin's checker.
- `nix develop`: enter a shell that provides `notification-template-check`.
- `nix build .#`: build the package with templates under `templates/`.

## Coding Style and Naming

Follow `.editorconfig`: UTF-8, LF line endings, trimmed whitespace, and 2-space
indentation for Ruby and ERB files. Name new template directories in
snake_case, such as `dataset_migration_finished`.

Keep `meta.rb` consistent with the existing `template` and `lang` blocks. Put
localized subjects and bodies in `email/`. Use `<%= ... %>` interpolation and
readable text wrapping. Update the relevant language variants together.

Use `[vpsFree.cz] ` before a user-facing email subject only when it has no
other identifying prefix. Keep an existing prefix such as
`[vpsAdmin Request #…]` instead of adding `[vpsFree.cz] `. For replies,
place `Re: ` before whichever prefix the subject uses. Apply the rule to every
language variant, including subjects with ERB expressions. Emails sent only to
admins do not need the prefix.

## Language and Communication Style

User-facing emails are factual, calm, and action-oriented. English starts with
`Hi <login>,` and closes with `Best regards,` then `vpsFree.cz team`. Czech
starts with `Ahoj <login>,`, uses informal singular address, and closes with
`S pozdravem`, then `tým vpsFree.cz`.

State the event or problem first, then give details, action links, and KB
references. Use `please` or `prosím` for requests, avoid marketing language, and
keep the standard automated-mail notice uniform in member-facing templates.
When the notice is present, use these exact visible lines in plain and HTML
variants; do not paraphrase either language in an individual template:

- English: `(This is an automated mail from vpsAdmin, your reply will be sent to our support)`
- Czech: `(Tento mail automaticky rozesílá vpsAdmin, Tvoje odpověď se zašle na naši podporu)`

Admin templates can be terse, using tables, lists, and direct action links.

## Commit and Pull Request Guidelines

Use short imperative subjects, often scoped by template name, for example
`vps_incident_report: add VPS action information`. Keep unrelated template
changes separate. Limit every commit message line to 80 characters or fewer.
Write multi-line messages to a temporary file and commit with `git commit -F`.

Pull requests should name affected directories, explain user-visible changes,
and note the flake checks. Include rendered previews for HTML changes.

## Security

Do not commit credentials or rendered emails containing personal data.
