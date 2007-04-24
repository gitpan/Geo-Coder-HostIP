package Geo::Coder::HostIP;

use strict;
use Carp;

use LWP::UserAgent;

sub new {
    my $c = shift;
    my $pkg = ref $c || $c;
    my $obj = {};
    bless $obj, $pkg;
    my $server = shift || 'api.hostip.info';
    $obj->{_server} = $server;
    $obj->{_ua} = LWP::UserAgent->new;
    $obj->{_agent} = 'Geo::Coder::HostIP/0.1';
    return $obj;
}

sub Agent {
    my $obj = shift;
    my $uaname = shift or return undef;
    $obj->{_agent} = $uaname;
}

sub _request {
    my $obj = shift;
    $obj->{_ua}->agent($obj->{_agent});
    return undef unless $obj->{_server} and $obj->{ip};

    my $res = $obj->{_ua}->get("http://$obj->{_server}/get_html.php?".
                               "ip=$obj->{ip}&position=true");

    if ($res->is_success) {
         return $obj->_parse($res->content);
    }
    else {
         croak $res->status_line;
    }
}

sub FetchIP {
    my $obj = shift;
    my $ip = shift or return undef;
    $obj->{ip} = $ip;
    return $obj->_request;
}

sub FetchName {
    my $obj = shift;
    my $name = shift or return undef;
    my $ip = join ".", unpack('C4', (gethostbyname $obj->{domain})[4]);
    return $obj->FetchIP($obj->{domain});
}

sub FetchRemoteAddr {
    my $obj = shift;
    if (exists $ENV{REMOTE_ADDR} && defined $ENV{REMOTE_ADDR}) {
        return $obj->FetchIP($ENV{REMOTE_ADDR});
    }
    else {
        return undef;
    }
}

sub Lat {
    my $obj = shift;
    return exists $obj->{Latitude} ? $obj->{Latitude} : undef;
}

sub Long {
    my $obj = shift;
    return exists $obj->{Longitude} ? $obj->{Longitude} : undef;
}

sub Latitude {
    my $obj = shift;
    return $obj->Lat;
}

sub Longitude {
    my $obj = shift;
    return $obj->Long;
}

sub City {
    my $obj = shift;
    return exists $obj->{City} ? $obj->{City} : undef;
}

sub Country {
    my $obj = shift;
    return exists $obj->{Country} ? $obj->{Country} : undef;
}

sub CountryCode {
    my $obj = shift;
    return exists $obj->{Country_Code} ? $obj->{Country_Code} : undef;
}

sub State {
    my $obj = shift;
    return exists $obj->{State} ? $obj->{State} : undef;
}

sub Coords {
    my $obj = shift;
    if (exists $obj->{Latitude} and exists $obj->{Longitude}) {
        return wantarray ? ($obj->{Latitude}, $obj->{Longitude}) : 
	                   "Lat: $obj->{Latitude}, Long: $obj->{Longitude}";
    }
    else {
        return undef;
    }
}

sub GoogleMap {
    my $obj = shift;
    my $params = pop;

    if (@_) {
        my $ip = shift;
	$obj->FetchIP($ip);
    }

    unless (    exists $obj->{Latitude} and defined $obj->{Latitude}
            and exists $obj->{Longitude} and defined $obj->{Longitude}
	    and ref $params eq 'HASH' and $params->{apikey}) {
        return undef;
    }

    my $apikey = $params->{apikey};
    my $id = $params->{id} || 'googlemap';
    my $fname = $params->{func_name} || 'load';
    my $width = $params->{width} || 500;
    my $height = $params->{height} || 300;
    my $zoom = $params->{zoom} || 13;

    my $controls = '';
    if ($params->{control}) {
       if ($params->{control} eq 'large') {
           $controls = 'map.addControl(new GLargeMapControl());';
       }
       elsif ($params->{control} eq 'small') {
           $controls = 'map.addControl(new GSmallMapControl());';
       }
       else {
           $controls = 'map.addControl(new GSmallScaleControl());';
       }
    }

    my $scalec = '';
    if ($params->{scalecontrol}) {
        $scalec = 'map.addControl(new GScaleControl());';
    }

    my $typec = '';
    if ($params->{typecontrol}) {
        $typec = 'map.addControl(new GMapTypeControl());';
    }
    
    my $overc = '';
    if ($params->{overviewcontrol}) {
        $overc = 'map.addControl(new GOverviewMapControl());';
    }

    my $lat = $obj->{Latitude} + 0;
    my $long = $obj->{Longitude} + 0;

    return <<"EOF";
    <script src="http://maps.google.com/maps?file=api&amp;v=2&amp;key=$apikey"
      type="text/javascript"></script>
    <script type="text/javascript">

    //<![CDATA[

    function $fname() {
        if (GBrowserIsCompatible()) {
            var map = new GMap2(document.getElementById('$id'));
            $controls
            $scalec
            $typec
            $overc
            map.setCenter(new GLatLng($lat, $long), $zoom);
        }
    }

    //]]>
    </script>
  </head>
  <body onload="$fname()" onunload="GUnload()">
    <div id="$id" style="width: ${width}px; height: ${height}px"></div>
  </body>
EOF
}

sub _parse {
    my $obj = shift;
    my $res = shift or return undef;

    for my $key (qw(Country City Longitude Latitude)) {
        delete $obj->{$key};
    }

    my $content = $res;
    my @rows = split /[\r\n]+/, $content;
    chomp @rows;

    for my $row (@rows) {
        my ($k, $v) = split /\s*:\s*/, $row, 2;
	if ($k eq 'Country') {
	    $v =~ /(.*)\s*(\([^\)])\)$/;
	    $obj->{Country} = $1;
	    $obj->{Country_Code} = $2;
	}
	elsif ($k eq 'City') {
	    if ($v =~ /(.*),\s+([A-Z]+)/) {
	        $obj->{City} = $1;
		$obj->{State} = $2;
            }
	}
	elsif ($k eq 'Latitude' or $k eq 'Longitude') {
	    $obj->{$k} = $v + 0;
	}
	else {
	    $obj->{$k} ||= $v;
	}
    }
    if (defined $obj->{Latitude} and defined $obj->{Longitude}) {
        return wantarray ? ($obj->{Latitude}, $obj->{Longitude}) :
	                   "Lat: $obj->{Latitude}, Long: $obj->{Longitude}";
    }
    else {
        return wantarray ? () : 'Coordinates Not Found';
    }
}

1;
