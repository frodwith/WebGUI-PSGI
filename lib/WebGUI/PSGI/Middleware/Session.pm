package WebGUI::PSGI::Middleware::Session;
use base qw(Plack::Middleware);

use WebGUI::Session;
use WebGUI::Session::Url;
use WebGUI::Config;
use Plack::Response;
use Plack::Request;

use warnings;
use strict;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

=head1 NAME

WebGUI::PSGI::Middleware::Session

=head1 DESCRIPTION

Ensure a wgSession variable in the environment hash.  

=head1 SYNOPSIS

    builder {
        enable '+WebGUI::PSGI::Middleware::Session';
        $app;
    }

=head1 ENVIRONMENT

In the incoming environment, if a wgSession variable is found, that is simply
passed through.  Otherwise, both the env hash and the %ENV hash are checked
for WEBGUI_ROOT (default: /data/WebGUI) and WEBGUI_CONFIG (will die if none is
found), and the cookies are used to determine a session id.

=cut

sub call {
    my ($self, $env) = @_;
    my $session;

    unless ($session = $env->{wgSession}) {
        my $root = $env->{WEBGUI_ROOT} 
            || $ENV{WEBGUI_ROOT}
            || '/data/WebGUI';

        my $configFile = $env->{WEBGUI_CONFIG} 
            || $ENV{WEBGUI_CONFIG}
            || die q(Couldn't find a WebGUI config);

        my $config = WebGUI::Config->new($root, $configFile);
        my $request = Plack::Request->new($env);

        my $cookie = $request->cookie($config->getCookieName);

        $session = $env->{wgSession} = WebGUI::Session->open(
            $root, $configFile, undef, undef, $cookie && $cookie->value
        );
    }

    local $env->{'psgi.url_scheme'} = 'https' if ($env->{HTTP_SSLPROXY});
    my $response = Plack::Response->new(@{ $self->app->($env) });
    $response->cookies->{$session->config->getCookieName} = {
        value => $session->getId
    };

    return $response->finalize;
}

1;
