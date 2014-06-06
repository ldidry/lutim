#! /usr/bin/env perl
###################################################
#
#  Copyright (C) 2010-2011  Vadim Rutkovsky <roignac@gmail.com>, Mario Kemper <mario.kemper@googlemail.com> and Shutter Team
#
#  This file is part of Shutter.
#
#  Shutter is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  Shutter is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Shutter; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
###################################################

package Lutim;

use lib $ENV{'SHUTTER_ROOT'}.'/share/shutter/resources/modules';

use utf8;
use strict;
use POSIX qw/setlocale/;
use Locale::gettext;
use Glib qw/TRUE FALSE/;

use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);

my $d = Locale::gettext->domain("shutter-upload-plugins");
$d->dir( $ENV{'SHUTTER_INTL'} );

my %upload_plugin_info = (
    'module'                        => "Lutim",
    'url'                           => "https://lut.im/",
    'registration'                  => "-",
    'name'                          => "Lutim",
    'description'                   => "Upload screenshots to Lutim",
    'supports_anonymous_upload'     => TRUE,
    'supports_authorized_upload'    => FALSE,
    'supports_oauth_upload'         => FALSE,
);

binmode( STDOUT, ":utf8" );
if ( exists $upload_plugin_info{$ARGV[ 0 ]} ) {
    print $upload_plugin_info{$ARGV[ 0 ]};
    exit;
}


#don't touch this
sub new {
    my $class = shift;

    #call constructor of super class (host, debug_cparam, shutter_root, gettext_object, main_gtk_window, ua)
    my $self = $class->SUPER::new( shift, shift, shift, shift, shift, shift );

    bless $self, $class;
    return $self;
}

#load some custom modules here (or do other custom stuff)
sub init {
    my $self = shift;

    use JSON;
    use LWP::UserAgent;
    use HTTP::Request::Common;

    return TRUE;
}

#handle
sub upload {
    my ( $self, $upload_filename, $username, $password ) = @_;

    #store as object vars
    $self->{_filename} = $upload_filename;
    $self->{_username} = $username;
    $self->{_password} = $password;

    utf8::encode $upload_filename;
    utf8::encode $password;
    utf8::encode $username;

    my $json = JSON->new();

    my $browser = LWP::UserAgent->new(
        'timeout'    => 20,
        'keep_alive' => 10,
        'env_proxy'  => 1,
    );


    #upload the file
    eval{

        my $url     = 'https://lut.im/';
        my $request = HTTP::Request::Common::POST(
            $url,
            Content_Type => 'multipart/form-data',
            Content      => [
                file   => [$upload_filename],
                format => 'json'
            ]
        );

        my $response = $browser->request($request);

        if ($response->is_success) {
            my $hash = $json->decode($response->decoded_content);

            if ($hash->{success}) {
                my $link = $url.$hash->{msg}->{short};
                $self->{_links}->{'view_image'}    = $link;
                $self->{_links}->{'download_link'} = $link.'?dl';
                $self->{_links}->{'twitter_link'}  = $link.'?t';
                $self->{_links}->{'delete_link'}   = $url.'d/'.$hash->{msg}->{real_short}.'/'.$hash->{msg}->{token};

                #set success code (200)
                $self->{_links}{'status'} = 200;
            } else {
                $self->{_links}{'status'} = $hash->{msg}->{msg};

            }
        } else {
            $self->{_links}{'status'} = $response->status_line;
        }
    };
    if($@){
        $self->{_links}{'status'} = $@;
    }

    #and return links
    return %{ $self->{_links} };
}

1;
