package Noembed::Source::GitHub;

use parent 'Noembed::Source';

sub prepare_source {
  my $self = shift;
  $self->{re} = qr{https?://gist\.github\.com/[0-9a-fA-f]+$}i;
}

sub matches {
  my ($self, $url) = @_;
  return $url =~ $self->{re};
}

sub request_url {
  my ($self, $url, $params) = @_;
  return "$url.pibb";
}

sub provider_name { "GitHub" }

1;
