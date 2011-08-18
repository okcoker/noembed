package Noembed::Source;

use Encode;
use JSON;
use AnyEvent::HTTP;

sub new {
  my ($class, %args) = @_;

  my $self = bless {%args}, $class;
  die "render is required" unless defined $self->{render};

  $self->prepare_source if $self->can('prepare_source');

  return $self;
}

sub render {
  my $self = shift;
  $self->{render}->($self->filename("html"), @_);
}

sub style {
  my $self = shift;
  
  # cache it
  $self->{style} ||= do {
    my $file = Noembed::style_dir() . "/" . $self->filename("css");
    if (-e $file) {
      open my $fh, "<", $file;
      local $/;
      <$fh>;
    }
  };
}

sub filename {
  my ($self, $ext) = @_;
  my ($name) = ref($self) =~ /:([^:]+)$/;
  return "$name.$ext";
}

sub request_url {
  my ($self, $url, $params) = @_;
  return $url;
}

sub filter {
  my $self = shift;
  return @_;
}

sub matches {
  die "must override matches method";
}

sub download {
  my ($self, $req, $cb) = @_;

  my $params = $req->parameters;
  my $url = $params->{url};

  my $service = $self->request_url($url, $params);
  my $nb = $req->env->{'psgi.nonblocking'};
  my $cv = AE::cv;

  http_request "get", $service, {
      persistent => 0,
      keepalive  => 0,
    },
    sub {
      my ($body, $headers) = @_;

      $body = decode("utf8", $body);

      if ($headers->{Status} == 200) {
        eval {
          my $data = $self->filter($body, $url);
          $data->{html} .= '<style type="text/css">'.$self->style.'</style>';
          $data->{type} = "rich";
          $data->{url} = $url;
          $data->{title} ||= $url;
          $data->{provider_name} ||= $self->provider_name;
          $cb->( encode_json($data), "" );
        };
        warn "Error after http request: $@" if $@;
      }
      else {
        $cb->("", $headers->{Reason});
      }

      $cv->send unless $nb;
    };

  $cv->recv unless $nb;
}

# default just keeps the downloaded content.
# should be overridden.
sub filter {
  my ($self, $body) = @_;
  return +{
    html => $body
  };
}

1;
