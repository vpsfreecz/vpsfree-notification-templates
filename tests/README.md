# Daily-report HTML regression checks

The daily policy summary contains current matches, recorded activity and
outstanding actions supplied by vpsAdmin. The template omits these sections when
an older producer does not supply the summary. HTML rendering formats the supplied
facts without querying the database or evaluating policies.

Run the focused examples with the vpsAdmin source under test and the Ruby, RSpec and
ActiveSupport dependencies from its declared environment:

```sh
VPSADMIN_RENDER_SOURCE=/path/to/checked/vpsadmin \
  ruby -rrspec/core -e 'exit RSpec::Core::Runner.run(ARGV)' -- \
  tests/daily_report_incident_policy_spec.rb
```

The examples load the actual production `TemplateBuilder` and time-zone helper
without loading the application or connecting to a database. Set
`DAILY_REPORT_PREVIEWS` to a directory outside this repository to retain the
synthetic full-template HTML samples.

`fixtures/daily_report_incident_policy.rb` is the shared pure Ruby payload for
these examples and the backend daily-report spec. It contains only synthetic
identifiers and native UTC times. Missing, empty, full, capped, null-link and
hostile-value variants cover optional data, count windows, historical nulls,
shared shutdown actions and mail outcomes. Update the producer spec alongside
fixture changes so both formats use the same facts.

The repository's ordinary vpsAdmin template checker remains the authority for
template metadata and ERB syntax. These focused render examples supplement it;
they do not send mail or verify delivery, configured recipients or a deployment.
